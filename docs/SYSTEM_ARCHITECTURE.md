# Jayple System Architecture Document
**Version 1.0 | Engineering Specification**  
**Target:** Production-Ready, Scalable Backend Architecture  
**Tech Stack:** Flutter + Firebase + Cloud Functions + Firestore + Cloudinary + Razorpay  
**Document Owner:** Senior System Architect & Backend Lead

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                                 │
├─────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │   Flutter    │    │   Flutter    │    │  Admin Web   │          │
│  │   Customer   │    │ Vendor/Free  │    │  Dashboard   │          │
│  │     App      │    │     App      │    │ (React/Next) │          │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘          │
│         │                   │                    │                   │
│         └───────────────────┴────────────────────┘                   │
│                             │                                         │
└─────────────────────────────┼─────────────────────────────────────────┘
                              │ HTTPS / WebSocket
┌─────────────────────────────┼─────────────────────────────────────────┐
│                    FIREBASE LAYER                                     │
├─────────────────────────────┼─────────────────────────────────────────┤
│  ┌──────────────────────────▼──────────────────────────┐             │
│  │        Firebase Authentication (Phone OTP)          │             │
│  └──────────────────────────┬──────────────────────────┘             │
│  ┌──────────────────────────▼──────────────────────────┐             │
│  │              Firestore (Source of Truth)            │             │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐       │             │
│  │  │ Users  │ │Bookings│ │ Ledger │ │Reviews │       │             │
│  │  │ Salons │ │Freelan │ │Settlem │ │ Events │       │             │
│  │  │Services│ │  cers  │ │  ents  │ │ Config │       │             │
│  │  └────────┘ └────────┘ └────────┘ └────────┘       │             │
│  └──────────────────────────┬──────────────────────────┘             │
│  ┌──────────────────────────▼──────────────────────────┐             │
│  │         Cloud Functions (Business Logic)            │             │
│  │  ┌─────────────────┐  ┌─────────────────┐          │             │
│  │  │ Request-Driven  │  │  Event-Driven   │          │             │
│  │  │ createBooking   │  │ onBookingCreate │          │             │
│  │  │ acceptBooking   │  │ onBookingUpdate │          │             │
│  │  │ cancelBooking   │  │ onFreelancerAcc │          │             │
│  │  └─────────────────┘  └─────────────────┘          │             │
│  └──────────────────────────┬──────────────────────────┘             │
│  ┌──────────────────────────▼──────────────────────────┐             │
│  │    Firebase Cloud Messaging (FCM)                   │             │
│  └─────────────────────────────────────────────────────┘             │
└───────────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────┼─────────────────────────────────────────┐
│                    EXTERNAL SERVICES                                  │
│  ┌──────────────┐  ┌───────▼──────┐  ┌──────────────┐               │
│  │  Cloudinary  │  │  Razorpay/   │  │ Google Maps  │               │
│  │    (Media)   │  │   Stripe     │  │     API      │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
└───────────────────────────────────────────────────────────────────────┘
```

**Architecture Flow Types:**

**Request-Driven (Synchronous):** Client → Cloud Function → Firestore → Response  
**Event-Driven (Asynchronous):** Firestore Write → Trigger → Cloud Function → Side Effects

---

## 2. Responsibility Separation

### 2.1 Flutter App (Thin Client)

**✅ Allowed:**
- UI rendering and state management
- User input collection and validation (client-side only)
- Intent dispatch (call Cloud Functions)
- Real-time data subscription (Firestore streams)
- Display derived/computed data
- Local caching for offline-first UX
- FCM notification handling

**❌ Prohibited:**
- Business logic execution
- Direct Firestore writes for critical operations
- Price calculations
- Reliability score computation
- Assignment algorithms
- Financial calculations

---

### 2.2 Cloud Functions (Business Logic Layer)

**Request-Driven Functions (HTTPS Callable):**

| Function | Responsibility |
|----------|----------------|
| `createBooking` | Validate booking request, create booking document, trigger assignment |
| `acceptBooking` | Validate acceptance, update booking state, cancel SLA timer |
| `rejectBooking` | Validate rejection, update freelancer stats, trigger reassignment |
| `cancelBooking` | Validate cancellation, apply penalties, update ledger |
| `completeBooking` | Mark booking complete, trigger settlement calculation |
| `submitReview` | Validate review, update target rating, recalculate reliability |
| `processPayment` | Initiate Razorpay/Stripe payment, update booking payment status |

**Event-Driven Functions (Firestore Triggers):**

| Function | Trigger | Responsibility |
|----------|---------|----------------|
| `onBookingCreated` | `bookings/{id}` onCreate | Assign freelancer or notify vendor, start SLA timer |
| `onBookingAccepted` | `bookings/{id}` onUpdate | Cancel timers, send notifications, update stats |
| `onBookingCompleted` | `bookings/{id}` onUpdate | Calculate earnings, update ledger, enable review |
| `onFreelancerTimeout` | Scheduled (Pub/Sub) | Reassign booking to next freelancer |
| `onVendorSLATimeout` | Scheduled (Pub/Sub) | Auto-reject booking, penalize vendor |
| `onReliabilityUpdate` | `freelancers/{id}` onUpdate | Recalculate priority tier |
| `onSettlementCycle` | Scheduled (weekly) | Calculate settlements, apply carry-forward logic |

---

## 3. Event-Driven Architecture

### Core Events

#### 1. `booking_created`
```
Client calls createBooking()
  ↓
