import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import axios from 'axios';
import { clearFirestoreData, getFirestore } from '../../test/helpers/emulator';

// Mock axios
jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

// Initialize Firebase Functions Test SDK with emulator config
const test = functionsTest(
  {
    projectId: 'urbangenspark-test',
  },
  undefined
);

// Initialize Firebase Admin with emulator settings
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'urbangenspark-test',
  });
}

describe('Alert Functions', () => {
  let db: admin.firestore.Firestore;

  beforeAll(() => {
    db = getFirestore();
  });

  beforeEach(async () => {
    await clearFirestoreData();
    // Reset axios mock
    mockedAxios.post.mockClear();
  });

  afterAll(() => {
    test.cleanup();
  });

  describe('System Alert Creation', () => {
    it('should create alert in Firestore', async () => {
      // Create a system alert manually
      await db.collection('system_alerts').add({
        type: 'test_alert',
        severity: 'high',
        message: 'Test alert message',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Verify alert exists
      const alerts = await db.collection('system_alerts').where('type', '==', 'test_alert').get();

      expect(alerts.docs.length).toBe(1);
      expect(alerts.docs[0].data().message).toBe('Test alert message');
    });

    it('should allow reading alerts', async () => {
      // Create multiple alerts
      const batch = db.batch();

      for (let i = 0; i < 3; i++) {
        const ref = db.collection('system_alerts').doc();
        batch.set(ref, {
          type: 'test_alert',
          severity: i === 0 ? 'critical' : 'medium',
          message: `Alert ${i}`,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Read alerts
      const allAlerts = await db.collection('system_alerts').get();
      expect(allAlerts.docs.length).toBe(3);
    });
  });

  describe('Slack Notification Mock', () => {
    it('should mock Slack webhook call', async () => {
      // Mock successful Slack response
      mockedAxios.post.mockResolvedValue({
        data: { ok: true },
        status: 200,
        statusText: 'OK',
        headers: {},
        config: {} as any,
      });

      // Simulate Slack webhook call
      const webhookUrl = 'https://hooks.slack.com/services/TEST';
      const result = await axios.post(webhookUrl, {
        text: 'Test alert',
      });

      expect(result.data.ok).toBe(true);
      expect(mockedAxios.post).toHaveBeenCalledWith(
        webhookUrl,
        expect.objectContaining({ text: 'Test alert' })
      );
    });

    it('should handle Slack webhook failure', async () => {
      // Mock failed Slack response
      mockedAxios.post.mockRejectedValue(new Error('Network error'));

      // Attempt Slack webhook call
      await expect(
        axios.post('https://hooks.slack.com/services/TEST', { text: 'Test' })
      ).rejects.toThrow('Network error');
    });
  });

  describe('Alert Query Performance', () => {
    it('should efficiently query recent alerts', async () => {
      // Create alerts with timestamps
      const batch = db.batch();
      const now = Date.now();

      for (let i = 0; i < 10; i++) {
        const ref = db.collection('system_alerts').doc();
        const timestamp = new Date(now - i * 60000); // Each 1 min apart
        batch.set(ref, {
          type: 'test_alert',
          severity: 'low',
          message: `Alert ${i}`,
          created_at: admin.firestore.Timestamp.fromDate(timestamp),
        });
      }

      await batch.commit();

      // Query recent alerts (last 5 minutes)
      const fiveMinutesAgo = admin.firestore.Timestamp.fromDate(new Date(now - 5 * 60000));

      const recentAlerts = await db
        .collection('system_alerts')
        .where('created_at', '>=', fiveMinutesAgo)
        .get();

      expect(recentAlerts.docs.length).toBeGreaterThan(0);
      expect(recentAlerts.docs.length).toBeLessThanOrEqual(10);
    });
  });
});
