# Urban Points Lebanon - Complete Ecosystem

A comprehensive loyalty and offers platform connecting consumers, merchants, and administrators in Lebanon.

---

## 🚀 Quick Start

### For Developers

```bash
# Clone/extract the repository
cd urbanpoints-lebanon-complete-ecosystem

# Read documentation
cat docs/01_SYSTEM_OVERVIEW.md

# Set up backend
cd backend/firebase-functions
npm install
npm run build

# Deploy to Firebase
cd ../../scripts
./deploy_production.sh
```

### For Copilot / AI Assistants

See `docs/06_COPILOT_CONTEXT.md` for complete AI-friendly context about this codebase.

---

## 📁 Repository Structure

```
urbanpoints-lebanon-complete-ecosystem/
├── docs/                              # Complete documentation
│   ├── 01_SYSTEM_OVERVIEW.md          # What the system does
│   ├── 02_ARCHITECTURE_BACKEND.md     # Backend architecture
│   ├── 03_ARCHITECTURE_FRONTEND.md    # Frontend architecture
│   ├── 04_DATA_MODELS.md              # Database schema
│   ├── 05_DEPLOYMENT_GUIDE.md         # How to deploy
│   ├── 06_COPILOT_CONTEXT.md          # AI assistant context
│   └── 07_APPS_OVERVIEW.md            # All apps overview
├── backend/                           # Backend services
│   ├── firebase-functions/            # Firebase Cloud Functions (PRIMARY)
│   └── rest-api/                      # Express REST API (legacy)
├── apps/                              # All applications
│   ├── mobile-customer/               # Consumer mobile app
│   ├── mobile-merchant/               # Merchant mobile app
│   ├── mobile-admin/                  # Admin mobile app
│   └── web-admin/                     # Web admin dashboard
├── scripts/                           # Deployment & utility scripts
│   ├── deploy_production.sh           # One-command deployment
│   ├── configure_firebase_env.sh      # Environment setup
│   ├── verify_deployment.sh           # Post-deployment validation
│   └── test_cloud_functions_logic.sh  # Business logic tests
├── infra/                             # Infrastructure configuration
│   ├── firebase.json                  # Firebase project config
│   ├── .firebaserc                    # Firebase project aliases
│   ├── firestore.rules                # Database security rules
│   └── firestore.indexes.json         # Query optimization indexes
├── archive/                           # Older/experimental code
├── .gitignore
├── README.md                          # This file
└── REPORT.md                          # Packaging report
```

---

## 🎯 What's Included

### Backend
- **19 Firebase Cloud Functions**: Authentication, points economy, QR security, offers, subscriptions, push notifications
- **Firestore Security Rules**: 18 collections with role-based access control
- **15 Composite Indexes**: Optimized query performance
- **Payment Gateway Webhooks**: OMT, Whish Money, Stripe integration
- **GDPR Compliance**: Data export and deletion functions

### Mobile Apps
- **Customer App**: Offer discovery, QR redemption, points wallet, subscriptions
- **Merchant App**: Offer management, QR scanning, analytics dashboard
- **Admin App**: Merchant approval, offer moderation, system administration

### Web Dashboard
- **Admin Web App**: Browser-based admin interface for platform management

### Infrastructure
- **Firebase Configuration**: Complete Firebase project setup (urbangenspark)
- **Deployment Scripts**: Automated deployment with validation
- **Environment Configuration**: Auto-generated secrets and configuration

---

## 🔥 Firebase Project

- **Project ID**: urbangenspark
- **Project Number**: 573269413177
- **Region**: us-central1
- **Console**: https://console.firebase.google.com/project/urbangenspark

---

## 📱 Applications

| App | Platform | Purpose | Build Status |
|-----|----------|---------|--------------|
| Customer App | Android/iOS | Consumer offer discovery & redemption | ✅ Production Ready |
| Merchant App | Android/iOS | Merchant offer management & QR validation | ✅ Production Ready |
| Admin App | Android/iOS | Platform administration & moderation | ✅ Production Ready |
| Web Admin | Browser | Admin dashboard (alternative) | ✅ Production Ready |

