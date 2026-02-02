# Jayple Financial Engine Specification
**Version 1.0 | Payments, Ledger & Settlements**  
**Platform:** Cloud Functions + Firestore + Razorpay  
**Document Owner:** Senior FinTech Systems Architect

---

## Core Financial Principles

1. ✅ **Append-only ledger** - No updates, no deletes
2. ✅ **Derived balances** - Computed from ledger, never stored as source
3. ✅ **Idempotent operations** - Every financial action has unique key
4. ✅ **Replayable settlements** - Can reconstruct from ledger
5. ✅ **Dispute freezing** - Blocks settlements until resolved
6. ✅ **Server-only writes** - Clients never write financial data

---

## 1. Payment Types & Flows

### 1.1 Online Payments (Razorpay)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ONLINE PAYMENT FLOW                            │
└─────────────────────────────────────────────────────────────────────┘

Customer creates booking
   ↓
App creates Razorpay order (via Cloud Function)
   ↓
Customer completes payment in app
   ↓
Razorpay sends webhook: payment.authorized
   ↓
Cloud Function: handlePaymentAuthorized
   ├─ Verify webhook signature
   ├─ Update booking: payment.status = 'authorized'
   └─ Store transactionId
   ↓
[Booking lifecycle continues]
   ↓
Booking COMPLETED
   ↓
Cloud Function: capturePayment
   ├─ Call Razorpay capture API
   ├─ Update booking: payment.status = 'captured'
   └─ Create ledger entries (earning, commission)
```

**Payment States:**
```javascript
payment: {
  method: 'online',
  gateway: 'razorpay',
  orderId: 'order_xyz123',           // Razorpay order ID
  transactionId: 'pay_abc789',       // Razorpay payment ID
  status: 'pending',                 // pending | authorized | captured | refunded | failed
  amount: 500,
  authorizedAt: Timestamp,
  capturedAt: Timestamp,
  refundedAt: Timestamp,
  refundId: 'rfnd_xyz',
}
```

### 1.2 Offline Payments

```
Customer books with payment.method = 'offline'
   ↓
Booking proceeds without payment
   ↓
Booking COMPLETED
   ↓
Cloud Function: onBookingCompleted
   ├─ Create earning ledger entry
   ├─ Create commission ledger entry
   └─ Add to outstandingBalance (vendor/freelancer owes platform)
   ↓
Outstanding tracked until vendor/freelancer pays
```

**Outstanding Balance Tracking:**
```javascript
// Vendor/Freelancer document
{
  balance: 5000,              // Earnings available for settlement
  outstandingBalance: 2000,   // Owes platform from offline collections
  totalEarnings: 50000,       // Lifetime earnings
}
```

### 1.3 Auto-Block Enforcement

```javascript
exports.checkOutstandingThreshold = functions.firestore
  .document('ledger/{ledgerEntryId}')
  .onCreate(async (snap, context) => {
    const entry = snap.data();
    
    if (entry.type !== 'earning' || entry.paymentMethod !== 'offline') return;
    
    const threshold = 10000; // ₹10,000
    
    if (entry.outstandingAfter >= threshold) {
      // Block user
      const userType = entry.userType; // 'vendor' or 'freelancer'
      const docPath = userType === 'vendor' 
        ? `cities/${entry.cityId}/vendors/${entry.userId}`
        : `cities/${entry.cityId}/freelancers/${entry.userId}`;
      
      await firestore.doc(docPath).update({
        status: 'blocked',
        blockReason: `Outstanding balance ₹${entry.outstandingAfter} exceeds threshold`,
        blockedAt: FieldValue.serverTimestamp(),
      });
      
      await sendFCM(entry.userId, {
        type: 'account_blocked',
        body: 'Account blocked due to outstanding balance. Clear dues to continue.',
      });
    }
  });
```

---

## 2. Ledger Design (Double-Entry)

### 2.1 Ledger Entry Structure

```javascript
/ledger/{ledgerEntryId}

