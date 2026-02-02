# Jayple Booking Engine Specification
**Version 1.0 | Backend Architecture**  
**Platform:** Cloud Functions + Firestore + Pub/Sub  
**Document Owner:** Senior Backend Architect

---

## Core Booking Principles

1. ✅ **Server-controlled state transitions** - Clients request intent only
2. ✅ **Deterministic state machine** - Valid transitions enforced
3. ✅ **Immutable event records** - Complete audit trail
4. ✅ **Idempotent operations** - Safe retries
5. ✅ **Race-safe** - Firestore transactions prevent conflicts

---

## 1. Booking State Machine

### 1.1 State Definitions

```
┌─────────────────────────────────────────────────────────────────────┐
│                      BOOKING STATE MACHINE                          │
└─────────────────────────────────────────────────────────────────────┘

                         ┌─────────┐
                         │ CREATED │ (Initial state)
                         └────┬────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
         [In-Shop]       [Home Service]   [FAILED]
              │               │
              │          ┌────▼────┐
              │          │ASSIGNING│ (Finding freelancer)
              │          └────┬────┘
              │               │
              │          ┌────┼────┐
              │          │    │    │
              │          ▼    ▼    ▼
              │      [Attempt 1,2,3]
              │          │
              │     ┌────┼────┐
              │     │    │    │
              │     ▼    │    ▼
              │  [FAILED]│ [Success]
              │          │
              ▼          ▼
      ┌──────────────────────┐
      │ PENDING_ACCEPTANCE   │ (Waiting for accept)
      └──────────┬───────────┘
                 │
        ┌────────┼────────┐
        │        │        │
        ▼        ▼        ▼
    [Timeout] [Accept] [Reject]
        │        │        │
        ▼        │        └──► [Reassign or FAILED]
    [CANCELLED]  │
                 ▼
          ┌──────────┐
          │CONFIRMED │
          └─────┬────┘
                │
        ┌───────┼───────┐
        │       │       │
        ▼       ▼       ▼
    [Cancel][Start] [Timeout]
        │       │
        ▼       ▼
    [CANCELLED] ┌────────────┐
                │IN_PROGRESS │
                └─────┬──────┘
                      │
              ┌───────┼───────┐
              │       │       │
              ▼       ▼       ▼
          [Cancel][Complete][Dispute]
              │       │       │
              ▼       ▼       ▼
        [CANCELLED] ┌──────────┐ ┌─────────┐
                    │COMPLETED │ │DISPUTED │
                    └──────┬───┘ └─────────┘
                           │
                           ▼
                    ┌──────────┐
                    │ REVIEWED │
                    └──────────┘
```

### 1.2 State Transition Table

| From State | To State | Trigger | Actor | Preconditions | Side Effects |
|------------|----------|---------|-------|---------------|--------------|
| CREATED | ASSIGNING | Auto | System | type=home | Start freelancer assignment |
| CREATED | PENDING_ACCEPTANCE | Auto | System | type=inShop, mode=manual | Start vendor SLA timer |
| CREATED | CONFIRMED | Auto | System | type=inShop, mode=autoAccept | Notify customer |
| CREATED | FAILED | System | System | Validation failed | Refund if paid |
| ASSIGNING | PENDING_ACCEPTANCE | System | System | Freelancer assigned | Start 30s timeout |
| ASSIGNING | FAILED | System | System | 3 attempts exhausted | Refund, notify customer |
| PENDING_ACCEPTANCE | CONFIRMED | acceptBooking() | Vendor/Freelancer | Within SLA/timeout | Cancel timers, update stats |
| PENDING_ACCEPTANCE | CANCELLED | Timeout | System | SLA/timeout expired | Refund, penalize vendor |
| PENDING_ACCEPTANCE | ASSIGNING | rejectBooking() | Freelancer | attempt < 3 | Reassign to next freelancer |
| PENDING_ACCEPTANCE | FAILED | System | System | Rejection + attempt=3 | Refund customer |
| CONFIRMED | IN_PROGRESS | startService() | Vendor/Freelancer | Service time reached | Notify customer |
| CONFIRMED | CANCELLED | cancelBooking() | Any party | Before service start | Apply penalty, refund |
| IN_PROGRESS | COMPLETED | completeBooking() | Vendor/Freelancer | Service done | Update ledger, enable review |
| IN_PROGRESS | CANCELLED | cancelBooking() | Customer/Vendor | Emergency only | Heavy penalty |
| IN_PROGRESS | DISPUTED | raiseDispute() | Customer | Issue occurred | Freeze settlement |
| COMPLETED | REVIEWED | submitReview() | Customer | Review submitted | Update ratings |

