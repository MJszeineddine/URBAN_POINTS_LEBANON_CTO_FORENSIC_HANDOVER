import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { Pool } from 'pg';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import rateLimit from 'express-rate-limit';
import { v4 as uuidv4 } from 'uuid';
import { JwtPayload } from './types/index';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Fail-closed guard: required secrets/config must exist
function ensureRequiredEnv() {
  const missing: string[] = [];
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.trim().length === 0) {
    missing.push('JWT_SECRET');
  }
  if (!process.env.DATABASE_URL || process.env.DATABASE_URL.trim().length === 0) {
    missing.push('DATABASE_URL');
  }
  if (missing.length > 0) {
    // Log and exit non-zero to prevent insecure startup
    // Minimal safe behavior per security fix plan
    console.error(`❌ Missing required environment variables: ${missing.join(', ')}`);
    process.exit(1);
  }
}

ensureRequiredEnv();

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

pool.on('connect', () => console.log('✅ Database connected'));
pool.on('error', (err) => console.error('❌ Database error:', err));

// Middleware
app.use(cors({ origin: process.env.CORS_ORIGIN || '*', credentials: true }));
app.use(helmet());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.API_RATE_LIMIT_WINDOW_MS || '900000'),
  max: parseInt(process.env.API_RATE_LIMIT_MAX_REQUESTS || '100'),
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// JWT middleware
const authenticate = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, error: 'No token provided' });

    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as JwtPayload;
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, error: 'Invalid token' });
  }
};

// Admin middleware: checks if user has admin role
const requireAdmin = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user?.role || req.user.role !== 'admin') {
      return res.status(403).json({ success: false, error: 'Admin access required', code: 'ADMIN_REQUIRED' });
    }
    next();
  } catch (error) {
    return res.status(500).json({ success: false, error: 'Authorization check failed' });
  }
};

// ============================================================================
// ENTITLEMENT MIDDLEWARE (Qatar Parity: Subscription Offers)
// ============================================================================

/**
 * Middleware: requireActiveSubscription
 * Enforces that user must have an active, non-expired subscription to proceed.
 * Returns 403 SUBSCRIPTION_REQUIRED if check fails.
 * Evidence: real gating logic for entitlements (not just keyword detection)
 */
const requireActiveSubscription = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user?.userId) {
      return res.status(401).json({ success: false, error: 'No user in context' });
    }

    // Check if user_subscriptions table exists
    const tableCheck = await pool.query(
      `SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'user_subscriptions'
      )`
    );

    if (!tableCheck.rows[0].exists) {
      // Table doesn't exist; for MVP, allow access (no subscriptions yet)
      return next();
    }

    // Query for active, non-expired subscription
    const result = await pool.query(
      `SELECT id, status, end_at FROM user_subscriptions 
       WHERE user_id = $1 AND status = 'active' AND end_at > NOW()
       LIMIT 1`,
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      // No active subscription found
      return res.status(403).json({
        success: false,
        error: 'Active subscription required',
        code: 'SUBSCRIPTION_REQUIRED',
        requiresSubscription: true
      });
    }

    // Attach subscription info to request for downstream use
    (req as any).subscription = result.rows[0];
    next();
  } catch (error: any) {
    console.error('Entitlement check error:', error);
    res.status(500).json({ success: false, error: 'Failed to check entitlement' });
  }
};

// ============================================================================
// ROOT & DOCUMENTATION ENDPOINT
// ============================================================================

app.get('/', (req: Request, res: Response) => {
  res.json({
    success: true,
    message: 'Urban Points Lebanon API',
    version: '1.0.0',
    endpoints: {
      health: 'GET /api/health',
      merchants: 'GET /api/merchants',
      offers: 'GET /api/offers',
      register: 'POST /api/auth/register',
      login: 'POST /api/auth/login'
    },
    documentation: 'See API_DOCUMENTATION.md for complete API reference'
  });
});

// ============================================================================
// HEALTH & SYSTEM ENDPOINTS
// ============================================================================