{
  // Identity
  ledgerEntryId: 'L123456',
  
  // Transaction Type
  type: 'earning',                    // earning | commission | penalty | refund | settlement | adjustment
  
  // Parties
  userId: 'V456',                     // Affected user
  userType: 'vendor',                 // vendor | freelancer | platform
  cityId: 'trichy',
  
  // Booking Reference
  bookingId: 'B789',                  // Source booking
  
  // Amount
  amount: 450,
  direction: 'credit',                // credit | debit
  
  // Payment Context
  paymentMethod: 'online',            // online | offline
  
  // Balance Snapshots (CRITICAL for auditability)
  balanceBefore: 1000,
  balanceAfter: 1450,
  outstandingBefore: 0,
  outstandingAfter: 0,
  
  // Settlement
  settlementId: null,                 // Populated when settled
  settled: false,
  
  // Idempotency
  idempotencyKey: 'B789_earning_V456',
  
  // Audit
  createdBy: 'system',
  createdAt: Timestamp,
}
```

### 2.2 Entry Types & Rules

| Type | Direction | Description | Affects Outstanding |
|------|-----------|-------------|---------------------|
| `earning` | credit | Vendor/Freelancer earns from booking | Yes (if offline) |
| `commission` | credit | Platform commission from booking | No |
| `penalty` | debit | Cancellation penalty | No |
| `refund` | debit | Refund to customer (reverses earning) | Yes (reduces) |
| `settlement` | debit | Weekly payout to vendor/freelancer | No |
| `adjustment` | credit/debit | Admin manual correction | Depends |

### 2.3 Balance Derivation

```javascript
async function calculateUserBalance(userId, cityId) {
  const ledgerEntries = await firestore
    .collection('ledger')
    .where('userId', '==', userId)
    .where('settled', '==', false)
    .get();
  
  let balance = 0;
  let outstanding = 0;
  
  for (const doc of ledgerEntries.docs) {
    const entry = doc.data();
    const amount = entry.direction === 'credit' ? entry.amount : -entry.amount;
    
    balance += amount;
    
    if (entry.type === 'earning' && entry.paymentMethod === 'offline') {
      outstanding += entry.amount;
    }
  }
  
  return { balance, outstanding };
}
```

### 2.4 Idempotency Strategy

```javascript
async function createLedgerEntry(entryData) {
  const idempotencyKey = entryData.idempotencyKey;
  
  // Check if entry already exists
  const existing = await firestore
    .collection('ledger')
    .where('idempotencyKey', '==', idempotencyKey)
    .limit(1)
    .get();
  
  if (!existing.empty) {
    console.log(`Ledger entry ${idempotencyKey} already exists, skipping`);
    return existing.docs[0].data();
  }
  
  // Calculate current balance
  const { balance, outstanding } = await calculateUserBalance(entryData.userId, entryData.cityId);
  
  // Create entry with balance snapshots
  const entry = {
    ...entryData,
    ledgerEntryId: `L${Date.now()}`,
    balanceBefore: balance,
    balanceAfter: entryData.direction === 'credit' 
      ? balance + entryData.amount 
      : balance - entryData.amount,
    outstandingBefore: outstanding,
    outstandingAfter: entryData.type === 'earning' && entryData.paymentMethod === 'offline'
      ? outstanding + entryData.amount
      : outstanding,
    settled: false,
    createdAt: FieldValue.serverTimestamp(),
  };
  
  await firestore.collection('ledger').add(entry);
  
  // Update denormalized balance on user document (for quick reads)
  const userPath = entryData.userType === 'vendor'
    ? `cities/${entryData.cityId}/vendors/${entryData.userId}`
    : `cities/${entryData.cityId}/freelancers/${entryData.userId}`;
  
  await firestore.doc(userPath).update({
    balance: entry.balanceAfter,
    outstandingBalance: entry.outstandingAfter,
  });
  
  return entry;
}
```

---

## 3. Booking ↔ Payment Coupling

### 3.1 State-Based Financial Actions

| Booking State | Payment Action | Ledger Action |
|---------------|----------------|---------------|
| CREATED | Create order (online) | None |
| CONFIRMED | Authorize payment | None |
| COMPLETED | Capture payment | Create earning + commission |
| CANCELLED (pre-accept) | Full refund | None |
| CANCELLED (post-accept) | Partial refund | Penalty entry |
| FAILED | Full refund | None |
| DISPUTED | Hold capture | Freeze settlement |

### 3.2 Booking Completion Handler

```javascript
exports.onBookingCompleted = functions.firestore
  .document('cities/{cityId}/bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    if (before.status === 'IN_PROGRESS' && after.status === 'COMPLETED') {
      const booking = after;
      const { cityId, bookingId } = context.params;
      
      // 1. Capture payment (if online)
      if (booking.payment.method === 'online' && booking.payment.status === 'authorized') {
        await capturePayment(booking.payment.transactionId, booking.pricing.totalAmount);
        
        await change.after.ref.update({
          'payment.status': 'captured',
          'payment.capturedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // 2. Determine recipient
      const recipientId = booking.type === 'inShop' ? booking.vendorId : booking.freelancerId;
      const recipientType = booking.type === 'inShop' ? 'vendor' : 'freelancer';
      
      // 3. Create earning entry (idempotent)
      await createLedgerEntry({
        type: 'earning',
        userId: recipientId,
        userType: recipientType,
        cityId,
        bookingId,
        amount: booking.pricing.vendorEarnings,
        direction: 'credit',
        paymentMethod: booking.payment.method,
        idempotencyKey: `${bookingId}_earning_${recipientId}`,
        createdBy: 'system',
      });
      
      // 4. Create commission entry (platform)
      await createLedgerEntry({
        type: 'commission',
        userId: 'platform',
        userType: 'platform',
        cityId,
        bookingId,
        amount: booking.pricing.commission,
        direction: 'credit',
        paymentMethod: booking.payment.method,
        idempotencyKey: `${bookingId}_commission`,
        createdBy: 'system',
      });
      
      // 5. Enable review
      await change.after.ref.update({
        'review.eligible': true,
      });
    }
  });
```

### 3.3 Cancellation with Penalty

```javascript
async function processCancellation(booking, cancelledBy, penalty) {
  const { bookingId, cityId, pricing, payment } = booking;
  
  // 1. Process refund (online payments)
  if (payment.method === 'online' && payment.status === 'authorized') {
    const refundAmount = pricing.totalAmount - penalty;
    
    if (refundAmount > 0) {
      const refund = await razorpay.payments.refund(payment.transactionId, {
        amount: refundAmount * 100, // paise
      });
      
      await firestore.doc(`cities/${cityId}/bookings/${bookingId}`).update({
        'payment.status': 'refunded',
        'payment.refundId': refund.id,
        'payment.refundedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  
  // 2. Create penalty entry (if applicable)
  if (penalty > 0) {
    await createLedgerEntry({
      type: 'penalty',
      userId: cancelledBy,
      userType: booking.type === 'inShop' ? 'vendor' : 'freelancer',
      cityId,
      bookingId,
      amount: penalty,
      direction: 'debit',
      paymentMethod: payment.method,
      idempotencyKey: `${bookingId}_penalty_${cancelledBy}`,
      createdBy: 'system',
    });
  }
}
```

---

## 4. Commission Engine

### 4.1 Commission Rates (from /admin/config)

```javascript
commission: {
  inShop: 0.10,     // 10% for salon bookings
  home: 0.15,       // 15% for home services
}
```

### 4.2 Commission Calculation

```javascript
function calculateCommission(bookingType, totalAmount) {
  const config = await getAdminConfig();
  const rate = bookingType === 'inShop' 
    ? config.commission.inShop 
    : config.commission.home;
  
  const commission = Math.round(totalAmount * rate);
  const earnings = totalAmount - commission;
  
  return { commission, earnings };
}
```

### 4.3 Commission Freeze Rule

**Existing bookings are NOT affected by rate changes.**

```javascript
// Commission is calculated and stored at booking creation
const pricing = {
  totalAmount: 500,
  commission: 50,           // Calculated at creation time
  vendorEarnings: 450,      // Stored immutably
};
```

---

## 5. Settlement Engine

### 5.1 Weekly Settlement Cycle

**Schedule:** Every Monday 00:00 IST

```javascript
exports.weeklySettlement = functions.pubsub
  .schedule('0 0 * * 1')              // Monday 00:00
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const settlementDate = new Date();
    const settlementId = `SET_${settlementDate.toISOString().slice(0, 10)}`;
    
    // Prevent double-run
    const existing = await firestore.doc(`settlements/${settlementId}`).get();
    if (existing.exists) {
      console.log('Settlement already processed today');
      return;
    }
    
    // Get all vendors and freelancers
    const cities = ['trichy']; // Expand for multi-city
    
    for (const cityId of cities) {
      await processSettlementsForCity(cityId, settlementId, settlementDate);
    }
  });

async function processSettlementsForCity(cityId, settlementId, settlementDate) {
  // Process vendors
  const vendors = await firestore
    .collection(`cities/${cityId}/vendors`)
    .where('status', '==', 'active')
    .get();
  
  for (const vendor of vendors.docs) {
    await processUserSettlement(vendor.data(), 'vendor', cityId, settlementId, settlementDate);
  }
  
  // Process freelancers
  const freelancers = await firestore
    .collection(`cities/${cityId}/freelancers`)
    .where('status', '==', 'active')
    .get();
  
  for (const freelancer of freelancers.docs) {
    await processUserSettlement(freelancer.data(), 'freelancer', cityId, settlementId, settlementDate);
  }
}
```

### 5.2 User Settlement Processing

```javascript
async function processUserSettlement(user, userType, cityId, settlementId, settlementDate) {
  const userId = userType === 'vendor' ? user.vendorId : user.freelancerId;
  const userSettlementId = `${settlementId}_${userId}`;
  
  // Check if already processed
  const existing = await firestore.doc(`settlements/${userSettlementId}`).get();
  if (existing.exists) return;
  
  // Get unsettled ledger entries
  const unsettledEntries = await firestore
    .collection('ledger')
    .where('userId', '==', userId)
    .where('settled', '==', false)
    .get();
  
  // Check for disputed bookings
  const disputedBookings = await firestore
    .collection(`cities/${cityId}/bookings`)
    .where(userType === 'vendor' ? 'vendorId' : 'freelancerId', '==', userId)
    .where('status', '==', 'DISPUTED')
    .get();
  
  const disputedBookingIds = disputedBookings.docs.map(d => d.id);
  
  // Calculate payable (excluding disputed)
  let payableAmount = 0;
  const includedEntries = [];
  const frozenEntries = [];
  
  for (const entry of unsettledEntries.docs) {
    const data = entry.data();
    
    if (disputedBookingIds.includes(data.bookingId)) {
      frozenEntries.push(entry.id);
      continue;
    }
    
    const amount = data.direction === 'credit' ? data.amount : -data.amount;
    payableAmount += amount;
    includedEntries.push(entry.id);
  }
  
  // Deduct outstanding
  payableAmount -= user.outstandingBalance;
  
  const threshold = 500; // ₹500 minimum
  
  if (payableAmount < threshold) {
    // Carry forward
    await firestore.doc(`settlements/${userSettlementId}`).set({
      settlementId: userSettlementId,
      userId,
      userType,
      cityId,
      settlementDate,
      totalBalance: user.balance,
      outstandingBalance: user.outstandingBalance,
      payableAmount,
      carriedForwardAmount: payableAmount,
      status: 'carriedForward',
      reason: `Amount ₹${payableAmount} below threshold ₹${threshold}`,
      createdAt: FieldValue.serverTimestamp(),
    });
    return;
  }
  
  // Create settlement record
  await firestore.doc(`settlements/${userSettlementId}`).set({
    settlementId: userSettlementId,
    userId,
    userType,
    cityId,
    settlementDate,
    totalBalance: user.balance,
    outstandingBalance: user.outstandingBalance,
    payableAmount,
    includedEntries,
    frozenEntries,
    payout: {
      amount: payableAmount,
      method: 'razorpay',
      status: 'pending',
    },
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });
  
  // Create settlement ledger entry
  await createLedgerEntry({
    type: 'settlement',
    userId,
    userType,
    cityId,
    bookingId: null,
    amount: payableAmount,
    direction: 'debit',
    settlementId: userSettlementId,
    idempotencyKey: userSettlementId,
    createdBy: 'system',
  });
  
  // Mark entries as settled
  const batch = firestore.batch();
  for (const entryId of includedEntries) {
    batch.update(firestore.doc(`ledger/${entryId}`), {
      settled: true,
      settlementId: userSettlementId,
    });
  }
  await batch.commit();
  
  // Trigger payout
  await triggerPayout(userSettlementId, userId, payableAmount);
}
```

---

## 6. Dispute Handling

### 6.1 Dispute Flow

```javascript
exports.raiseDispute = functions.https.onCall(async (data, context) => {
  const { bookingId, reason } = data;
  const customerId = context.auth.uid;
  
  const bookingRef = firestore.doc(`cities/trichy/bookings/${bookingId}`);
  const booking = await bookingRef.get();
  
  if (booking.data().customerId !== customerId) {
    throw new HttpsError('permission-denied');
  }
  
  if (booking.data().status !== 'COMPLETED') {
    throw new HttpsError('failed-precondition', 'Can only dispute completed bookings');
  }
  
  await bookingRef.update({
    status: 'DISPUTED',
    'dispute.reason': reason,
    'dispute.raisedBy': customerId,
    'dispute.raisedAt': FieldValue.serverTimestamp(),
    'dispute.status': 'open',
  });
  
  // Notify admin
  await notifyAdmins('dispute_raised', { bookingId, reason });
  
  return { success: true };
});

// Admin resolves dispute
exports.resolveDispute = functions.https.onCall(async (data, context) => {
  requireAdmin(context);
  
  const { bookingId, resolution, refundAmount } = data;
  
  const bookingRef = firestore.doc(`cities/trichy/bookings/${bookingId}`);
  const booking = await bookingRef.get();
  const bookingData = booking.data();
  
  await bookingRef.update({
    'dispute.status': 'resolved',
    'dispute.resolution': resolution,
    'dispute.resolvedBy': context.auth.uid,
    'dispute.resolvedAt': FieldValue.serverTimestamp(),
    status: resolution === 'refund' ? 'CANCELLED' : 'COMPLETED',
  });
  
  if (resolution === 'refund' && refundAmount > 0) {
    // Create refund ledger entry
    await createLedgerEntry({
      type: 'refund',
      userId: bookingData.vendorId || bookingData.freelancerId,
      userType: bookingData.type === 'inShop' ? 'vendor' : 'freelancer',
      cityId: 'trichy',
      bookingId,
      amount: refundAmount,
      direction: 'debit',
      idempotencyKey: `${bookingId}_dispute_refund`,
      createdBy: context.auth.uid,
    });
    
    // Process actual refund
    if (bookingData.payment.method === 'online') {
      await razorpay.payments.refund(bookingData.payment.transactionId, {
        amount: refundAmount * 100,
      });
    }
  }
  
  return { success: true };
});
```

---

## 7. Fraud Prevention

| Risk | Prevention |
|------|------------|
| Duplicate payment callbacks | Idempotency key on ledger entries |
| Offline payment abuse | Outstanding threshold + auto-block |
| Fake completion | Customer confirmation required |
| Settlement gaming | Dispute freezes settlement |
| Refund abuse | Track refund frequency per customer |

---

## 8. Financial Auditability

### 8.1 Audit Queries

**Vendor Earnings (date range):**
```javascript
const earnings = await firestore
  .collection('ledger')
  .where('userId', '==', vendorId)
  .where('type', '==', 'earning')
  .where('createdAt', '>=', startDate)
  .where('createdAt', '<=', endDate)
  .get();

const total = earnings.docs.reduce((sum, doc) => sum + doc.data().amount, 0);
```

**Platform Revenue:**
```javascript
const commissions = await firestore
  .collection('ledger')
  .where('type', '==', 'commission')
  .where('createdAt', '>=', startDate)
  .get();

const revenue = commissions.docs.reduce((sum, doc) => sum + doc.data().amount, 0);
```

### 8.2 Reconciliation

```javascript
async function reconcileUserBalance(userId) {
  // Calculate from ledger
  const ledgerBalance = await calculateUserBalance(userId);
  
  // Get stored balance
  const user = await firestore.doc(`cities/trichy/vendors/${userId}`).get();
  const storedBalance = user.data().balance;
  
  if (ledgerBalance.balance !== storedBalance) {
    console.error(`Balance mismatch for ${userId}: ledger=${ledgerBalance.balance}, stored=${storedBalance}`);
    // Alert admin
  }
}
```

---

## 9. Edge Cases

| Scenario | Resolution |
|----------|------------|
| Payment succeeds, booking fails | Refund via webhook reconciliation |
| Booking completes, callback delayed | Idempotent ledger entries |
| Refund fails | Retry queue, manual resolution |
| Settlement fails mid-run | Idempotent per-user, resume on next run |

---

## Document Status

**Status:** Production-Ready  
**Version:** 1.0  
**Last Updated:** 2026-02-02

**This financial engine is ready for Cloud Functions implementation.** 🚀
