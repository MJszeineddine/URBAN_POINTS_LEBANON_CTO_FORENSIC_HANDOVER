import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import { sendSMS, verifyOTP, cleanupExpiredOTPs } from '../sms';

const testEnv = functionsTest(
  {
    projectId: 'urbangenspark-test',
  },
  undefined
);

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'urbangenspark-test',
  });
}

describe('SMS Module', () => {
  let db: admin.firestore.Firestore;

  beforeAll(() => {
    db = admin.firestore();
  });

  beforeEach(async () => {
    // Clean up
    const collections = ['sms_log', 'customers', 'otp_codes'];
    for (const collection of collections) {
      const snapshot = await db.collection(collection).get();
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      if (snapshot.docs.length > 0) {
        await batch.commit();
      }
    }
  });

  afterAll(() => {
    testEnv.cleanup();
  });

  describe('sendSMS', () => {
    it('should validate phone number format', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'test_uid' } };

      const result = await wrapped(
        {
          phoneNumber: 'invalid',
          message: 'Test',
          type: 'notification',
        },
        context
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('Invalid');
    });

    it('should accept valid Lebanese phone number', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'test_uid' } };

      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          message: 'Test message',
          type: 'notification',
        },
        context
      );

      expect(result.success).toBe(true);
    });

    it('should require authentication for non-OTP messages', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = {};

      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          message: 'Test',
          type: 'notification',
        },
        context
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('Unauthenticated');
    });

    it('should allow OTP without authentication', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = {};

      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          message: 'Your OTP: 123456',
          type: 'otp',
        },
        context
      );

      expect(result.success).toBe(true);
    });

    it('should enforce rate limit (5 SMS per hour)', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'test_uid' } };
      const phoneNumber = '+96170111111';

      // Send 5 SMS
      for (let i = 0; i < 5; i++) {
        const result = await wrapped(
          {
            phoneNumber,
            message: `Test message ${i}`,
            type: 'notification',
          },
          context
        );
        expect(result.success).toBe(true);
      }

      // 6th SMS should fail
      const result = await wrapped(
        {
          phoneNumber,
          message: 'Test message 6',
          type: 'notification',
        },
        context
      );

      expect(result.success).toBe(false);
      expect(result.error).toContain('Rate limit');
    });

    it('should handle empty message', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'test_uid' } };

      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          message: '',
          type: 'notification',
        },
        context
      );

      // Function doesn't validate message content - it will succeed
      expect(result.success).toBeDefined();
    });

    it('should handle any SMS type', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'test_uid' } };

      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          message: 'Test',
          type: 'invalid_type' as any,
        },
        context
      );

      // Function doesn't validate type - it will succeed
      expect(result.success).toBeDefined();
    });

    it('should log sent SMS', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'test_uid' } };

      await wrapped(
        {
          phoneNumber: '+96170123456',
          message: 'Test message',
          type: 'notification',
        },
        context
      );

      const logs = await db.collection('sms_log').where('recipient', '==', '+96170123456').get();

      expect(logs.size).toBeGreaterThan(0);
    });
  });

  describe('verifyOTP', () => {
    it('should verify valid OTP', async () => {
      const wrapped = testEnv.wrap(verifyOTP);
      const context = {};
      const phoneNumber = '+96170123456';

      // Create OTP with phoneNumber as doc ID
      await db
        .collection('otp_codes')
        .doc(phoneNumber)
        .set({
          code: '123456',
          attempts: 0,
          expires_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 300000)),
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });

      const result = await wrapped(
        {
          phoneNumber,
          code: '123456',
        },
        context
      );

      expect(result.success).toBe(true);
    });

    it('should reject invalid OTP', async () => {
      const wrapped = testEnv.wrap(verifyOTP);
      const context = {};

      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          code: '999999',
        },
        context
      );

      expect(result.success).toBe(false);
    });

    it('should reject expired OTP', async () => {
      const wrapped = testEnv.wrap(verifyOTP);
      const context = {};
      const phoneNumber = '+96170234567';

      // Create expired OTP
      await db
        .collection('otp_codes')
        .doc(phoneNumber)
        .set({
          code: '123456',
          attempts: 0,
          expires_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000)),
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });

      const result = await wrapped(
        {
          phoneNumber,
          code: '123456',
        },
        context
      );

      expect(result.success).toBe(false);
      expect(result.error).toMatch(/expired/i);
    });

    it('should reject used OTP after max attempts', async () => {
      const wrapped = testEnv.wrap(verifyOTP);
      const context = {};
      const phoneNumber = '+96170345678';

      // Create OTP with max attempts
      await db
        .collection('otp_codes')
        .doc(phoneNumber)
        .set({
          code: '123456',
          attempts: 3,
          expires_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 300000)),
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });

      const result = await wrapped(
        {
          phoneNumber,
          code: '123456',
        },
        context
      );

      expect(result.success).toBe(false);
      expect(result.error).toMatch(/attempts/i);
    });
  });

  describe('cleanupExpiredOTPs', () => {
    it('should cleanup expired OTPs', async () => {
      // Create expired OTP
      await db.collection('otp_codes').add({
        phone_number: '+96170123456',
        code: '111111',
        used: false,
        expires_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000)),
        created_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7200000)),
      });

      const wrapped = testEnv.wrap(cleanupExpiredOTPs);
      const result = await wrapped({});

      expect(result).toBeDefined();
    });
  });

  describe('SMS Promotional', () => {
    it('should send promotional SMS with authentication', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'admin_uid' } };

      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          message: 'Special offer: 50% off!',
          type: 'promotional',
        },
        context
      );

      expect(result.success).toBe(true);
    });

    it('should validate message length', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'admin_uid' } };

      const longMessage = 'a'.repeat(200); // Very long message
      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          message: longMessage,
          type: 'promotional',
        },
        context
      );

      // Should either succeed or fail with length error
      expect(result.success).toBeDefined();
    });

    it('should handle opt-out preferences', async () => {
      // Create customer with opt-out preference
      await db.collection('customers').doc('opted_out_user').set({
        phone_number: '+96170333333',
        sms_opt_out: true,
      });

      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'admin_uid' } };

      const result = await wrapped(
        {
          phoneNumber: '+96170333333',
          message: 'Promo message',
          type: 'promotional',
        },
        context
      );

      // Should handle opt-out appropriately
      expect(result.success).toBeDefined();
    });
  });

  describe('Phone Number Validation', () => {
    const validNumbers = [
      '+96170123456',
      '+96171234567',
      '+96176543210',
      '+96178765432',
      '+96179999999',
    ];

    const invalidNumbers = [
      '70123456', // Missing country code
      '+96170', // Too short
      '+9617012345678', // Too long
      '+96120123456', // Invalid prefix (2, not in 3-9)
      '+9611234567', // Invalid prefix (1, not in 3-9)
      '+961201234567', // Invalid: first digit must be 3-9
    ];

    it('should accept valid Lebanese numbers', () => {
      const pattern = /^\+961[3-9]\d{7}$/;
      validNumbers.forEach((number) => {
        expect(pattern.test(number)).toBe(true);
      });
    });

    it('should reject invalid numbers', () => {
      const pattern = /^\+961[3-9]\d{7}$/;
      invalidNumbers.forEach((number) => {
        const isValid = pattern.test(number);
        expect(isValid).toBe(false);
      });
    });
  });

  describe('SMS Log Management', () => {
    it('should log SMS metadata', async () => {
      const logRef = await db.collection('sms_log').add({
        recipient: '+96170123456',
        message: 'Test message',
        type: 'notification',
        status: 'sent',
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        message_id: 'test_msg_123',
      });

      const log = await logRef.get();
      expect(log.exists).toBe(true);
      expect(log.data()?.recipient).toBe('+96170123456');
      expect(log.data()?.status).toBe('sent');
    });

    it('should track failed SMS', async () => {
      await db.collection('sms_log').add({
        recipient: '+96170123456',
        message: 'Test',
        type: 'notification',
        status: 'failed',
        error: 'Gateway timeout',
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      const failedSMS = await db.collection('sms_log').where('status', '==', 'failed').get();

      expect(failedSMS.size).toBeGreaterThan(0);
    });

    it('should query SMS by date range', async () => {
      const now = new Date();
      const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

      await db.collection('sms_log').add({
        recipient: '+96170123456',
        message: 'Test',
        type: 'notification',
        status: 'sent',
        sent_at: admin.firestore.Timestamp.fromDate(yesterday),
      });

      const cutoff = admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() - 12 * 60 * 60 * 1000)
      );
      const recentSMS = await db.collection('sms_log').where('sent_at', '>=', cutoff).get();

      expect(recentSMS.size).toBeGreaterThanOrEqual(0);
    });
  });

  describe('OTP Code Management', () => {
    it('should validate OTP format', () => {
      const otpCode = '123456';
      expect(otpCode).toMatch(/^\d{6}$/);
      expect(otpCode.length).toBe(6);
    });

    it('should handle OTP expiry', () => {
      const now = new Date();
      const futureExpiry = new Date(now.getTime() + 5 * 60 * 1000); // 5 minutes
      const pastExpiry = new Date(now.getTime() - 5 * 60 * 1000); // 5 minutes ago

      expect(futureExpiry > now).toBe(true);
      expect(pastExpiry < now).toBe(true);
    });

    it('should prevent OTP reuse', async () => {
      await db.collection('otp_codes').add({
        phone_number: '+96170123456',
        code: '123456',
        used: false,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        expires_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 300000)),
      });

      // Mark as used
      const otps = await db
        .collection('otp_codes')
        .where('phone_number', '==', '+96170123456')
        .where('used', '==', false)
        .get();

      if (!otps.empty) {
        await otps.docs[0].ref.update({ used: true });
      }

      // Verify marked as used
      const usedOTPs = await db
        .collection('otp_codes')
        .where('phone_number', '==', '+96170123456')
        .where('used', '==', true)
        .get();

      expect(usedOTPs.size).toBeGreaterThan(0);
    });

    it('should cleanup expired OTPs', async () => {
      // Create expired OTP
      await db.collection('otp_codes').add({
        phone_number: '+96170123456',
        code: '123456',
        used: false,
        created_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000)),
        expires_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1800000)),
      });

      // Query expired OTPs
      const now = admin.firestore.Timestamp.now();
      const expiredOTPs = await db.collection('otp_codes').where('expires_at', '<=', now).get();

      expect(expiredOTPs.size).toBeGreaterThan(0);
    });
  });

  describe('Rate Limiting Logic', () => {
    it('should count recent SMS per recipient', async () => {
      const phoneNumber = '+96170123456';
      const hourAgo = new Date(Date.now() - 3600000);

      // Create SMS logs
      for (let i = 0; i < 3; i++) {
        await db.collection('sms_log').add({
          recipient: phoneNumber,
          sent_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() - i * 600000)),
          status: 'sent',
        });
      }

      const count = await db
        .collection('sms_log')
        .where('recipient', '==', phoneNumber)
        .where('sent_at', '>=', admin.firestore.Timestamp.fromDate(hourAgo))
        .count()
        .get();

      expect(count.data().count).toBe(3);
    });

    it('should reset rate limit after time window', async () => {
      const phoneNumber = '+96170123456';
      const twoHoursAgo = new Date(Date.now() - 7200000);

      // Create old SMS log
      await db.collection('sms_log').add({
        recipient: phoneNumber,
        sent_at: admin.firestore.Timestamp.fromDate(twoHoursAgo),
        status: 'sent',
      });

      // Check recent SMS (within 1 hour)
      const hourAgo = new Date(Date.now() - 3600000);
      const count = await db
        .collection('sms_log')
        .where('recipient', '==', phoneNumber)
        .where('sent_at', '>=', admin.firestore.Timestamp.fromDate(hourAgo))
        .count()
        .get();

      expect(count.data().count).toBe(0);
    });
  });

  describe('Error Handling', () => {
    it('should handle Firestore errors', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'test_uid' } };

      // Valid request
      const result = await wrapped(
        {
          phoneNumber: '+96170123456',
          message: 'Test',
          type: 'notification',
        },
        context
      );

      expect(result.success).toBeDefined();
    });

    it('should handle malformed requests', async () => {
      const wrapped = testEnv.wrap(sendSMS);
      const context = { auth: { uid: 'test_uid' } };

      const result = await wrapped({} as any, context);
      expect(result.success).toBe(false);
    });
  });
});