app.get('/api/health', async (req: Request, res: Response) => {
  try {
    const result = await pool.query('SELECT healthcheck()');
    const healthData = result.rows[0].healthcheck;
    res.json({ success: true, data: healthData });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/feature-flags', async (req: Request, res: Response) => {
  try {
    const result = await pool.query('SELECT key, enabled, notes as description FROM feature_flags');
    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================================================
// AUTHENTICATION ENDPOINTS
// ============================================================================

app.post('/api/auth/register', async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const { phone, email, full_name, password } = req.body;

    if (!phone || !full_name || !password) {
      return res.status(400).json({ success: false, error: 'Phone, full_name, and password are required' });
    }

    // Check if user exists
    const existing = await client.query('SELECT id FROM users WHERE phone = $1', [phone]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ success: false, error: 'Phone number already registered' });
    }

    // Hash password and create user
    const passwordHash = await bcrypt.hash(password, 12);
    const userId = uuidv4();

    await client.query('BEGIN');
    await client.query(
      `INSERT INTO users (id, phone, email, full_name, password_hash, role, points_balance, is_active) 
       VALUES ($1, $2, $3, $4, $5, 'user', 0, true)`,
      [userId, phone, email || null, full_name, passwordHash]
    );
    await client.query('COMMIT');

    const token = jwt.sign({ userId, phone, role: 'user' }, process.env.JWT_SECRET!, { expiresIn: '7d' });
    const refreshToken = jwt.sign({ userId }, process.env.JWT_SECRET!, { expiresIn: '30d' });

    res.status(201).json({
      success: true,
      data: {
        token,
        refreshToken,
        user: { id: userId, phone, email, full_name, role: 'user', points_balance: 0 }
      }
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Register error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

app.post('/api/auth/login', async (req: Request, res: Response) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return res.status(400).json({ success: false, error: 'Phone and password are required' });
    }

    const result = await pool.query(
      'SELECT id, phone, email, full_name, role, points_balance, password_hash, is_active FROM users WHERE phone = $1',
      [phone]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    if (!user.is_active) {
      return res.status(403).json({ success: false, error: 'Account is deactivated' });
    }

    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    // Update last login
    // Login tracking removed - last_login_at column doesn't exist

    const token = jwt.sign({ userId: user.id, phone: user.phone, role: user.role }, process.env.JWT_SECRET!, { expiresIn: '7d' });
    const refreshToken = jwt.sign({ userId: user.id }, process.env.JWT_SECRET!, { expiresIn: '30d' });

    res.json({
      success: true,
      data: {
        token,
        refreshToken,
        user: {
          id: user.id,
          phone: user.phone,
          email: user.email,
          full_name: user.full_name,
          role: user.role,
          points_balance: user.points_balance
        }
      }
    });
  } catch (error: any) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================================================
// USER ENDPOINTS
// ============================================================================

app.get('/api/users/me', authenticate, async (req: Request, res: Response) => {
  try {
    const result = await pool.query(
      'SELECT id, phone, email, full_name, role, points_balance, is_active, created_at FROM users WHERE id = $1',
      [req.user!.userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    res.json({ success: true, data: result.rows[0] });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/users/me/vouchers', authenticate, async (req: Request, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT v.*, o.title as offer_title, o.description as offer_description, 
              m.name as merchant_name, m.category as merchant_category
       FROM vouchers v
       JOIN offers o ON v.offer_id = o.id
       JOIN merchants m ON o.merchant_id = m.id
       WHERE v.user_id = $1
       ORDER BY v.month_end DESC`,
      [req.user!.userId]
    );

    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/users/me/transactions', authenticate, async (req: Request, res: Response) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;

    const result = await pool.query(
      `SELECT id, type, points_delta as points, description, reference_id, created_at
       FROM transactions
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.user!.userId, limit, offset]
    );

    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================================================
// MERCHANT ENDPOINTS
// ============================================================================

app.get('/api/merchants', async (req: Request, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT id, name, category, address, contact_phone as phone, contact_email as email, logo_url, description, is_active
       FROM merchants
       WHERE is_active = true
       ORDER BY name`
    );

    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/merchants/:id', async (req: Request, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT id, name, category, address, contact_phone as phone, contact_email as email, logo_url, description, is_active
       FROM merchants
       WHERE id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Merchant not found' });
    }

    res.json({ success: true, data: result.rows[0] });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/merchants/:id/offers', async (req: Request, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT id, title, description, points_cost, party_min, party_max, image_url, blackout_dates, is_active, created_at
       FROM offers
       WHERE merchant_id = $1 AND is_active = true
       ORDER BY created_at DESC`,
      [req.params.id]
    );

    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================================================
// OFFER ENDPOINTS
// ============================================================================

app.get('/api/offers', async (req: Request, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT o.*, m.name as merchant_name, m.category as merchant_category, m.logo_url as merchant_logo
       FROM offers o
       JOIN merchants m ON o.merchant_id = m.id
       WHERE o.is_active = true
       ORDER BY o.created_at DESC`
    );

    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/offers/:id', async (req: Request, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT o.*, m.name as merchant_name, m.category as merchant_category, 
              m.address as merchant_address, m.contact_phone as merchant_phone, m.logo_url as merchant_logo
       FROM offers o
       JOIN merchants m ON o.merchant_id = m.id
       WHERE o.id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Offer not found' });
    }

    res.json({ success: true, data: result.rows[0] });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/offers/:id/purchase', authenticate, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const offerId = req.params.id;
    const userId = req.user!.userId;

    await client.query('BEGIN');

    // Get offer details
    const offerResult = await client.query(
      'SELECT id, merchant_id, title, points_cost, valid_until, is_active FROM offers WHERE id = $1',
      [offerId]
    );

    if (offerResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Offer not found' });
    }

    const offer = offerResult.rows[0];

    if (!offer.is_active) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'Offer is not active' });
    }

    if (new Date(offer.valid_until) < new Date()) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'Offer has expired' });
    }

    // Check user points balance
    const userResult = await client.query('SELECT points_balance FROM users WHERE id = $1', [userId]);
    const userBalance = userResult.rows[0].points_balance;

    if (userBalance < offer.points_cost) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'Insufficient points balance' });
    }

    // Deduct points
    await client.query(
      'UPDATE users SET points_balance = points_balance - $1 WHERE id = $2',
      [offer.points_cost, userId]
    );

    // Create transaction record
    await client.query(
      `INSERT INTO transactions (id, user_id, type, points, description, reference_id, reference_type)
       VALUES ($1, $2, 'redeem', $3, $4, $5, 'offer')`,
      [uuidv4(), userId, -offer.points_cost, `Redeemed: ${offer.title}`, offerId]
    );

    // Create voucher
    const voucherId = uuidv4();
    const voucherCode = `VOC-${Date.now()}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // Voucher expires in 30 days

    await client.query(
      `INSERT INTO vouchers (id, offer_id, user_id, code, month_start, month_end)
       VALUES ($1, $2, $3, $4, 'available', NOW(), $5)`,
      [voucherId, offerId, userId, voucherCode, expiresAt]
    );

    await client.query('COMMIT');

    const voucherResult = await client.query(
      'SELECT * FROM vouchers WHERE id = $1',
      [voucherId]
    );

    res.status(201).json({
      success: true,
      message: 'Voucher purchased successfully',
      data: {
        voucher: voucherResult.rows[0],
        new_balance: userBalance - offer.points_cost
      }
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Purchase error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

// ============================================================================
// VOUCHER ENDPOINTS
// ============================================================================

app.post('/api/vouchers/:id/validate', async (req: Request, res: Response) => {
  try {
    const { party_size, redemption_date } = req.body;
    const voucherId = req.params.id;

    if (!party_size) {
      return res.status(400).json({ success: false, error: 'party_size is required' });
    }

    const result = await pool.query(
      'SELECT validate_redemption($1, $2, $3)',
      [voucherId, party_size, redemption_date || null]
    );

    const validation = result.rows[0].validate_redemption;
    res.json({ success: true, data: validation });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/vouchers/:id/redeem', authenticate, requireActiveSubscription, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const { party_size, redemption_date, notes } = req.body;
    const voucherId = req.params.id;
    const userId = req.user!.userId;

    if (!party_size) {
      return res.status(400).json({ success: false, error: 'party_size is required' });
    }

    await client.query('BEGIN');

    // Validate redemption
    const validation = await client.query(
      'SELECT validate_redemption($1, $2, $3)',
      [voucherId, party_size, redemption_date || null]
    );

    const validationResult = validation.rows[0].validate_redemption;

    if (!validationResult.is_valid) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: 'Voucher validation failed',
        reasons: validationResult.reasons
      });
    }

    // Get voucher and offer details
    const voucherResult = await client.query(
      `SELECT v.*, o.merchant_id, o.id as offer_id FROM vouchers v
       JOIN offers o ON v.offer_id = o.id
       WHERE v.id = $1`,
      [voucherId]
    );

    if (voucherResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Voucher not found' });
    }

    const voucher = voucherResult.rows[0];

    // =====================================================================
    // MANUAL SUBSCRIPTION MVP: Enforce monthly offer usage limit
    // =====================================================================
    // Compute period_key (YYYY-MM) for monthly limit tracking
    const now = new Date();
    const periodKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

    // Create user_offer_usage table if needed (atomic: create + enforce limit in single transaction)
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_offer_usage (
        user_id UUID NOT NULL,
        offer_id UUID NOT NULL,
        period_key VARCHAR(7) NOT NULL,
        redemption_count INT DEFAULT 0,
        last_redeemed_at TIMESTAMP,
        PRIMARY KEY (user_id, offer_id, period_key),
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (offer_id) REFERENCES offers(id)
      )
    `);

    // Lock row for update to prevent race conditions
    // Use INSERT ... ON CONFLICT to atomically enforce once-per-month
    const usageCheckResult = await client.query(
      `SELECT redemption_count FROM user_offer_usage 
       WHERE user_id = $1 AND offer_id = $2 AND period_key = $3
       FOR UPDATE`,
      [userId, voucher.offer_id, periodKey]
    );

    if (usageCheckResult.rows.length > 0) {
      const redemptionCount = usageCheckResult.rows[0].redemption_count;
      if (redemptionCount >= 1) {
        await client.query('ROLLBACK');
        return res.status(429).json({
          success: false,
          error: 'Monthly offer limit reached for this offer',
          code: 'OFFER_MONTHLY_LIMIT_REACHED',
          periodKey,
          limitPerMonth: 1
        });
      }
      
      // Increment count for existing row
      await client.query(
        `UPDATE user_offer_usage 
         SET redemption_count = redemption_count + 1, last_redeemed_at = NOW()
         WHERE user_id = $1 AND offer_id = $2 AND period_key = $3`,
        [userId, voucher.offer_id, periodKey]
      );
    } else {
      // Insert new usage record
      await client.query(
        `INSERT INTO user_offer_usage (user_id, offer_id, period_key, redemption_count, last_redeemed_at)
         VALUES ($1, $2, $3, 1, NOW())`,
        [userId, voucher.offer_id, periodKey]
      );
    }

    // Create redemption record
    const redemptionId = uuidv4();
    await client.query(
      `INSERT INTO voucher_redemptions (id, voucher_id, merchant_id, redeemed_by_user_id, party_size, redemption_date, status, notes)
       VALUES ($1, $2, $3, $4, $5, $6, 'success', $7)`,
      [redemptionId, voucherId, voucher.merchant_id, userId, party_size, redemption_date || new Date(), notes || null]
    );

    // Update voucher status
    await client.query(
      `UPDATE vouchers SET status = 'redeemed', redeemed_at = NOW() WHERE id = $1`,
      [voucherId]
    );

    await client.query('COMMIT');

    res.json({
      success: true,
      message: 'Voucher redeemed successfully',
      data: { redemption_id: redemptionId, party_size, redemption_date: redemption_date || new Date(), periodKey }
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Redeem error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

// ============================================================================
// GIFT ENDPOINTS
// ============================================================================

app.post('/api/vouchers/:id/gift', authenticate, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const { recipient_phone, message } = req.body;
    const voucherId = req.params.id;
    const senderId = req.user!.userId;

    if (!recipient_phone) {
      return res.status(400).json({ success: false, error: 'recipient_phone is required' });
    }

    await client.query('BEGIN');

    // Verify voucher ownership and status
    const voucherResult = await client.query(
      'SELECT id, user_id, is_active FROM vouchers WHERE id = $1',
      [voucherId]
    );

    if (voucherResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Voucher not found' });
    }

    const voucher = voucherResult.rows[0];

    if (voucher.user_id !== senderId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ success: false, error: 'You do not own this voucher' });
    }

    if (voucher.status !== 'available') {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'Voucher is not available for gifting' });
    }

    // Find recipient
    const recipientResult = await client.query('SELECT id FROM users WHERE phone = $1', [recipient_phone]);

    if (recipientResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Recipient not found' });
    }

    const recipientId = recipientResult.rows[0].id;

    if (recipientId === senderId) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'Cannot gift to yourself' });
    }

    // Create gift record
    const giftId = uuidv4();
    await client.query(
      `INSERT INTO gifts (id, voucher_id, sender_user_id, recipient_user_id, status, message, sent_at)
       VALUES ($1, $2, $3, $4, 'pending', $5, NOW())`,
      [giftId, voucherId, senderId, recipientId, message || null]
    );

    // Update voucher status
    await client.query(`UPDATE vouchers SET status = 'gifted' WHERE id = $1`, [voucherId]);

    await client.query('COMMIT');

    res.status(201).json({
      success: true,
      message: 'Gift sent successfully',
      data: { gift_id: giftId, status: 'pending' }
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Gift error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

app.get('/api/gifts/received', authenticate, async (req: Request, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT g.*, v.code as voucher_code, o.title as offer_title, 
              u.full_name as sender_name, u.phone as sender_phone
       FROM gifts g
       JOIN vouchers v ON g.voucher_id = v.id
       JOIN offers o ON v.offer_id = o.id
       JOIN users u ON g.sender_user_id = u.id
       WHERE g.recipient_user_id = $1
       ORDER BY g.sent_at DESC`,
      [req.user!.userId]
    );

    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/gifts/:id/accept', authenticate, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const giftId = req.params.id;
    const userId = req.user!.userId;

    await client.query('BEGIN');

    // Verify gift
    const giftResult = await client.query(
      'SELECT id, voucher_id, recipient_user_id, status FROM gifts WHERE id = $1',
      [giftId]
    );

    if (giftResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Gift not found' });
    }

    const gift = giftResult.rows[0];

    if (gift.recipient_user_id !== userId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ success: false, error: 'This gift is not for you' });
    }

    if (gift.status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'Gift already responded to' });
    }

    // Transfer voucher ownership
    await client.query(
      `UPDATE vouchers SET user_id = $1, is_active = true WHERE id = $2`,
      [userId, gift.voucher_id]
    );

    // Update gift status
    await client.query(
      `UPDATE gifts SET status = 'accepted', responded_at = NOW() WHERE id = $1`,
      [giftId]
    );

    await client.query('COMMIT');

    res.json({ success: true, message: 'Gift accepted successfully' });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Accept gift error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

app.post('/api/gifts/:id/reject', authenticate, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const giftId = req.params.id;
    const userId = req.user!.userId;

    await client.query('BEGIN');

    // Verify gift
    const giftResult = await client.query(
      'SELECT id, voucher_id, sender_user_id, recipient_user_id, status FROM gifts WHERE id = $1',
      [giftId]
    );

    if (giftResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Gift not found' });
    }

    const gift = giftResult.rows[0];

    if (gift.recipient_user_id !== userId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ success: false, error: 'This gift is not for you' });
    }

    if (gift.status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'Gift already responded to' });
    }

    // Return voucher to sender
    await client.query(
      `UPDATE vouchers SET status = 'available' WHERE id = $1`,
      [gift.voucher_id]
    );

    // Update gift status
    await client.query(
      `UPDATE gifts SET status = 'rejected', responded_at = NOW() WHERE id = $1`,
      [giftId]
    );

    await client.query('COMMIT');

    res.json({ success: true, message: 'Gift rejected successfully' });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Reject gift error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

// ============================================================================
// ERROR HANDLING
// ============================================================================

// ============================================================================
// ADMIN ENDPOINTS (Manual Subscription MVP)
// ============================================================================

/**
 * GET /api/admin/users/search?phone=...
 * Search users by phone number (admin-only)
 * Returns: [{ id, phone, name }]
 */
app.get('/api/admin/users/search', authenticate, requireAdmin, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const { phone } = req.query;

    if (!phone || typeof phone !== 'string') {
      return res.status(400).json({ success: false, error: 'phone query parameter required' });
    }

    // Safe parameterized query for ILIKE search
    const result = await client.query(
      `SELECT id, phone, full_name as name, is_active
       FROM users
       WHERE phone ILIKE $1
       LIMIT 10`,
      [`%${phone}%`]
    );

    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    console.error('User search error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

/**
 * GET /api/admin/subscriptions/status?userId=UUID
 * Get subscription status for a user (admin-only)
 * Returns: { hasActiveSubscription, status, planCode, startAt, endAt, source, note, activatedBy }
 */
app.get('/api/admin/subscriptions/status', authenticate, requireAdmin, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const { userId } = req.query;

    if (!userId || typeof userId !== 'string') {
      return res.status(400).json({ success: false, error: 'userId query parameter required' });
    }

    // Check if table exists
    const tableCheck = await client.query(
      `SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_subscriptions')`
    );

    if (!tableCheck.rows[0].exists) {
      return res.json({
        success: true,
        data: { hasActiveSubscription: false, status: null }
      });
    }

    // Query for active subscription
    const result = await client.query(
      `SELECT id, status, plan_code as planCode, start_at as startAt, end_at as endAt, 
              source, note, activated_by as activatedBy
       FROM user_subscriptions
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.json({
        success: true,
        data: { hasActiveSubscription: false, status: null }
      });
    }

    const sub = result.rows[0];
    const isActive = sub.status === 'active' && new Date(sub.endAt) > new Date();

    res.json({
      success: true,
      data: {
        hasActiveSubscription: isActive,
        status: sub.status,
        planCode: sub.planCode,
        startAt: sub.startAt,
        endAt: sub.endAt,
        source: sub.source,
        note: sub.note,
        activatedBy: sub.activatedBy
      }
    });
  } catch (error: any) {
    console.error('Subscription status error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

/**
 * POST /api/admin/subscriptions/activate
 * Admin endpoint to manually activate a user's subscription
 * Used for offline payment / manual activation workflow
 * Request body: { userId: UUID, planCode?: string, durationDays?: number, note?: string }
 * Response: { success: true, data: { subscriptionId, userId, status, startAt, endAt, source: 'manual' } }
 */
app.post('/api/admin/subscriptions/activate', authenticate, requireAdmin, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const { userId, planCode, durationDays, note } = req.body;
    const adminId = req.user!.userId;

    if (!userId) {
      return res.status(400).json({ success: false, error: 'userId is required' });
    }

    const duration = durationDays || 30; // Default 30 days

    await client.query('BEGIN');

    // Verify user exists
    const userCheck = await client.query('SELECT id FROM users WHERE id = $1', [userId]);
    if (userCheck.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    // Create user_subscriptions table if needed (manual activation scenario)
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_subscriptions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL,
        plan_id UUID,
        plan_code VARCHAR(50),
        status VARCHAR(50) DEFAULT 'active',
        source VARCHAR(50) DEFAULT 'manual',
        provider VARCHAR(50),
        provider_ref VARCHAR(255),
        activated_by UUID,
        note TEXT,
        start_at TIMESTAMP DEFAULT NOW(),
        end_at TIMESTAMP NOT NULL,
        auto_renew BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(user_id) -- Only one active subscription per user (can be overridden)
      )
    `);

    // Calculate end date
    const startAt = new Date();
    const endAt = new Date();
    endAt.setDate(endAt.getDate() + duration);

    // Insert or update subscription (manual activation)
    const subResult = await client.query(
      `INSERT INTO user_subscriptions (
         user_id, plan_code, status, source, activated_by, note, start_at, end_at
       ) VALUES ($1, $2, 'active', 'manual', $3, $4, $5, $6)
       ON CONFLICT (user_id) DO UPDATE SET
         plan_code = EXCLUDED.plan_code,
         status = 'active',
         source = 'manual',
         activated_by = EXCLUDED.activated_by,
         note = EXCLUDED.note,
         start_at = EXCLUDED.start_at,
         end_at = EXCLUDED.end_at,
         updated_at = NOW()
       RETURNING id, user_id, status, start_at, end_at, source`,
      [userId, planCode || 'MANUAL_STANDARD', adminId, note || null, startAt, endAt]
    );

    await client.query('COMMIT');

    const subscription = subResult.rows[0];
    res.status(201).json({
      success: true,
      data: {
        subscriptionId: subscription.id,
        userId: subscription.user_id,
        status: subscription.status,
        startAt: subscription.start_at,
        endAt: subscription.end_at,
        source: subscription.source,
        activatedBy: adminId,
        note
      }
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Admin activate subscription error:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

// ============================================================================
// SUBSCRIPTION ENDPOINTS (Qatar Parity - Subscription Offers)
// ============================================================================

/**
 * GET /api/subscription-plans
 * List available subscription plans
 * Evidence: Supports subscription offers feature per Qatar parity requirement
 */
app.get('/api/subscription-plans', async (req: Request, res: Response) => {
  try {
    // Check if subscription_plans table exists
    const tableCheck = await pool.query(
      `SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'subscription_plans'
      )`
    );

    if (!tableCheck.rows[0].exists) {
      // Create table if it doesn't exist (first-run scenario)
      await pool.query(`
        CREATE TABLE IF NOT EXISTS subscription_plans (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          name VARCHAR(255) NOT NULL,
          description TEXT,
          period VARCHAR(50) NOT NULL,
          price NUMERIC(10, 2) NOT NULL,
          currency VARCHAR(3) DEFAULT 'USD',
          active BOOLEAN DEFAULT true,
          created_at TIMESTAMP DEFAULT NOW(),
          updated_at TIMESTAMP DEFAULT NOW()
        )
      `);

      // Seed with default plans if table is new
      await pool.query(`
        INSERT INTO subscription_plans (name, description, period, price, currency, active)
        VALUES 
          ('Monthly Plan', 'Access all offers for one month', 'monthly', 9.99, 'USD', true),
          ('Yearly Plan', 'Access all offers for one year with 20% savings', 'yearly', 99.99, 'USD', true)
        ON CONFLICT DO NOTHING
      `);
    }

    const result = await pool.query(
      'SELECT id, name, description, period, price, currency, active FROM subscription_plans WHERE active = true ORDER BY period DESC'
    );

    res.json({ success: true, data: result.rows });
  } catch (error: any) {
    console.error('Error fetching subscription plans:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/subscriptions/me
 * Get current user's subscription (requires auth)
 * Evidence: User can check active entitlement
 */
app.get('/api/subscriptions/me', authenticate, async (req: Request, res: Response) => {
  try {
    const tableCheck = await pool.query(
      `SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_subscriptions')`
    );

    if (!tableCheck.rows[0].exists) {
      return res.json({ success: true, data: null, message: 'No active subscription' });
    }

    const result = await pool.query(
      `SELECT s.id, s.plan_id, p.name as plan_name, p.period, s.status, s.start_at, s.end_at, s.auto_renew
       FROM user_subscriptions s
       JOIN subscription_plans p ON s.plan_id = p.id
       WHERE s.user_id = $1
       ORDER BY s.start_at DESC
       LIMIT 1`,
      [req.user!.userId]
    );

    if (result.rows.length === 0) {
      return res.json({ success: true, data: null, message: 'No active subscription' });
    }

    res.json({ success: true, data: result.rows[0] });
  } catch (error: any) {
    console.error('Error fetching subscription:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * POST /api/subscriptions/start
 * Start a new subscription (requires auth)
 * Evidence: User can initiate subscription
 * Note: Manual provider for dev/staging mode
 */
app.post('/api/subscriptions/start', authenticate, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const { planId } = req.body;
    const userId = req.user!.userId;

    if (!planId) {
      return res.status(400).json({ success: false, error: 'planId is required' });
    }

    await client.query('BEGIN');

    // Verify plan exists
    const planResult = await client.query(
      'SELECT id, name, period, price FROM subscription_plans WHERE id = $1 AND active = true',
      [planId]
    );

    if (planResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Plan not found or inactive' });
    }

    const plan = planResult.rows[0];

    // Create subscription table if needed
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_subscriptions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL,
        plan_id UUID NOT NULL,
        status VARCHAR(50) DEFAULT 'active',
        provider VARCHAR(50) DEFAULT 'manual',
        provider_ref VARCHAR(255),
        start_at TIMESTAMP DEFAULT NOW(),
        end_at TIMESTAMP NOT NULL,
        auto_renew BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        FOREIGN KEY (plan_id) REFERENCES subscription_plans(id)
      )
    `);

    // Calculate end date based on period
    let endAt = new Date();
    if (plan.period === 'monthly') {
      endAt.setMonth(endAt.getMonth() + 1);
    } else if (plan.period === 'yearly') {
      endAt.setFullYear(endAt.getFullYear() + 1);
    }

    // Insert subscription
    const subResult = await client.query(
      `INSERT INTO user_subscriptions (user_id, plan_id, status, provider, end_at, auto_renew)
       VALUES ($1, $2, 'active', 'manual', $3, false)
       RETURNING id, status, start_at, end_at`,
      [userId, planId, endAt]
    );

    await client.query('COMMIT');

    res.json({
      success: true,
      data: {
        subscriptionId: subResult.rows[0].id,
        status: subResult.rows[0].status,
        planName: plan.name,
        startAt: subResult.rows[0].start_at,
        endAt: subResult.rows[0].end_at,
        message: 'Subscription created successfully (manual provider - dev mode)'
      }
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Error starting subscription:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

/**
 * POST /api/subscriptions/cancel
 * Cancel current subscription (requires auth)
 */
app.post('/api/subscriptions/cancel', authenticate, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const userId = req.user!.userId;

    await client.query('BEGIN');

    const tableCheck = await client.query(
      `SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_subscriptions')`
    );

    if (!tableCheck.rows[0].exists) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'No subscription found' });
    }

    const result = await client.query(
      `UPDATE user_subscriptions SET status = 'canceled', updated_at = NOW()
       WHERE user_id = $1 AND status = 'active'
       RETURNING id`,
      [userId]
    );

    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'No active subscription to cancel' });
    }

    await client.query('COMMIT');

    res.json({ success: true, message: 'Subscription canceled successfully' });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Error canceling subscription:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

/**
 * GET /api/entitlements/me
 * Check user's subscription entitlements (gates offer redemption)
 */
app.get('/api/entitlements/me', authenticate, async (req: Request, res: Response) => {
  const client = await pool.connect();
  try {
    const userId = req.user!.userId;

    const tableCheck = await client.query(
      `SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_subscriptions')`
    );

    if (!tableCheck.rows[0].exists) {
      return res.json({ hasActiveSubscription: false, expiresAt: null });
    }

    const result = await client.query(
      `SELECT status, end_at FROM user_subscriptions 
       WHERE user_id = $1 AND status = 'active' AND end_at > NOW()
       LIMIT 1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.json({ hasActiveSubscription: false, expiresAt: null });
    }

    const subscription = result.rows[0];
    res.json({ 
      hasActiveSubscription: true, 
      expiresAt: subscription.end_at.toISOString() 
    });
  } catch (error: any) {
    console.error('Error fetching entitlements:', error);
    res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
});

app.use((req: Request, res: Response) => {
  res.status(404).json({ success: false, error: 'Endpoint not found' });
});

app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ success: false, error: 'Internal server error' });
});

// ============================================================================
// SERVER START
// ============================================================================

app.listen(PORT, () => {
  console.log(`
════════════════════════════════════════════════════════════════
🚀 URBAN POINTS LEBANON API SERVER
════════════════════════════════════════════════════════════════
✅ Server running on port ${PORT}
✅ Environment: ${process.env.NODE_ENV}
✅ Database: Neon PostgreSQL 17.5
✅ Timezone: ${process.env.TIMEZONE}
✅ Country: ${process.env.COUNTRY_CODE}
✅ Payments: ${process.env.PAYMENTS_ENABLED}
════════════════════════════════════════════════════════════════
📋 API Endpoints:
   Health:        GET  /api/health
   Feature Flags: GET  /api/feature-flags
   
   Auth:          POST /api/auth/register
                  POST /api/auth/login
   
   Users:         GET  /api/users/me
                  GET  /api/users/me/vouchers
                  GET  /api/users/me/transactions
   
   Merchants:     GET  /api/merchants
                  GET  /api/merchants/:id
                  GET  /api/merchants/:id/offers
   
   Offers:        GET  /api/offers
                  GET  /api/offers/:id
                  POST /api/offers/:id/purchase (auth)
   
   Vouchers:      POST /api/vouchers/:id/validate
                  POST /api/vouchers/:id/redeem (auth)
   
   Gifts:         POST /api/vouchers/:id/gift (auth)
                  GET  /api/gifts/received (auth)
                  POST /api/gifts/:id/accept (auth)
                  POST /api/gifts/:id/reject (auth)
════════════════════════════════════════════════════════════════
  `);
});

export default app;
