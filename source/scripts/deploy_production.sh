#!/bin/bash

# ============================================================================
# Urban Points Lebanon - Production Deployment Script
# Project: urbangenspark
# Generated: Autonomous Deployment Session
# ============================================================================

set -e  # Exit on error

PROJECT_ID="urbangenspark"
REGION="us-central1"

echo "============================================================================"
echo "Urban Points Lebanon - Production Deployment"
echo "Project: $PROJECT_ID"
echo "============================================================================"
echo ""

# ============================================================================
# STEP 1: Pre-Deployment Validation
# ============================================================================

echo "STEP 1: Pre-Deployment Validation"
echo "-----------------------------------"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ ERROR: Firebase CLI not installed"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI installed: $(firebase --version)"

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ ERROR: Not logged in to Firebase"
    echo "Run: firebase login"
    exit 1
fi

echo "✅ Firebase authentication valid"

# Validate project selection
CURRENT_PROJECT=$(firebase use | grep "active project" | awk '{print $NF}')
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    echo "⚠️  WARNING: Current project is $CURRENT_PROJECT, switching to $PROJECT_ID"
    firebase use $PROJECT_ID
fi

echo "✅ Project: $PROJECT_ID"
echo ""

# ============================================================================
# STEP 2: Build Cloud Functions
# ============================================================================

echo "STEP 2: Building Cloud Functions"
echo "---------------------------------"

cd functions

# Install dependencies
echo "📦 Installing dependencies..."
npm ci

# Build TypeScript
echo "🔨 Compiling TypeScript..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Cloud Functions build failed"
    exit 1
fi

echo "✅ Cloud Functions build successful"
echo ""

cd ..

# ============================================================================
# STEP 3: Deploy Firestore Rules
# ============================================================================

echo "STEP 3: Deploying Firestore Rules"
echo "----------------------------------"

echo "📋 Deploying security rules..."
firebase deploy --only firestore:rules --project $PROJECT_ID

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Firestore rules deployment failed"
    exit 1
fi

echo "✅ Firestore rules deployed successfully"
echo ""

# ============================================================================
# STEP 4: Deploy Firestore Indexes
# ============================================================================

echo "STEP 4: Deploying Firestore Indexes"
echo "------------------------------------"

echo "📊 Deploying indexes..."
firebase deploy --only firestore:indexes --project $PROJECT_ID

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Firestore indexes deployment failed"
    exit 1
fi

echo "✅ Firestore indexes deployed successfully"
echo ""

# ============================================================================
# STEP 5: Deploy Cloud Functions
# ============================================================================

echo "STEP 5: Deploying Cloud Functions"
echo "----------------------------------"

echo "☁️  Deploying 19 Cloud Functions..."
echo "This may take 5-10 minutes..."
firebase deploy --only functions --project $PROJECT_ID

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Cloud Functions deployment failed"
    exit 1
fi

echo "✅ Cloud Functions deployed successfully"
echo ""

# ============================================================================
# STEP 6: Verify Deployment
# ============================================================================

echo "STEP 6: Verifying Deployment"
echo "-----------------------------"

echo "🔍 Listing deployed functions..."
firebase functions:list --project $PROJECT_ID

echo ""
echo "🔍 Checking Firestore rules..."
firebase firestore:rules:get --project $PROJECT_ID | head -20

echo ""

# ============================================================================
# DEPLOYMENT COMPLETE
# ============================================================================

echo "============================================================================"
echo "✅ DEPLOYMENT COMPLETE"
echo "============================================================================"
echo ""
echo "Deployed Resources:"
echo "  ✅ Firestore Security Rules"
echo "  ✅ Firestore Indexes (15 composite indexes)"
echo "  ✅ Cloud Functions (19 functions)"
echo ""
echo "Next Steps:"
echo "  1. Configure payment gateway webhooks (see DEPLOYMENT_GUIDE.md Section 4.4)"
echo "  2. Set up Firebase environment variables (see DEPLOYMENT_GUIDE.md Section 3.1)"
echo "  3. Test critical flows (QR redemption, subscription, points)"
echo "  4. Monitor Cloud Functions logs: firebase functions:log --project $PROJECT_ID"
echo ""
echo "Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID"
echo "============================================================================"
