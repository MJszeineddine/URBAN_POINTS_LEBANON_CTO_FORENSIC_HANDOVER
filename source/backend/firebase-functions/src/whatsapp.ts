/**
 * WhatsApp Verification & OTP Service
 * Integrates Twilio WhatsApp Business API for user verification
 * Replaces SMS-based OTP flow with WhatsApp-based verification
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Lazy initialization
const getDb = () => admin.firestore();

interface WhatsAppRequest {
  phoneNumber: string;
  message: string;
  type: 'otp' | 'notification' | 'promotional';
}

interface WhatsAppResponse {
  success: boolean;
  messageId?: string;
  whatsappId?: string;
  error?: string;
}

interface WhatsAppOTPRequest {
  phoneNumber: string;
}

interface WhatsAppOTPResponse {
  success: boolean;
  error?: string;
}

interface VerifyWhatsAppOTPRequest {
  phoneNumber: string;
  code: string;
}

interface VerifyWhatsAppOTPResponse {
  success: boolean;
  valid?: boolean;
  error?: string;
}

/**
 * Send WhatsApp Message via Twilio API
 * 
 * Integration points:
 * - Twilio WhatsApp Business API
 * - Rate limiting: 5 messages per user per hour
 * - Storage of message metadata for audit
 * 
 * @param data - Phone number, message, and type
 * @param context - Auth context
 * @returns Success status and message ID
 */
