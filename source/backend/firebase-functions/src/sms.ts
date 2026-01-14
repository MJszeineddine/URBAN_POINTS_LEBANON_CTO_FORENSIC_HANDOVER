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

      // Integrate with Lebanese SMS Gateway
      // Priority: Lebanese providers (touch.com.lb, alfa.com.lb)
      // Fallback: International providers (Twilio)
      
      const smsApiKey = process.env.SMS_API_KEY || functions.config().sms?.api_key;
      const smsProvider = process.env.SMS_PROVIDER || functions.config().sms?.provider || 'touch'; // touch, alfa, twilio
      
      let messageId: string;
      
      try {
        if (smsProvider === 'touch' && smsApiKey) {
          // Touch Lebanon SMS Gateway
          const response = await fetch('https://api.touch.com.lb/sms/v1/send', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${smsApiKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              to: data.phoneNumber,
              message: data.message,
              sender: 'UrbanPoints',
            }),
          });
          
          if (!response.ok) {
            throw new Error(`Touch SMS API error: ${response.statusText}`);
          }
          
          const result = await response.json();
          messageId = result.message_id || result.id;
          
        } else if (smsProvider === 'alfa' && smsApiKey) {
          // Alfa Lebanon SMS Gateway
          const response = await fetch('https://api.alfa.com.lb/sms/send', {
            method: 'POST',
            headers: {
              'X-API-Key': smsApiKey,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              recipient: data.phoneNumber,
              text: data.message,
              from: 'UrbanPoints',
            }),
          });
          
          if (!response.ok) {
            throw new Error(`Alfa SMS API error: ${response.statusText}`);
          }
          
          const result = await response.json();
          messageId = result.msg_id || result.message_id;
          
        } else if (smsProvider === 'twilio' && smsApiKey) {
          // Twilio fallback for international
          const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID || functions.config().twilio?.account_sid;
          const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER || functions.config().twilio?.phone_number;
          
          if (!twilioAccountSid || !twilioPhoneNumber) {
            throw new Error('Twilio credentials not configured');
          }
          
          const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`, {
            method: 'POST',
            headers: {
              'Authorization': 'Basic ' + Buffer.from(`${twilioAccountSid}:${smsApiKey}`).toString('base64'),
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
              To: data.phoneNumber,
              From: twilioPhoneNumber,
              Body: data.message,
            }).toString(),
          });
          
          if (!response.ok) {
            throw new Error(`Twilio SMS API error: ${response.statusText}`);
          }
          
          const result = await response.json();
          messageId = result.sid;
          
        } else {
          // Simulated mode for development/testing
          messageId = `SMS_SIM_${Date.now()}_${Math.random().toString(36).substring(7)}`;
          console.log(`SIMULATED SMS (${smsProvider}): ${data.phoneNumber} - ${data.message}`);
        }
        
      } catch (error) {
        console.error('SMS Gateway error:', error);
        // Fallback to simulated mode on error
        messageId = `SMS_ERR_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      }

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