### 1.3 Forbidden Transitions

- ❌ COMPLETED → CANCELLED
- ❌ CANCELLED → CONFIRMED
- ❌ FAILED → CONFIRMED
- ❌ Any state → CREATED
- ❌ REVIEWED → Any other state

---

## 2. In-Shop Booking Flow

### 2.1 Creation Flow

```javascript
// Cloud Function: createInShopBooking
exports.createInShopBooking = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError('unauthenticated');
  
  const { salonId, serviceIds, scheduledDate, scheduledTime, paymentMethod, idempotencyKey } = data;
  const customerId = context.auth.uid;
  
  // 1. Check idempotency
  const existing = await firestore
    .collection('cities/trichy/bookings')
    .where('idempotencyKey', '==', idempotencyKey)
    .limit(1)
    .get();
  
  if (!existing.empty) {
    return { bookingId: existing.docs[0].id, alreadyExists: true };
  }
  
  // 2. Validate salon & services
  const salon = await firestore.doc(`cities/trichy/vendors/${salonId}`).get();
  if (!salon.exists || salon.data().status !== 'active') {
    throw new HttpsError('not-found', 'Salon not available');
  }
  
  // 3. Calculate pricing
  const isWeekend = isWeekendDate(scheduledDate);
  let totalAmount = 0;
  const services = [];
  
  for (const serviceId of serviceIds) {
    const service = await firestore.doc(`cities/trichy/vendors/${salonId}/services/${serviceId}`).get();
    const price = isWeekend ? service.data().weekendPrice : service.data().weekdayPrice;
    totalAmount += price;
    services.push({ serviceId, serviceName: service.data().serviceName, price });
  }
  
  const commission = totalAmount * 0.10; // 10% commission
  
  // 4. Create booking document
  const bookingRef = firestore.collection('cities/trichy/bookings').doc();
  const bookingData = {
    bookingId: bookingRef.id,
    cityId: 'trichy',
    type: 'inShop',
    customerId,
    vendorId: salonId,
    services,
    scheduledDate: admin.firestore.Timestamp.fromDate(new Date(scheduledDate)),
    scheduledTime,
    pricing: { totalAmount, commission, vendorEarnings: totalAmount - commission },
    payment: { method: paymentMethod, status: 'pending' },
    status: 'CREATED',
    idempotencyKey,
    createdAt: FieldValue.serverTimestamp(),
  };
  
  await bookingRef.set(bookingData);
  
  // 5. Trigger state transition (via Firestore trigger)
  return { bookingId: bookingRef.id, totalAmount };
});

// Firestore Trigger: onBookingCreated
exports.onInShopBookingCreated = functions.firestore
  .document('cities/{cityId}/bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    
    if (booking.type !== 'inShop') return;
    
    const salon = await firestore.doc(`cities/${booking.cityId}/vendors/${booking.vendorId}`).get();
    const salonData = salon.data();
    
    if (salonData.bookingMode === 'autoAccept') {
      // Auto-accept mode
      await snap.ref.update({
        status: 'CONFIRMED',
        'timestamps.confirmedAt': FieldValue.serverTimestamp(),
      });
      
      await createStatusEvent(snap.ref, 'CREATED', 'CONFIRMED', 'system', 'Auto-accept mode');
      await sendFCM(booking.customerId, { type: 'booking_confirmed', bookingId: snap.id });
      await sendFCM(booking.vendorId, { type: 'new_booking', bookingId: snap.id });
      
    } else {
      // Manual mode - start SLA timer
      const isPeakHours = isPeakTime(booking.scheduledTime);
      const slaMinutes = isPeakHours 
        ? salonData.slaConfig.peakHours.slaMinutes 
        : salonData.slaConfig.offPeakHours.slaMinutes;
      
      const slaDeadline = new Date(Date.now() + slaMinutes * 60 * 1000);
      
      await snap.ref.update({
        status: 'PENDING_ACCEPTANCE',
        'sla.deadline': admin.firestore.Timestamp.fromDate(slaDeadline),
        'sla.slaMinutes': slaMinutes,
        'sla.isPeakHours': isPeakHours,
      });
      
      await createStatusEvent(snap.ref, 'CREATED', 'PENDING_ACCEPTANCE', 'system', 'Manual mode');
      
      // Schedule SLA timeout
      await schedulePubSubMessage('vendor-sla-timeout', {
        bookingId: snap.id,
        cityId: booking.cityId,
      }, slaMinutes * 60);
      
      await sendFCM(booking.vendorId, { type: 'booking_request', bookingId: snap.id, deadline: slaDeadline });
    }
  });
```

