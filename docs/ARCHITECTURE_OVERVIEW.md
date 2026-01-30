# Architecture Overview (Evidence-Only)

Anchors:
- Mobile Customer: source/apps/mobile-customer
- Mobile Merchant: source/apps/mobile-merchant
- Web Admin: source/apps/web-admin
- Firebase Functions: source/backend/firebase-functions
- REST API: source/backend/rest-api

```mermaid
flowchart LR
  subgraph Mobile[Flutter Mobile Apps]
    C[Customer App]:::app
    M[Merchant App]:::app
  end

  subgraph Backend
    FCF[Firebase Cloud Functions]:::svc
    DB[(PostgreSQL)]:::db
    API[REST API (Express)]:::svc
  end

  subgraph Admin[Web Admin (Next.js)]
    WA[Web Admin UI]:::app
  end

  C -- Auth/Firestore/Functions --> FCF
  M -- Auth/Firestore/Functions --> FCF
  WA -- Admin Ops/Playwright E2E --> FCF
  FCF -- Stripe/3rd-party --> Ext[External Services]
  C -- Network/HTTP --> API
  M -- Network/HTTP --> API
  API -- Queries --> DB

  classDef app fill:#9cf,stroke:#036,stroke-width:1px;
  classDef svc fill:#fc9,stroke:#630,stroke-width:1px;
  classDef db fill:#cfc,stroke:#060,stroke-width:1px;
```

Evidence notes:
- Firebase emulator proof currently BLOCKED (firebase.json missing).
- Playwright configured but BLOCKED due to environment prerequisites.
- Integration tests present for mobile apps but BLOCKED without devices/emulators.
- No real E2E journey packs found under local-ci/verification/e2e_journeys.
