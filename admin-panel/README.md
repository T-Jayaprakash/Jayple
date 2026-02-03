# Jayple Admin Panel

Internal Admin Control for Jayple Platform.

## Stack
- Vite + React
- Material UI
- Firebase Auth + Cloud Functions (HTTPS API)

## Setup

1. **Install Dependencies:**
   ```bash
   cd admin-panel
   npm install
   ```

2. **Run Locally:**
   ```bash
   npm run dev
   ```

## Authentication

- **Admin Logic:** Uses `AdminGuard` component.
- **Access:** Only users with Custom Claim `admin = true` can access the dashboard.
- **Login:** /login

## Features

- **Dashboard:** Platform Stats (Users, Bookings, etc.)
- **Users:** List, Block/Unblock
- **Bookings:** Search, Filter, Force Cancel
- **Settlements:** View, Mark Paid
- **Disputes:** Resolve Refunds/Payouts

## Security Rules

- NO direct Firestore SDK queries (`getDoc`, `collection`).
- ALL data fetched via `httpsCallable` functions.
- `AuthContext` verifies `idTokenResult.claims.admin` on load.