---

## 🚀 Deployment

### Prerequisites
- Node.js 20+
- Firebase CLI 14.20.0+
- Flutter 3.35.4 (for mobile apps)

### One-Command Deployment

```bash
cd scripts
./deploy_production.sh
```

This deploys:
- Firebase Cloud Functions (19 functions)
- Firestore Security Rules
- Firestore Indexes
- Web Admin Dashboard

**Estimated Time**: 8-12 minutes

For detailed instructions, see `docs/05_DEPLOYMENT_GUIDE.md`

---

## 🏗️ Technology Stack

### Backend
- **Firebase Cloud Functions**: Node.js 20, TypeScript 5.3
- **Firestore**: NoSQL database with real-time sync
- **Firebase Auth**: Email/phone authentication

### Mobile Apps
- **Flutter**: 3.35.4 (Dart 3.9.2)
- **State Management**: Provider
- **Local Storage**: Hive + shared_preferences
- **Push Notifications**: Firebase Cloud Messaging

### Web
- **Admin Dashboard**: Static HTML/CSS/JavaScript
- **Hosting**: Firebase Hosting

---

## 📚 Documentation

All documentation is in the `docs/` directory:

1. **01_SYSTEM_OVERVIEW.md**: High-level system description, user types, main flows
2. **02_ARCHITECTURE_BACKEND.md**: Backend architecture, Cloud Functions, data flow
3. **03_ARCHITECTURE_FRONTEND.md**: Mobile and web frontend architecture
4. **04_DATA_MODELS.md**: Complete database schema (15 collections)
5. **05_DEPLOYMENT_GUIDE.md**: Step-by-step deployment instructions
6. **06_COPILOT_CONTEXT.md**: AI assistant context with examples
7. **07_APPS_OVERVIEW.md**: Detailed app descriptions

---

## 🎓 For AI Assistants (Copilot, ChatGPT, Claude)

This codebase is **AI-friendly** with comprehensive documentation:

- **Quick Navigation**: See `docs/06_COPILOT_CONTEXT.md`
- **Module Organization**: Clear directory structure
- **Extension Examples**: 5 detailed examples of adding new features
- **Common Patterns**: Reusable code templates
- **Testing Guidelines**: Unit and integration test examples

---

## 🔐 Security

- **Firestore Security Rules**: Role-based access control
- **QR Token Security**: HMAC SHA-256 with 60-second expiry
- **Payment Security**: Webhook signature verification
- **GDPR Compliance**: Data export and deletion
- **No Hard-Coded Secrets**: All secrets in Firebase config or environment variables

---

## 🧪 Testing

### Backend Tests
```bash
cd backend/firebase-functions
npm test
```

### Mobile App Tests
```bash
cd apps/mobile-customer
flutter test
```

---

## 📦 What to Do Next

1. **Review Documentation**: Start with `docs/01_SYSTEM_OVERVIEW.md`
2. **Set Up Firebase**: Create Firebase project or use existing `urbangenspark`
3. **Configure Environment**: Run `scripts/configure_firebase_env.sh`
4. **Deploy Backend**: Run `scripts/deploy_production.sh`
5. **Build Mobile Apps**: Use `flutter build apk --release` for each app
6. **Configure Payments**: Set up payment gateway webhooks (see docs)

---

## 🤝 Contributing

This is a complete production-ready ecosystem. To extend or modify:

1. Read `docs/06_COPILOT_CONTEXT.md` for extension examples
2. Follow existing code patterns
3. Update documentation when adding features
4. Run tests before committing
5. Use deployment scripts for consistency

---

## 📄 License

Copyright © 2025 Urban Points Lebanon

---

## 📞 Support

- **Documentation**: See `docs/` directory
- **Firebase Console**: https://console.firebase.google.com/project/urbangenspark
- **Deployment Issues**: See `docs/05_DEPLOYMENT_GUIDE.md` troubleshooting section

---

**Version**: 1.0  
**Last Updated**: November 2025  
**Status**: Production Ready ✅