async function coreSendWhatsAppMessage(data: WhatsAppRequest, context: functions.https.CallableContext): Promise<WhatsAppResponse> {
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
    const hourAgo = new Date(Date.now() - 3600000);
    
    const recentMessages = await getDb()
      .collection('whatsapp_log')
      .where('recipient', '==', data.phoneNumber)
      .where('sent_at', '>=', admin.firestore.Timestamp.fromDate(hourAgo))
      .count()
      .get();

    if (recentMessages.data().count >= 5) {
      return { success: false, error: 'Rate limit exceeded. Max 5 messages per hour.' };
    }

    // Get Twilio WhatsApp credentials
    const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID || functions.config().twilio?.account_sid;
    const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN || functions.config().twilio?.auth_token;
    const whatsappNumber = process.env.WHATSAPP_NUMBER || functions.config().whatsapp?.number || 'whatsapp:+1234567890';

    if (!twilioAccountSid || !twilioAuthToken) {
      console.log('Twilio WhatsApp not configured. Simulating message send.');
      // Simulation mode for development
      const messageId = `sim_${Date.now()}`;
      
      await getDb().collection('whatsapp_log').add({
        recipient: data.phoneNumber,
        message: data.message,
        type: data.type,
        status: 'sent',
        messageId,
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        messageId,
      };
    }

    // Send via Twilio WhatsApp API
    const encodedMessage = encodeURIComponent(data.message);
    const authString = Buffer.from(`${twilioAccountSid}:${twilioAuthToken}`).toString('base64');

    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${authString}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `From=${encodeURIComponent(whatsappNumber)}&To=whatsapp:${encodeURIComponent(data.phoneNumber)}&Body=${encodedMessage}`,
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Twilio API error: ${response.status} ${errorText}`);
    }

    const result = await response.json() as any;
    const messageId = result.sid;

    // Log message for audit trail
    await getDb().collection('whatsapp_log').add({
      recipient: data.phoneNumber,
      message: data.message,
      type: data.type,
      status: 'sent',
      messageId,
      whatsapp_id: messageId,
      provider: 'twilio',
      sent_at: admin.firestore.FieldValue.serverTimestamp(),
    });

      return {
        success: true,
        messageId,
        whatsappId: messageId,
      };

    } catch (error) {
      console.error('Error sending WhatsApp message:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
}

/**
 * Cloud Function wrapper for sendWhatsAppMessage
 */
export const sendWhatsAppMessage = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 20,
  })
  .https.onCall(async (data: WhatsAppRequest, context): Promise<WhatsAppResponse> => {
    return coreSendWhatsAppMessage(data, context);
  });

/**
 * Send WhatsApp OTP Code
 * 
 * Generates a 6-digit OTP and sends via WhatsApp
 * 
 * @param data - Phone number
 * @returns Success status
 */
export const sendWhatsAppOTP = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 20,
  })
  .https.onCall(async (data: WhatsAppOTPRequest, context): Promise<WhatsAppOTPResponse> => {
    try {
      if (!data.phoneNumber) {
        return { success: false, error: 'Phone number required' };
      }

      // Validate phone number format (Lebanese +961)
      if (!data.phoneNumber.match(/^\+961[3-9]\d{7}$/)) {
        return { success: false, error: 'Invalid Lebanese phone number' };
      }

      // Generate 6-digit OTP
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      
      // Store OTP with 5-minute expiry
      const expiryTime = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes
      
      await getDb()
        .collection('otp_codes')
        .doc(data.phoneNumber)
        .set({
          code,
          expires_at: admin.firestore.Timestamp.fromDate(expiryTime),
          attempts: 0,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          channel: 'whatsapp', // Track that this OTP was sent via WhatsApp
        });

      // Send OTP via WhatsApp
      const message = `Your Urban Points verification code is: ${code}\n\nValid for 5 minutes. Do not share this code.`;
      
      const sendResult = await coreSendWhatsAppMessage({
        phoneNumber: data.phoneNumber,
        message,
        type: 'otp',
      }, context);

      if (!sendResult.success) {
        return {
          success: false,
          error: sendResult.error || 'Failed to send WhatsApp message',
        };
      }

      // Store OTP send metadata
      await getDb().collection('whatsapp_otp_history').add({
        phone_number: data.phoneNumber,
        code_hash: hashCode(code), // Don't store plain code
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        message_id: sendResult.messageId,
        expires_at: admin.firestore.Timestamp.fromDate(expiryTime),
      });

      return { success: true };

    } catch (error) {
      console.error('Error sending WhatsApp OTP:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });

/**
 * Verify WhatsApp OTP Code
 * 
 * Security features:
 * - 5-minute expiry
 * - 3 attempts maximum
 * - Auto-deletion after verification
 * - Phone number added to verified_phones custom claim
 * 
 * @param data - Phone number and OTP code
 * @returns Verification success status
 */
export const verifyWhatsAppOTP = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 20,
  })
  .https.onCall(async (data: VerifyWhatsAppOTPRequest, context): Promise<VerifyWhatsAppOTPResponse> => {
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
        return { success: false, error: 'Too many attempts. Request a new OTP.' };
      }

      // Verify code
      if (otpData.code !== data.code) {
        await otpDoc.ref.update({
          attempts: admin.firestore.FieldValue.increment(1),
        });
        return { success: false, error: 'Invalid OTP code' };
      }

      // Success - delete OTP and update user record
      await otpDoc.ref.delete();

      // If user is authenticated, add phone number to custom claims
      if (context.auth) {
        const uid = context.auth.uid;

        // Update user document with verified phone
        await getDb().collection('customers').doc(uid).update({
          phone_number: data.phoneNumber,
          phone_verified: true,
          phone_verified_at: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(async () => {
          // Create if doesn't exist
          await getDb().collection('customers').doc(uid).set({
            phone_number: data.phoneNumber,
            phone_verified: true,
            phone_verified_at: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        });

        // Set custom claim for verified phone
        try {
          await admin.auth().setCustomUserClaims(uid, {
            phone_verified: true,
            verified_phone: data.phoneNumber,
          });
        } catch (claimError) {
          console.error('Error setting custom claims:', claimError);
          // Don't fail the OTP verification due to claim error
        }
      }

      // Log successful verification
      await getDb().collection('whatsapp_verification_log').add({
        phone_number: data.phoneNumber,
        verified_at: admin.firestore.FieldValue.serverTimestamp(),
        user_id: context.auth?.uid || 'anonymous',
      });

      return {
        success: true,
        valid: true,
      };

    } catch (error) {
      console.error('Error verifying WhatsApp OTP:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });

/**
 * Cleanup Expired WhatsApp OTPs
 * Scheduled to run daily to clean up expired OTP codes
 */
export const cleanupExpiredWhatsAppOTPs = functions
  .pubsub
  .schedule('every day 03:00')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const expiredOTPs = await getDb()
        .collection('otp_codes')
        .where('expires_at', '<=', now)
        .limit(100)
        .get();

      const batch = getDb().batch();
      expiredOTPs.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      if (expiredOTPs.size > 0) {
        await batch.commit();
        console.log(`Cleaned up ${expiredOTPs.size} expired OTP codes`);
      }

      return null;
    } catch (error) {
      console.error('Error cleaning up expired OTPs:', error);
      return null;
    }
  });

/**
 * Helper function to hash OTP code for storage
 */
function hashCode(code: string): string {
  // Simple hash for demo - in production use proper crypto
  let hash = 0;
  for (let i = 0; i < code.length; i++) {
    const char = code.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash).toString(16);
}

/**
 * Get WhatsApp verification status for a user
 */
export const getWhatsAppVerificationStatus = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 10,
  })
  .https.onCall(async (data: { phoneNumber?: string }, context): Promise<{ verified: boolean; phoneNumber?: string; error?: string }> => {
    try {
      if (!context.auth) {
        return { verified: false, error: 'Unauthenticated' };
      }

      const uid = context.auth.uid;
      
      // Check if phone is verified in custom claims
      const user = await admin.auth().getUser(uid);
      const customClaims = user.customClaims as any;
      
      if (customClaims?.phone_verified && customClaims?.verified_phone) {
        return {
          verified: true,
          phoneNumber: customClaims.verified_phone,
        };
      }

      // Fallback: check user document
      const userDoc = await getDb().collection('customers').doc(uid).get();
      if (userDoc.exists) {
        const userData = userDoc.data() as any;
        if (userData.phone_verified && userData.phone_number) {
          return {
            verified: true,
            phoneNumber: userData.phone_number,
          };
        }
      }

      return { verified: false };

    } catch (error) {
      console.error('Error getting WhatsApp verification status:', error);
      return {
        verified: false,
        error: error instanceof Error ? error.message : 'Internal error',
      };
    }
  });
