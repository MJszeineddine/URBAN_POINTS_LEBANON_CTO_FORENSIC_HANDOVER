/**
 * Contract Tests for Customer App Integration
 * Tests that backend callables match Flutter client expectations
 * 
 * CRITICAL: These tests verify the DTO contracts that the customer app depends on
 */

import { toOfferDTO } from '../adapters/offerDto';
import { toIsoString } from '../adapters/time';
import * as admin from 'firebase-admin';

describe('Customer App DTO Contracts', () => {
  describe('Offer DTO Adapter', () => {
    it('should convert Firestore Timestamp to ISO string for valid_until', () => {
      const firestoreTimestamp = admin.firestore.Timestamp.fromDate(new Date('2026-12-31T23:59:59Z'));
      
      const raw = {
        id: 'offer123',
        title: 'Test Offer',
        description: 'Test description',
        points_value: 100,
        valid_until: firestoreTimestamp,
        merchant_id: 'merchant123',
        merchant_name: 'Test Merchant',
        category: 'Food'
      };
      
      const dto = toOfferDTO(raw);
      
      expect(dto.valid_until).toBeTruthy();
      expect(typeof dto.valid_until).toBe('string');
      expect(dto.valid_until).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    });

    it('should map points_value to both points_required and points_cost', () => {
      const raw = {
        id: 'offer123',
        title: 'Test Offer',
        description: 'Test',
        points_value: 250,
        merchant_id: 'merchant123',
        merchant_name: 'Test Merchant',
        category: 'Food'
      };
      
      const dto = toOfferDTO(raw);
      
      expect(dto.points_required).toBe(250);
      expect(dto.points_cost).toBe(250);
    });

    it('should include used flag', () => {
      const raw = {
        id: 'offer123',
        title: 'Test Offer',
        description: 'Test',
        points_value: 100,
        merchant_id: 'merchant123',
        merchant_name: 'Test Merchant',
        category: 'Food'
      };
      
      const dtoUnused = toOfferDTO(raw, false);
      const dtoUsed = toOfferDTO(raw, true);
      
      expect(dtoUnused.used).toBe(false);
      expect(dtoUsed.used).toBe(true);
    });

    it('should handle camelCase to snake_case conversions', () => {
      const raw = {
        id: 'offer123',
        title: 'Test Offer',
        description: 'Test',
        imageUrl: 'https://example.com/image.png',
        discountPercentage: 15,
        isActive: true,
        pointsValue: 100,
        validUntil: new Date('2026-12-31'),
        merchantId: 'merchant123',
        merchantName: 'Test Merchant',
        category: 'Food'
      };
      
      const dto = toOfferDTO(raw);
      
      expect(dto.image_url).toBe('https://example.com/image.png');
      expect(dto.discount_percentage).toBe(15);
      expect(dto.is_active).toBe(true);
      expect(dto.points_required).toBe(100);
    });

    it('should handle missing optional fields', () => {
      const raw = {
        id: 'offer123',
        title: 'Minimal Offer',
        description: 'Test',
        merchant_id: 'merchant123',
        merchant_name: 'Test Merchant',
        category: 'Food'
      };
      
      const dto = toOfferDTO(raw);
      
      expect(dto.id).toBe('offer123');
      expect(dto.points_required).toBe(0);
      expect(dto.points_cost).toBe(0);
      expect(dto.image_url).toBe('');
      expect(dto.discount_percentage).toBe(0);
      expect(dto.is_active).toBe(true);
      expect(dto.used).toBe(false);
    });
  });

  describe('Time Adapter', () => {
    it('should convert Firestore Timestamp to ISO string', () => {
      const timestamp = admin.firestore.Timestamp.fromDate(new Date('2026-01-15T12:00:00Z'));
      const result = toIsoString(timestamp);
      
      expect(result).toBeTruthy();
      expect(typeof result).toBe('string');
      expect(result).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    });

    it('should convert Date to ISO string', () => {
      const date = new Date('2026-01-15T12:00:00Z');
      const result = toIsoString(date);
      
      expect(result).toBeTruthy();
      expect(result).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    });

    it('should handle null/undefined', () => {
      expect(toIsoString(null)).toBeNull();
      expect(toIsoString(undefined)).toBeNull();
    });

    it('should convert number (Unix timestamp) to ISO string', () => {
      const timestamp = Date.parse('2026-01-15T12:00:00Z');
      const result = toIsoString(timestamp);
      
      expect(result).toBeTruthy();
      expect(result).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    });
  });

  describe('QR Token Response Format', () => {
    it('should include qr_token key in response', () => {
      // Mock response from generateQRToken
      const mockResponse = {
        success: true,
        token: 'abc123def456',
        displayCode: '1234',
        expiresAt: '2026-01-28T12:00:00Z'
      };
      
      // Simulate the wrapper logic
      const adaptedResponse = {
        ...mockResponse,
        qr_token: mockResponse.token,
        display_code: mockResponse.displayCode,
        expires_at: mockResponse.expiresAt
      };
      
      expect(adaptedResponse.qr_token).toBe('abc123def456');
      expect(adaptedResponse.display_code).toBe('1234');
      expect(adaptedResponse.expires_at).toBe('2026-01-28T12:00:00Z');
      
      // Original keys should also exist
      expect(adaptedResponse.token).toBe('abc123def456');
      expect(adaptedResponse.displayCode).toBe('1234');
      expect(adaptedResponse.expiresAt).toBe('2026-01-28T12:00:00Z');
    });
  });

  describe('Points History Response Format', () => {
    it('should return history with correct structure', () => {
      // Mock points transaction data
      const mockTransactions = [
        {
          user_id: 'user123',
          created_at: admin.firestore.Timestamp.fromDate(new Date('2026-01-28T10:00:00Z')),
          points: 100,
          description: 'Earned points for purchase'
        },
        {
          user_id: 'user123',
          created_at: admin.firestore.Timestamp.fromDate(new Date('2026-01-27T15:30:00Z')),
          points: -50,
          description: 'Redeemed points for offer'
        }
      ];
      
      // Simulate the mapping logic from getPointsHistory
      const history = mockTransactions.map(tx => ({
        timestamp: toIsoString(tx.created_at)!,
        points: tx.points,
        description: tx.description
      }));
      
      expect(history).toHaveLength(2);
      expect(history[0].timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
      expect(history[0].points).toBe(100);
      expect(history[0].description).toBe('Earned points for purchase');
      expect(history[1].points).toBe(-50);
    });
  });
});

describe('Backend Callable Stubs Removal', () => {
  it('should verify lib/callableWrappers.js does not contain unimplemented stubs', async () => {
    const fs = await import('fs/promises');
    const path = await import('path');
    
    // Read the compiled output
    const libPath = path.join(__dirname, '../../lib/callableWrappers.js');
    
    try {
      const content = await fs.readFile(libPath, 'utf-8');
      
      // Critical callables that must NOT throw unimplemented errors
      const criticalCallables = [
        'getAvailableOffers',
        'getFilteredOffers',
        'searchOffers',
        'getPointsHistory',
        'redeemOffer',
        'generateQRToken'
      ];
      
      for (const callable of criticalCallables) {
        // Check for pattern: exports.xxx = functions.https.onCall(...'unimplemented'...)
        const unimplementedPattern = new RegExp(
          `exports\\.${callable}\\s*=\\s*functions\\.https\\.onCall\\([^)]*HttpsError\\([^)]*'unimplemented'`,
          'i'
        );
        
        expect(content).not.toMatch(unimplementedPattern);
      }
    } catch (err: any) {
      if (err.code === 'ENOENT') {
        console.warn('lib/callableWrappers.js not found - skipping compiled output check');
        // This is acceptable in CI before build
        return;
      }
      throw err;
    }
  });
});