Cloud Function validates & creates booking document
  ↓
Firestore Trigger: onBookingCreated
  ├─ IF home service: Assign freelancer, start 30s timeout
  └─ IF in-shop:
      ├─ Auto-accept mode: Confirm immediately
      └─ Manual mode: Notify vendor, start SLA timer
```

#### 2. `freelancer_assigned`
```
onBookingCreated assigns freelancer
  ↓
Update booking: { freelancerId, assignedAt, deadline }
  ↓
Schedule Pub/Sub timeout (30 seconds)
  ↓
Send FCM to freelancer (high priority)
```

#### 3. `freelancer_accepted`
```
Client calls acceptBooking()
  ↓
Validate & update booking: { status: 'confirmed' }
  ↓
Cancel timeout, update freelancer stats
  ↓
Send FCM to customer & freelancer
```

#### 4. `freelancer_timeout`
```
Pub/Sub fires after 30s
  ↓
IF booking still pending:
  ├─ Update freelancer stats (timeout rejection)
  ├─ IF attempts < 3: Reassign to next freelancer
  └─ ELSE: Mark booking as failed, refund customer
```

#### 5. `booking_completed`
```
Vendor/Freelancer calls completeBooking()
  ↓
Update booking: { status: 'completed' }
  ↓
Update ledger: Credit earnings, deduct commission
  ↓
Enable review, send FCM to customer
```

#### 6. `settlement_cycle_started`
```
Cloud Scheduler triggers (Monday 00:00 IST)
  ↓
FOR EACH vendor/freelancer:
  ├─ Calculate payable = earnings - commission - outstanding
  ├─ IF payable >= ₹500: Process payout
  └─ ELSE: Carry forward to next week
```

---

## 4. Booking Engine Architecture

### State Machine

```
PENDING → CONFIRMED → IN_PROGRESS → COMPLETED → REVIEWED
   ↓           ↓            ↓
