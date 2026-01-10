/**
 * SMS Gateway Integration
 * Handles SMS sending for OTP, notifications, and promotional messages
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Lazy initialization
const getDb = () => admin.firestore();

interface SMSRequest {
  phoneNumber: string;
  message: string;
  type: 'otp' | 'notification' | 'promotional';
}

interface SMSResponse {
  success: boolean;
  messageId?: string;
  error?: string;
}

/**
 * Send SMS via Gateway
 * 
 * Integration points:
 * - Lebanese SMS Gateway (touch.com.lb or similar)
 * - Twilio fallback for international
 * - Rate limiting: 5 SMS per user per hour
 * 
 * @param data - Phone number, message, and type
 * @returns Success status and message ID
 */
export const sendSMS = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 20 // Higher for SMS volume
  })
  .https.onCall(async (data: SMSRequest, context): Promise<SMSResponse> => {
    try {
      // Verify authentication for non-OTP messages
      if (data.type !== 'otp' && !context.auth) {
        return { success: false, error: 'Unauthenticated' };
      }

      // Validate phone number format (Lebanese +961)
      if (!data.phoneNumber.match(/^\+961[3-9]\d{7}$/)) {
        return { success: false, error: 'Invalid Lebanese phone number' };
      }

      // Rate limiting check
      const userId = context.auth?.uid || data.phoneNumber;
      const hourAgo = new Date(Date.now() - 3600000);
      
      const recentSMS = await getDb().collection('sms_log')
        .where('recipient', '==', data.phoneNumber)
        .where('sent_at', '>=', admin.firestore.Timestamp.fromDate(hourAgo))
        .count()
        .get();

      if (recentSMS.data().count >= 5) {
        return { success: false, error: 'Rate limit exceeded. Max 5 SMS per hour.' };
      }

      // TODO: Integrate with actual Lebanese SMS Gateway
      // For now, simulate SMS sending
      
      // Production implementation would be:
      /*
      const response = await fetch('https://api.touch.com.lb/sms/send', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.SMS_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: data.phoneNumber,
          message: data.message,
          sender: 'UrbanPoints',
        }),
      });
      
      const result = await response.json();
      if (!result.success) {
        throw new Error(result.error);
      }
      */

      // Generate simulated message ID
      const messageId = `SMS_${Date.now()}_${Math.random().toString(36).substring(7)}`;

      // Log SMS in Firestore
      await getDb().collection('sms_log').add({
        message_id: messageId,
        recipient: data.phoneNumber,
        message: data.message,
        type: data.type,
        status: 'sent',
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        user_id: userId,
      });

      // For OTP messages, store the code temporarily
      if (data.type === 'otp') {
        const otpMatch = data.message.match(/\d{6}/);
        if (otpMatch) {
          await getDb().collection('otp_codes').doc(data.phoneNumber).set({
            code: otpMatch[0],
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            expires_at: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 300000)), // 5 minutes
            attempts: 0,
          });
        }
      }

      return {
        success: true,
        messageId,
      };

    } catch (error) {
      console.error('Error sending SMS:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });

/**
 * Verify OTP Code
 * 
 * Security features:
 * - 5-minute expiry
 * - 3 attempts maximum
 * - Auto-deletion after verification
 * 
 * @param data - Phone number and OTP code
 * @returns Verification success status
 */
export const verifyOTP = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 20,
  })
  .https.onCall(async (data: { phoneNumber: string; code: string }, context) => {
    try {
      if (!data.phoneNumber || !data.code) {
        return { success: false, error: 'Phone number and code required' };
      }

      const otpDoc = await getDb().collection('otp_codes').doc(data.phoneNumber).get();

      if (!otpDoc.exists) {
        return { success: false, error: 'OTP not found or expired' };
      }

      const otpData = otpDoc.data()!;

      // Check expiry
      if (Date.now() > otpData.expires_at.toMillis()) {
        await otpDoc.ref.delete();
        return { success: false, error: 'OTP expired' };
      }

      // Check attempts
      if (otpData.attempts >= 3) {
        await otpDoc.ref.delete();
        return { success: false, error: 'Too many attempts' };
      }

      // Verify code
      if (otpData.code !== data.code) {
        await otpDoc.ref.update({
          attempts: admin.firestore.FieldValue.increment(1),
        });
        return { success: false, error: 'Invalid OTP code' };
      }

      // Success - delete OTP
      await otpDoc.ref.delete();

      return { success: true };

    } catch (error) {
      console.error('Error verifying OTP:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });

/**
 * Cleanup Expired OTPs
 * Scheduled function to run every hour
 */
// TEMPORARILY DISABLED - Requires Cloud Scheduler API
export const cleanupExpiredOTPs = null as any;
/*
export const cleanupExpiredOTPs = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 120,
  })
  .pubsub.schedule('every 1 hours')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      const expiredOTPs = await getDb().collection('otp_codes')
        .where('expires_at', '<', now)
        .get();

      if (expiredOTPs.empty) {
        console.log('No expired OTPs to clean up');
        return null;
      }

      const batch = getDb().batch();
      expiredOTPs.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Cleaned up ${expiredOTPs.size} expired OTPs`);

      return null;
    } catch (error) {
      console.error('Error cleaning up expired OTPs:', error);
      return null;
    }
  });
*/