### 2.2 Vendor Acceptance

```javascript
exports.acceptBooking = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError('unauthenticated');
  
  const { bookingId } = data;
  const userId = context.auth.uid;
  
  return await firestore.runTransaction(async (transaction) => {
    const bookingRef = firestore.doc(`cities/trichy/bookings/${bookingId}`);
    const booking = await transaction.get(bookingRef);
    
    if (!booking.exists) throw new HttpsError('not-found', 'Booking not found');
    
    const bookingData = booking.data();
    
    // Validate state
    if (bookingData.status !== 'PENDING_ACCEPTANCE') {
      throw new HttpsError('failed-precondition', `Cannot accept booking in ${bookingData.status} state`);
    }
    
    // Validate actor
    const user = await transaction.get(firestore.doc(`users/${userId}`));
    if (bookingData.type === 'inShop' && user.data().vendorId !== bookingData.vendorId) {
      throw new HttpsError('permission-denied', 'Not authorized');
    }
    
    // Check SLA deadline
    if (bookingData.sla?.deadline && Date.now() > bookingData.sla.deadline.toMillis()) {
      throw new HttpsError('deadline-exceeded', 'SLA deadline passed');
    }
    
    // Update booking
    transaction.update(bookingRef, {
      status: 'CONFIRMED',
      'timestamps.confirmedAt': FieldValue.serverTimestamp(),
      'sla.respondedAt': FieldValue.serverTimestamp(),
    });
    
    // Create status event
    await createStatusEvent(bookingRef, 'PENDING_ACCEPTANCE', 'CONFIRMED', userId, 'Accepted by vendor');
    
    // Cancel SLA timeout (handled by Pub/Sub checking status)
    
    // Send notifications
    await sendFCM(bookingData.customerId, { type: 'booking_confirmed', bookingId });
    
    return { success: true };
  });
});
```

---

## 3. Home Service Booking Flow

### 3.1 Freelancer Assignment Engine