CANCELLED  CANCELLED    DISPUTED
```

### State Transition Rules

| From | To | Trigger | Side Effects |
|------|----|---------|--------------| 
| PENDING | CONFIRMED | Accept | Cancel timers, notify customer |
| PENDING | CANCELLED | Timeout/Cancel | Refund, penalize |
| PENDING | FAILED | 3 rejections | Refund customer |
| CONFIRMED | IN_PROGRESS | Service starts | Notify customer |
| CONFIRMED | CANCELLED | User cancels | Apply penalty |
| IN_PROGRESS | COMPLETED | Service done | Update ledger |
| COMPLETED | REVIEWED | Review submitted | Update ratings |

### Freelancer Assignment Algorithm

```javascript
function assignFreelancer(bookingId, customerLocation, serviceCategory) {
  // 1. Query eligible freelancers
  const freelancers = firestore
    .collection('freelancers')
    .where('serviceCategories', 'array-contains', serviceCategory)
    .where('isOnline', '==', true)
    .where('status', '==', 'active')
    .get();

  // 2. Filter by proximity
  const nearby = freelancers.filter(f => 
    calculateDistance(f.location, customerLocation) <= f.serviceRadius
  );

  // 3. Exclude already attempted
  const attempted = booking.freelancerAssignmentAttempts.map(a => a.freelancerId);
  const eligible = nearby.filter(f => !attempted.includes(f.id));

  // 4. Sort by priority tier, then distance
  const sorted = eligible.sort((a, b) => {
    const tierPriority = { gold: 3, silver: 2, bronze: 1 };
    if (tierPriority[a.priorityTier] !== tierPriority[b.priorityTier]) {
      return tierPriority[b.priorityTier] - tierPriority[a.priorityTier];
    }
    return calculateDistance(a.location, customerLocation) - 
           calculateDistance(b.location, customerLocation);
  });

  return sorted[0];
}
```

---

## 5. Reliability & Scoring Engine

### Data Storage

```javascript
// Freelancer Document
{
  freelancerId: 'FL123',
  
  // Rolling window (last 10 jobs)
  recentJobs: [
    {
      jobId: 'B789',
      assignedAt: timestamp,
      response: 'accepted' | 'rejected' | 'timeout',
      responseTime: 15, // seconds
      manual: true, // manual rejection vs timeout
    }
  ],
  
  // Computed metrics
  acceptanceRate: 0.85,
  manualRejectionCount: 1,
  timeoutRejectionCount: 1,
  averageResponseTime: 12.5,
  
  // Availability
  weeklyAvailabilityTarget: 20,
  weeklyAvailabilityActual: 18,
  availabilityConsistencyScore: 0.90,
  
  // Overall
  reliabilityScore: 87.5,
  priorityTier: 'gold' | 'silver' | 'bronze',
}
```

### Recalculation Logic

```javascript
async function recalculateFreelancerReliability(freelancerId) {
  const freelancer = await firestore.doc(`freelancers/${freelancerId}`).get();
  const data = freelancer.data();
  
  // 1. Acceptance Rate (last 10 jobs)
  const recentJobs = data.recentJobs.slice(-10);
  const accepted = recentJobs.filter(j => j.response === 'accepted').length;
  const acceptanceRate = accepted / recentJobs.length;
  
  // 2. Rejections
  const manualRejections = recentJobs.filter(j => j.response === 'rejected' && j.manual).length;
  const timeoutRejections = recentJobs.filter(j => j.response === 'timeout').length;
  
  // 3. Availability Consistency
  const availabilityConsistency = data.weeklyAvailabilityActual / data.weeklyAvailabilityTarget;
  
  // 4. Weighted Reliability Score
  const reliabilityScore = (
    acceptanceRate * 40 +
    (1 - data.cancellationRate) * 20 +
    (data.averageRating / 5) * 20 +
    (1 - timeoutRejections / 10) * 10 +
    availabilityConsistency * 10
  );
  
  // 5. Determine Priority Tier
  let priorityTier = 'bronze';
  if (acceptanceRate > 0.90 && data.averageRating > 4.5 && availabilityConsistency > 0.80) {
    priorityTier = 'gold';
  } else if (acceptanceRate > 0.75 && data.averageRating > 4.0 && availabilityConsistency > 0.60) {
    priorityTier = 'silver';
  }
  
  // 6. Update Firestore
  await firestore.doc(`freelancers/${freelancerId}`).update({
    acceptanceRate,
    manualRejectionCount: manualRejections,
    timeoutRejectionCount: timeoutRejections,
    availabilityConsistencyScore: availabilityConsistency,
    reliabilityScore,
    priorityTier,
  });
}
```

**Trigger Points:**
- After every job response (accept/reject/timeout)
- After booking completion
- After review submission
- Scheduled batch (every 6 hours)

---

## 6. Financial & Ledger Architecture

### Double-Entry Ledger Design

```javascript
// Ledger Document
{
  ledgerId: 'L123',
  userId: 'U456',
  userType: 'vendor' | 'freelancer',
  bookingId: 'B789',
  
  type: 'earning' | 'commission' | 'penalty' | 'settlement' | 'refund',
  amount: 500,
  direction: 'credit' | 'debit',
  
  description: 'Booking earnings',
  paymentMethod: 'online' | 'offline',
  
  balanceBefore: 1000,
  balanceAfter: 1500,
  outstandingBefore: 200,
  outstandingAfter: 200,
  
  createdAt: timestamp,
  idempotencyKey: 'B789_earning', // Prevent duplicates
}
```

### On Booking Completion

```javascript
async function onBookingCompleted(bookingId) {
  await firestore.runTransaction(async (transaction) => {
    const booking = await transaction.get(firestore.doc(`bookings/${bookingId}`));
    const userId = booking.data().vendorId || booking.data().freelancerId;
    
    const totalAmount = booking.data().totalAmount;
    const commission = booking.data().commission;
    const earnings = totalAmount - commission;
    
    // Create earning ledger entry (idempotent)
    const earningLedgerId = `${bookingId}_earning`;
    transaction.set(firestore.doc(`ledger/${earningLedgerId}`), {
      ledgerId: earningLedgerId,
      userId,
      bookingId,
      type: 'earning',
      amount: earnings,
      direction: 'credit',
      paymentMethod: booking.data().paymentMethod,
      idempotencyKey: earningLedgerId,
      createdAt: FieldValue.serverTimestamp(),
    });
    
    // Update user balance
    transaction.update(firestore.doc(`vendors/${userId}`), {
      balance: FieldValue.increment(earnings),
      outstandingBalance: booking.data().paymentMethod === 'offline'
        ? FieldValue.increment(totalAmount)
        : FieldValue.increment(0),
    });
  });
}
```

### Weekly Settlement

```javascript
async function runWeeklySettlement() {
  const settlementThreshold = 500;
  const users = await firestore.collection('vendors').where('status', '==', 'active').get();
  
  for (const userDoc of users.docs) {
    const balance = userDoc.data().balance || 0;
    const outstanding = userDoc.data().outstandingBalance || 0;
    const payableAmount = balance - outstanding;
    
    const settlementId = `${userDoc.id}_${new Date().toISOString().split('T')[0]}`;
    
    if (payableAmount >= settlementThreshold) {
      // Process payout
      await firestore.doc(`settlements/${settlementId}`).set({
        userId: userDoc.id,
        payableAmount,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
      });
      
      await triggerPayout(userDoc.id, payableAmount);
      
    } else {
      // Carry forward
      await firestore.doc(`settlements/${settlementId}`).set({
        userId: userDoc.id,
        carriedForwardAmount: payableAmount,
        status: 'carriedForward',
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }
}
```

### Auto-Block on Outstanding Threshold

```javascript
async function checkOutstandingThreshold(userId, outstandingBalance) {
  const threshold = 10000;
  
  if (outstandingBalance >= threshold) {
    await firestore.doc(`vendors/${userId}`).update({
      status: 'blocked',
      blockReason: 'outstanding_threshold_exceeded',
      blockedAt: FieldValue.serverTimestamp(),
    });
    
    await sendFCM(userId, {
      type: 'account_blocked',
      reason: 'Outstanding balance exceeded ₹10,000',
    });
  }
}
```

---

## 7. Notification Architecture (FCM)

### Notification Types

| Event | Recipient | Priority | Payload |
|-------|-----------|----------|---------|
| Job Request | Freelancer | High | `{ type: 'job_request', bookingId, amount }` |
| Booking Request | Vendor | High | `{ type: 'booking_request', bookingId }` |
| Booking Confirmed | Customer | Normal | `{ type: 'booking_confirmed', bookingId }` |
| Service Completed | Customer | Normal | `{ type: 'service_completed', bookingId }` |
| Settlement Processed | Vendor/Freelancer | Normal | `{ type: 'settlement_processed', amount }` |
| Account Blocked | Vendor/Freelancer | Critical | `{ type: 'account_blocked', reason }` |

### Implementation

```javascript
async function sendNotification(userId, payload) {
  const userDoc = await firestore.doc(`users/${userId}`).get();
  const fcmTokens = userDoc.data().fcmTokens || [];
  
  const message = {
    data: payload,
    notification: {
      title: getNotificationTitle(payload.type),
      body: getNotificationBody(payload),
    },
    android: {
      priority: payload.priority || 'normal',
      notification: {
        sound: 'default',
        channelId: payload.type.includes('job') ? 'job_requests' : 'general',
      },
    },
  };
  
  await Promise.all(
    fcmTokens.map(token => admin.messaging().send({ ...message, token }))
  );
}
```

---

## 8. Failure & Edge-Case Handling

### 8.1 Network Failures (Idempotency)

```javascript
// Client generates idempotency key
const idempotencyKey = `${userId}_${Date.now()}`;
await createBooking({ ...params, idempotencyKey });

// Server checks for duplicates
const existing = await firestore
  .collection('bookings')
  .where('idempotencyKey', '==', idempotencyKey)
  .limit(1)
  .get();

if (!existing.empty) {
  return { bookingId: existing.docs[0].id, alreadyExists: true };
}
```

### 8.2 Freelancer App Killed

**Multi-layer notification:**
1. FCM high-priority (wakes app)
2. SMS fallback (after 10s if no response)
3. 30s timeout (reassign)

### 8.3 Double Settlement Prevention

```javascript
const settlementId = `global_${new Date().toISOString().split('T')[0]}`;
const existing = await firestore.doc(`settlement_runs/${settlementId}`).get();

if (existing.exists) {
  console.log('Settlement already ran today');
  return;
}

await firestore.doc(`settlement_runs/${settlementId}`).set({
  status: 'running',
  startedAt: FieldValue.serverTimestamp(),
});
```

### 8.4 Self-Healing: Orphaned Bookings

```javascript
// Scheduled: Every hour
async function cleanupOrphanedBookings() {
  const threshold = Date.now() - (24 * 60 * 60 * 1000);
  
  const orphaned = await firestore
    .collection('bookings')
    .where('status', '==', 'pending')
    .where('createdAt', '<', new Date(threshold))
    .get();
  
  for (const booking of orphaned.docs) {
    await firestore.doc(`bookings/${booking.id}`).update({
      status: 'failed',
      failureReason: 'orphaned_cleanup',
    });
    await processRefund(booking.id);
  }
}
```

---

## 9. Scalability Plan (Trichy → Metro)

### 9.1 Multi-City Expansion

**Geo-Sharding Strategy:**
```javascript
// Collection structure
/cities/{cityId}/vendors/{vendorId}
/cities/{cityId}/freelancers/{freelancerId}
/cities/{cityId}/bookings/{bookingId}

// Query within city
const vendors = await firestore
  .collection(`cities/${cityId}/vendors`)
  .where('isActive', '==', true)
  .get();
```

### 9.2 Firestore Cost Control

**Indexing Strategy:**
- Composite indexes for frequent queries
- Avoid unindexed queries at scale
- Use collection group queries sparingly

**Read Optimization:**
- Cache frequently accessed data (service categories, pricing)
- Use Firestore offline persistence in Flutter
- Denormalize data to reduce joins

### 9.3 Cloud Function Cold-Start Mitigation

**Strategies:**
- Use minimum instances for critical functions
- Keep functions warm with scheduled pings
- Optimize function size (tree-shaking)
- Use Cloud Run for long-running tasks

```javascript
// firebase.json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs18",
    "minInstances": {
      "createBooking": 1,
      "acceptBooking": 1
    }
  }
}
```

---

## 10. Security Rules

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Bookings: Customers can create, all parties can read
    match /bookings/{bookingId} {
      allow create: if request.auth != null;
      allow read: if request.auth.uid == resource.data.customerId
                  || request.auth.uid == resource.data.vendorId
                  || request.auth.uid == resource.data.freelancerId;
      allow update: if false; // Only Cloud Functions can update
    }
    
    // Ledger: Read-only for users, write-only for Cloud Functions
    match /ledger/{ledgerId} {
      allow read: if request.auth.uid == resource.data.userId;
      allow write: if false; // Only Cloud Functions
    }
  }
}
```

---

## 11. Monitoring & Observability

### Key Metrics to Track

**Operational:**
- Booking success rate
- Average time to assignment
- Freelancer acceptance rate
- Vendor SLA compliance rate
- Cancellation rate by role

**Financial:**
- GMV (Gross Merchandise Value)
- Commission earned
- Settlement completion rate
- Outstanding balances

**Technical:**
- Cloud Function execution time
- Firestore read/write counts
- FCM delivery rate
- Error rates by function

### Logging Strategy

```javascript
// Structured logging in Cloud Functions
const { logger } = require('firebase-functions');

logger.info('Booking created', {
  bookingId,
  customerId,
  type,
  amount,
  timestamp: new Date().toISOString(),
});
```

---

## 12. Deployment Strategy

### Environment Setup

```
environments/
├── dev/
│   ├── .env
│   └── firebase.json
├── staging/
│   ├── .env
│   └── firebase.json
└── production/
    ├── .env
    └── firebase.json
```

### CI/CD Pipeline

1. **Development:** Auto-deploy on push to `dev` branch
2. **Staging:** Manual deploy, full testing
3. **Production:** Manual deploy with approval

### Rollback Strategy

- Keep previous 3 Cloud Function versions
- Firestore backups (daily)
- Ability to revert to previous version within 5 minutes

---

**Document Status:** Ready for Engineering Handoff  
**Next Steps:** 
1. Set up Firebase project
2. Implement core Cloud Functions
3. Design Firestore indexes
4. Build Flutter thin client
5. Test end-to-end flows

**Owner:** Backend Lead  
**Last Updated:** 2026-02-01
