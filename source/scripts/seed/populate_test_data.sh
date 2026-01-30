#!/bin/bash
# Urban Points Lebanon - Test Data Population Script
# Populates Firebase Firestore with sample test data

set -e

echo "🌱 Urban Points Lebanon - Test Data Seeding"
echo "============================================"

# Check if Firebase CLI is available
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install: npm install -g firebase-tools"
    exit 1
fi

# Check if project is selected
FIREBASE_PROJECT=$(firebase use 2>&1 | grep "Active Project" | awk '{print $3}')
if [ -z "$FIREBASE_PROJECT" ]; then
    echo "❌ No Firebase project selected. Run: firebase use urbangenspark"
    exit 1
fi

echo "✅ Using Firebase project: $FIREBASE_PROJECT"
echo ""

# Sample Customers
echo "👥 Creating sample customers..."
firebase firestore:update customers customer_001 '{
  "email": "john.doe@example.com",
  "phone": "+96170123456",
  "name": "John Doe",
  "points_balance": 1500,
  "tier": "gold",
  "referral_code": "JOHN2024",
  "status": "active",
  "created_at": "2024-01-15T10:00:00Z"
}' || echo "⚠️ Customer creation skipped (may already exist)"

firebase firestore:update customers customer_002 '{
  "email": "jane.smith@example.com",
  "phone": "+96170123457",
  "name": "Jane Smith",
  "points_balance": 800,
  "tier": "silver",
  "referral_code": "JANE2024",
  "status": "active",
  "created_at": "2024-02-20T14:30:00Z"
}' || echo "⚠️ Customer creation skipped"

# Sample Merchants
echo "🏪 Creating sample merchants..."
firebase firestore:update merchants merchant_001 '{
  "business_name": "Downtown Coffee House",
  "email": "coffee@example.com",
  "phone": "+96170987654",
  "category": "cafe",
  "status": "active",
  "subscription_tier": "premium",
  "subscription_expiry": "2025-12-31T23:59:59Z",
  "location": {
    "address": "Hamra Street, Beirut",
    "latitude": 33.8959,
    "longitude": 35.4783
  },
  "created_at": "2024-01-01T09:00:00Z"
}' || echo "⚠️ Merchant creation skipped"

firebase firestore:update merchants merchant_002 '{
  "business_name": "Healthy Bites Restaurant",
  "email": "healthybites@example.com",
  "phone": "+96170987655",
  "category": "restaurant",
  "status": "active",
  "subscription_tier": "basic",
  "subscription_expiry": "2025-06-30T23:59:59Z",
  "location": {
    "address": "Verdun, Beirut",
    "latitude": 33.8704,
    "longitude": 35.4831
  },
  "created_at": "2024-01-10T11:00:00Z"
}' || echo "⚠️ Merchant creation skipped"

# Sample Offers
echo "🎁 Creating sample offers..."
firebase firestore:update offers offer_001 '{
  "merchant_id": "merchant_001",
  "title": "Free Coffee with Pastry",
  "description": "Buy any pastry and get a free coffee",
  "points_cost": 200,
  "discount_type": "free_item",
  "discount_value": 0,
  "category": "food_drink",
  "status": "active",
  "start_date": "2024-11-01T00:00:00Z",
  "end_date": "2025-12-31T23:59:59Z",
  "redemption_count": 45,
  "created_at": "2024-11-01T08:00:00Z"
}' || echo "⚠️ Offer creation skipped"

firebase firestore:update offers offer_002 '{
  "merchant_id": "merchant_002",
  "title": "20% Off Healthy Meals",
  "description": "Get 20% discount on all healthy meal options",
  "points_cost": 150,
  "discount_type": "percentage",
  "discount_value": 20,
  "category": "food_drink",
  "status": "active",
  "start_date": "2024-11-15T00:00:00Z",
  "end_date": "2025-11-30T23:59:59Z",
  "redemption_count": 78,
  "created_at": "2024-11-15T10:00:00Z"
}' || echo "⚠️ Offer creation skipped"

echo ""
echo "✅ Test data population complete!"
echo ""
echo "📊 Created:"
echo "  • 2 Sample Customers (John Doe, Jane Smith)"
echo "  • 2 Sample Merchants (Downtown Coffee House, Healthy Bites)"
echo "  • 2 Sample Offers (Free Coffee, 20% Off Meals)"
echo ""
echo "🔗 View data in Firebase Console:"
echo "  https://console.firebase.google.com/project/$FIREBASE_PROJECT/firestore"