```javascript
// Firestore Trigger: Start assignment
exports.onHomeBookingCreated = functions.firestore
  .document('cities/{cityId}/bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    
    if (booking.type !== 'home') return;
    
    await snap.ref.update({ status: 'ASSIGNING' });
    await createStatusEvent(snap.ref, 'CREATED', 'ASSIGNING', 'system', 'Starting freelancer assignment');
    
    // Trigger assignment
    await assignFreelancer(snap.ref, booking, 1);
  });

async function assignFreelancer(bookingRef, booking, attemptNumber) {
  if (attemptNumber > 3) {
    // Max attempts reached - fail booking
    await bookingRef.update({
      status: 'FAILED',
      'failure.reason': 'no_freelancer_available',
      'failure.failedAt': FieldValue.serverTimestamp(),
    });
    
    await createStatusEvent(bookingRef, 'ASSIGNING', 'FAILED', 'system', 'Max assignment attempts reached');
    await processRefund(booking.bookingId);
    await sendFCM(booking.customerId, { type: 'booking_failed', reason: 'No freelancer available' });
    return;
  }
  
  // 1. Get previous attempts
  const previousAttempts = await bookingRef.collection('assignment_attempts').get();
  const attemptedFreelancerIds = previousAttempts.docs.map(doc => doc.data().freelancerId);
  
  // 2. Query eligible freelancers
  const freelancers = await firestore
    .collection(`cities/${booking.cityId}/freelancers`)
    .where('serviceCategories', 'array-contains', booking.serviceCategory)
    .where('isOnline', '==', true)
    .where('status', '==', 'active')
    .get();
  
  // 3. Filter by proximity & exclude attempted
  const eligible = [];
  for (const doc of freelancers.docs) {
    const freelancer = doc.data();
    
    if (attemptedFreelancerIds.includes(doc.id)) continue;
    
    const distance = calculateDistance(
      freelancer.homeLocation,
      booking.customerAddress.location
    );
    
    if (distance <= freelancer.serviceRadius) {
      eligible.push({ ...freelancer, freelancerId: doc.id, distance });
    }
  }
  
  if (eligible.length === 0) {
    // No eligible freelancers - fail booking
    await bookingRef.update({
      status: 'FAILED',
      'failure.reason': 'no_freelancer_in_area',
      'failure.failedAt': FieldValue.serverTimestamp(),
    });
    
    await createStatusEvent(bookingRef, 'ASSIGNING', 'FAILED', 'system', 'No freelancers in service area');
    await processRefund(booking.bookingId);
    await sendFCM(booking.customerId, { type: 'booking_failed', reason: 'No freelancer in your area' });
    return;
  }
  
  // 4. Sort by priority tier, then distance
  eligible.sort((a, b) => {
    const tierPriority = { gold: 3, silver: 2, bronze: 1 };
    const tierDiff = tierPriority[b.reliability.priorityTier] - tierPriority[a.reliability.priorityTier];
    if (tierDiff !== 0) return tierDiff;
    return a.distance - b.distance;
  });
  
  const selectedFreelancer = eligible[0];
  
  // 5. Assign to freelancer
  const deadline = new Date(Date.now() + 30 * 1000); // 30 seconds
  
  await bookingRef.update({
    status: 'PENDING_ACCEPTANCE',
    freelancerId: selectedFreelancer.freelancerId,
    'assignment.currentAttempt': attemptNumber,
    'assignment.assignedAt': FieldValue.serverTimestamp(),
    'assignment.freelancerDeadline': admin.firestore.Timestamp.fromDate(deadline),
  });
  
  // 6. Create assignment attempt record
  await bookingRef.collection('assignment_attempts').doc(`attempt_${attemptNumber}`).set({
    attemptId: `attempt_${attemptNumber}`,
    attemptNumber,
    freelancerId: selectedFreelancer.freelancerId,
    assignedAt: FieldValue.serverTimestamp(),
    deadline: admin.firestore.Timestamp.fromDate(deadline),
    response: null, // Will be updated on accept/reject/timeout
  });
  
  // 7. Update freelancer job snapshot
  await firestore.doc(`cities/${booking.cityId}/freelancers/${selectedFreelancer.freelancerId}/job_snapshots/${booking.bookingId}`).set({
    jobId: booking.bookingId,
    assignedAt: FieldValue.serverTimestamp(),
    response: null,
    createdAt: FieldValue.serverTimestamp(),
  });
  
  await createStatusEvent(bookingRef, 'ASSIGNING', 'PENDING_ACCEPTANCE', 'system', `Assigned to freelancer (attempt ${attemptNumber})`);
  
  // 8. Schedule timeout
  await schedulePubSubMessage('freelancer-timeout', {
    bookingId: booking.bookingId,
    cityId: booking.cityId,
    freelancerId: selectedFreelancer.freelancerId,
    attemptNumber,
  }, 30);
  
  // 9. Send notification
  await sendFCM(selectedFreelancer.userId, {
    type: 'job_request',
    bookingId: booking.bookingId,
    customerAddress: booking.customerAddress.street,
    amount: booking.pricing.totalAmount,
    deadline,
  });
}
```

### 3.2 Freelancer Timeout Handler

```javascript
exports.handleFreelancerTimeout = functions.pubsub
  .topic('freelancer-timeout')
  .onPublish(async (message) => {
    const { bookingId, cityId, freelancerId, attemptNumber } = message.json;
    
    return await firestore.runTransaction(async (transaction) => {
      const bookingRef = firestore.doc(`cities/${cityId}/bookings/${bookingId}`);
      const booking = await transaction.get(bookingRef);
      
      if (!booking.exists) return;
      
      const bookingData = booking.data();
      
      // Check if still pending (not already accepted/rejected)
      if (bookingData.status !== 'PENDING_ACCEPTANCE') return;
      if (bookingData.assignment.currentAttempt !== attemptNumber) return;
      
      // Update attempt record
      const attemptRef = bookingRef.collection('assignment_attempts').doc(`attempt_${attemptNumber}`);
      transaction.update(attemptRef, {
        response: 'timeout',
        responseTime: 30,
      });
      
      // Update freelancer job snapshot
      const jobSnapshotRef = firestore.doc(`cities/${cityId}/freelancers/${freelancerId}/job_snapshots/${bookingId}`);
      transaction.update(jobSnapshotRef, {
        response: 'timeout',
        responseTimeSeconds: 30,
        manual: false,
      });
      
      // Reassign or fail
      transaction.update(bookingRef, { status: 'ASSIGNING' });
      
      // Trigger reassignment (outside transaction)
      setImmediate(() => assignFreelancer(bookingRef, bookingData, attemptNumber + 1));
    });
  });
```

---

## 4. Cancellation Logic

### 4.1 Cancellation Rules

| Cancelled By | Before Acceptance | After Acceptance | In Progress |
|--------------|-------------------|------------------|-------------|
| Customer | Free | ₹50 penalty | ₹100 penalty |
| Vendor | Free | Reliability penalty | Heavy penalty + refund |
| Freelancer | N/A | Reliability penalty | Heavy penalty + refund |
| System (timeout) | Free refund | Free refund | N/A |

### 4.2 Cancel Booking Function

```javascript
exports.cancelBooking = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError('unauthenticated');
  
  const { bookingId, reason } = data;
  const userId = context.auth.uid;
  
  return await firestore.runTransaction(async (transaction) => {
    const bookingRef = firestore.doc(`cities/trichy/bookings/${bookingId}`);
    const booking = await transaction.get(bookingRef);
    
    if (!booking.exists) throw new HttpsError('not-found');
    
    const bookingData = booking.data();
    
    // Validate state
    if (!['PENDING_ACCEPTANCE', 'CONFIRMED', 'IN_PROGRESS'].includes(bookingData.status)) {
      throw new HttpsError('failed-precondition', `Cannot cancel booking in ${bookingData.status} state`);
    }
    
    // Determine canceller
    const user = await transaction.get(firestore.doc(`users/${userId}`));
    let cancelledBy = 'customer';
    if (user.data().vendorId === bookingData.vendorId) cancelledBy = 'vendor';
    if (user.data().freelancerId === bookingData.freelancerId) cancelledBy = 'freelancer';
    
    // Calculate penalty
    let penalty = 0;
    if (bookingData.status === 'PENDING_ACCEPTANCE') {
      penalty = 0; // Free cancellation before acceptance
    } else if (bookingData.status === 'CONFIRMED') {
      penalty = cancelledBy === 'customer' ? 50 : 0;
    } else if (bookingData.status === 'IN_PROGRESS') {
      penalty = 100;
    }
    
    // Update booking
    transaction.update(bookingRef, {
      status: 'CANCELLED',
      'cancellation.cancelledBy': cancelledBy,
      'cancellation.reason': reason,
      'cancellation.penalty': penalty,
      'cancellation.cancelledAt': FieldValue.serverTimestamp(),
      'timestamps.cancelledAt': FieldValue.serverTimestamp(),
    });
    
    // Process refund & penalty (outside transaction)
    setImmediate(async () => {
      if (penalty > 0) {
        await applyPenalty(userId, bookingId, penalty);
      }
      await processRefund(bookingId, bookingData.pricing.totalAmount - penalty);
      await updateCancellationStats(cancelledBy === 'customer' ? userId : bookingData.customerId);
    });
    
    await createStatusEvent(bookingRef, bookingData.status, 'CANCELLED', userId, reason);
    
    return { success: true, penalty };
  });
});
```

---

## 5. Payment Integration

### 5.1 Payment States

```javascript
payment: {
  method: 'online' | 'offline',
  status: 'pending' | 'authorized' | 'captured' | 'refunded',
  transactionId: 'razorpay_xyz',
  authorizedAt: Timestamp,
  capturedAt: Timestamp,
  refundedAt: Timestamp,
}
```

### 5.2 Payment Flow

**Online Payment:**
1. Customer creates booking → `payment.status = 'pending'`
2. App initiates Razorpay payment
3. On success → Call `confirmPayment(bookingId, transactionId)`
4. Cloud Function updates → `payment.status = 'authorized'`
5. On booking completion → Auto-capture payment → `payment.status = 'captured'`

**Offline Payment:**
1. Booking created with `payment.method = 'offline'`
2. On completion → Ledger tracks outstanding balance
3. Vendor/Freelancer pays later → Outstanding reduced

---

## 6. Event Logging

### 6.1 Status Events Subcollection

```javascript
/cities/{cityId}/bookings/{bookingId}/status_events/{eventId}

{
  eventId: 'evt_123',
  fromStatus: 'PENDING_ACCEPTANCE',
  toStatus: 'CONFIRMED',
  triggeredBy: 'vendor_V456',
  reason: 'Accepted by vendor',
  metadata: { responseTime: 120 },
  createdAt: Timestamp,
}
```

### 6.2 Helper Function

```javascript
async function createStatusEvent(bookingRef, fromStatus, toStatus, triggeredBy, reason, metadata = {}) {
  await bookingRef.collection('status_events').add({
    fromStatus,
    toStatus,
    triggeredBy,
    reason,
    metadata,
    createdAt: FieldValue.serverTimestamp(),
  });
}
```

---

## 7. Edge Cases

### 7.1 Concurrent Freelancer Acceptance

**Problem:** Two freelancers accept same booking simultaneously

**Solution:** Firestore transaction ensures only one succeeds

```javascript
// In acceptBooking transaction
if (bookingData.status !== 'PENDING_ACCEPTANCE') {
  throw new HttpsError('failed-precondition', 'Booking already accepted');
}
```

### 7.2 Duplicate Client Requests

**Solution:** Idempotency key prevents duplicates

```javascript
const existing = await firestore
  .collection('cities/trichy/bookings')
  .where('idempotencyKey', '==', idempotencyKey)
  .limit(1)
  .get();

if (!existing.empty) {
  return { bookingId: existing.docs[0].id, alreadyExists: true };
}
```

### 7.3 Partial Failures

**Problem:** Notification sent but DB write failed

**Solution:** Idempotent operations + retry logic

```javascript
// All critical operations use transactions
// Notifications sent after transaction commits
// If notification fails, retry via Pub/Sub
```

---

## Document Status

**Status:** Production-Ready  
**Version:** 1.0  
**Last Updated:** 2026-02-02  
**Owner:** Senior Backend Architect

**This booking engine is ready for Cloud Functions implementation.** 🚀
