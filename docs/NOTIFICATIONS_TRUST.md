# Jayple Notification & Trust Layer Specification
**Version 1.0 | Reliability Engineering**  
**Platform:** FCM + SMS + Firestore  
**Document Owner:** Senior Distributed Systems Engineer

---

## Core Trust Principles

1. ✅ **Notifications are best-effort** - Never guaranteed
2. ✅ **Backend never depends on delivery** - State machine is truth
3. ✅ **Multi-layer delivery** - FCM → Retry → SMS → In-app inbox
4. ✅ **Users can reconstruct truth** - Firestore is source of truth
5. ✅ **Observable failures** - Metrics and alerts

---

## 1. Notification Channels

### 1.1 Channel Matrix

| Channel | Use Case | Cost | Latency | Reliability |
|---------|----------|------|---------|-------------|
| FCM Push | Primary delivery | Free | ~1s | 95%+ |
| FCM Data | Background sync | Free | ~1s | 95%+ |
| SMS | Critical fallback | ₹0.25/msg | ~5s | 99%+ |
| In-App Inbox | Source of truth | Storage only | Real-time | 100% |

### 1.2 Priority Levels

| Priority | FCM Config | SMS Fallback | Retry Attempts |
|----------|------------|--------------|----------------|
| CRITICAL | high priority, TTL 0 | Yes, after 30s | 5 |
| HIGH | high priority, TTL 5min | No | 3 |
| NORMAL | normal priority, TTL 1hr | No | 2 |
| SILENT | data-only, TTL 4hr | No | 1 |

---

## 2. Notification Events

### 2.1 Booking Lifecycle

| Event | Recipients | Priority | Channels | SMS Fallback |
|-------|-----------|----------|----------|--------------|
| Booking Created | Customer | NORMAL | FCM + Inbox | No |
| Freelancer Assigned | Freelancer | CRITICAL | FCM + Inbox | Yes (30s) |
| Freelancer Accepted | Customer | HIGH | FCM + Inbox | No |
| Freelancer Rejected | Customer | NORMAL | Inbox only | No |
| Vendor Request | Vendor | CRITICAL | FCM + Inbox | Yes (if SLA < 5min) |
| SLA Warning (2min left) | Vendor | HIGH | FCM + Inbox | No |
| Booking Confirmed | Customer, Provider | HIGH | FCM + Inbox | No |
| Booking Cancelled | All parties | HIGH | FCM + Inbox | No |
| Booking Failed | Customer | HIGH | FCM + Inbox | No |
| Booking Completed | Customer | NORMAL | FCM + Inbox | No |

### 2.2 Financial Events

| Event | Recipients | Priority | Channels | SMS Fallback |
|-------|-----------|----------|----------|--------------|
| Payment Authorized | Customer | NORMAL | Inbox only | No |
| Payment Captured | Customer, Provider | NORMAL | FCM + Inbox | No |
| Refund Initiated | Customer | HIGH | FCM + Inbox | No |
| Settlement Processed | Provider | HIGH | FCM + Inbox | Yes |
| Outstanding Warning (80%) | Provider | HIGH | FCM + Inbox + SMS | Yes |
| Account Blocked | Provider | CRITICAL | FCM + Inbox + SMS | Yes |

### 2.3 Admin/Trust Events

| Event | Recipients | Priority | Channels | SMS Fallback |
|-------|-----------|----------|----------|--------------|
| Application Approved | Applicant | HIGH | FCM + Inbox + SMS | Yes |
| Application Rejected | Applicant | HIGH | FCM + Inbox | No |
| Account Suspended | User | CRITICAL | FCM + Inbox + SMS | Yes |
| Account Unblocked | User | HIGH | FCM + Inbox | No |
| Dispute Opened | Provider, Admin | HIGH | FCM + Inbox | No |
| Dispute Resolved | Customer, Provider | HIGH | FCM + Inbox | No |

---

## 3. Notification Infrastructure

### 3.1 Core Notification Function

```javascript
const PRIORITY_CONFIG = {
  CRITICAL: { fcmPriority: 'high', ttl: 0, maxRetries: 5, smsFallback: true, smsDelay: 30 },
  HIGH: { fcmPriority: 'high', ttl: 300, maxRetries: 3, smsFallback: false },
  NORMAL: { fcmPriority: 'normal', ttl: 3600, maxRetries: 2, smsFallback: false },
  SILENT: { fcmPriority: 'normal', ttl: 14400, maxRetries: 1, smsFallback: false },
};

async function sendNotification(userId, event) {
  const { type, title, body, data, priority = 'NORMAL' } = event;
  const config = PRIORITY_CONFIG[priority];
  const notificationId = `N${Date.now()}_${userId}_${type}`;
  
  // 1. Create in-app inbox entry (source of truth)
  await createInboxEntry(userId, notificationId, event);
  
  // 2. Get user's FCM tokens
  const user = await firestore.doc(`users/${userId}`).get();
  const fcmTokens = user.data().fcmTokens || [];
  
  if (fcmTokens.length === 0) {
    await logDeliveryAttempt(notificationId, 'fcm', 'skipped', 'no_tokens');
    if (config.smsFallback) {
      await scheduleSMSFallback(userId, event, 0);
    }
    return;
  }
  
  // 3. Send FCM to all devices
  const message = {
    tokens: fcmTokens,
    notification: priority !== 'SILENT' ? { title, body } : undefined,
    data: { ...data, notificationId, type },
    android: { priority: config.fcmPriority, ttl: config.ttl * 1000 },
    apns: { headers: { 'apns-priority': config.fcmPriority === 'high' ? '10' : '5' } },
  };
  
  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    
    // 4. Handle token cleanup and retry
    const failedTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        if (resp.error?.code === 'messaging/registration-token-not-registered') {
          failedTokens.push(fcmTokens[idx]);
        }
      }
    });
    
    // Remove invalid tokens
    if (failedTokens.length > 0) {
      await firestore.doc(`users/${userId}`).update({
        fcmTokens: FieldValue.arrayRemove(...failedTokens),
      });
    }
    
    const successCount = response.successCount;
    const status = successCount > 0 ? 'delivered' : 'failed';
    
    await logDeliveryAttempt(notificationId, 'fcm', status, { successCount, failedTokens });
    
    // 5. Schedule SMS fallback for critical notifications
    if (status === 'failed' && config.smsFallback) {
      await scheduleSMSFallback(userId, event, config.smsDelay);
    }
    
  } catch (error) {
    await logDeliveryAttempt(notificationId, 'fcm', 'error', error.message);
    
    // Schedule retry
    await scheduleRetry(userId, event, 1, config.maxRetries);
  }
}
```

### 3.2 Retry Strategy

```javascript
async function scheduleRetry(userId, event, attempt, maxAttempts) {
  if (attempt >= maxAttempts) {
    await logDeliveryAttempt(event.notificationId, 'fcm', 'exhausted', { totalAttempts: attempt });
    
    // Trigger SMS fallback if critical
    if (PRIORITY_CONFIG[event.priority].smsFallback) {
      await scheduleSMSFallback(userId, event, 0);
    }
    return;
  }
  
  // Exponential backoff: 5s, 15s, 45s, 135s
  const delaySeconds = Math.pow(3, attempt) * 5;
  
  await pubsub.topic('notification-retry').publish({
    userId,
    event,
    attempt: attempt + 1,
    maxAttempts,
  }, { delaySeconds });
}

exports.handleNotificationRetry = functions.pubsub
  .topic('notification-retry')
  .onPublish(async (message) => {
    const { userId, event, attempt, maxAttempts } = message.json;
    
    // Deduplicate: Check if already delivered
    const status = await getDeliveryStatus(event.notificationId);
    if (status === 'delivered') {
      return; // Already delivered, skip
    }
    
    await sendNotification(userId, { ...event, _retryAttempt: attempt });
  });
```

### 3.3 SMS Fallback

```javascript
async function scheduleSMSFallback(userId, event, delaySeconds) {
  // Check if SMS already sent for this notification
  const existing = await firestore
    .collection('notification_logs')
    .where('notificationId', '==', event.notificationId)
    .where('channel', '==', 'sms')
    .where('status', '==', 'delivered')
    .limit(1)
    .get();
  
  if (!existing.empty) return; // Already sent
  
  if (delaySeconds > 0) {
    await pubsub.topic('sms-fallback').publish({
      userId,
      event,
    }, { delaySeconds });
  } else {
    await sendSMS(userId, event);
  }
}

async function sendSMS(userId, event) {
  const user = await firestore.doc(`users/${userId}`).get();
  const phone = user.data().phone;
  
  // Rate limiting: Max 5 SMS per user per day
  const today = new Date().toISOString().slice(0, 10);
  const smsCount = await firestore
    .collection('notification_logs')
    .where('userId', '==', userId)
    .where('channel', '==', 'sms')
    .where('date', '==', today)
    .count()
    .get();
  
  if (smsCount.data().count >= 5) {
    await logDeliveryAttempt(event.notificationId, 'sms', 'throttled', 'daily_limit');
    return;
  }
  
  try {
    // Send via Twilio/MSG91
    await smsProvider.send(phone, event.smsBody || event.body);
    await logDeliveryAttempt(event.notificationId, 'sms', 'delivered');
    
    // Log for cost tracking
    await firestore.collection('sms_usage').add({
      userId,
      phone,
      notificationId: event.notificationId,
      cost: 0.25,
      date: today,
      timestamp: FieldValue.serverTimestamp(),
    });
    
  } catch (error) {
    await logDeliveryAttempt(event.notificationId, 'sms', 'failed', error.message);
  }
}
```

---

## 4. In-App Notification Inbox

### 4.1 Collection Structure

```javascript
/users/{userId}/notifications/{notificationId}

{
  notificationId: 'N1234567890_U456_booking_confirmed',
  
  // Content
  type: 'booking_confirmed',
  title: 'Booking Confirmed',
  body: 'Your booking at Royal Salon is confirmed for 2:00 PM',
  
  // References
  bookingId: 'B789',
  actionUrl: '/bookings/B789',
  
  // Status
  read: false,
  readAt: null,
  
  // Delivery tracking
  deliveryStatus: 'fcm_delivered',  // inbox_only | fcm_delivered | sms_delivered
  
  // Immutable
  createdAt: Timestamp,
}
```

### 4.2 Inbox Operations

```javascript
async function createInboxEntry(userId, notificationId, event) {
  await firestore.doc(`users/${userId}/notifications/${notificationId}`).set({
    notificationId,
    type: event.type,
    title: event.title,
    body: event.body,
    bookingId: event.data?.bookingId || null,
    actionUrl: event.data?.actionUrl || null,
    read: false,
    readAt: null,
    deliveryStatus: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function markAsRead(userId, notificationId) {
  await firestore.doc(`users/${userId}/notifications/${notificationId}`).update({
    read: true,
    readAt: FieldValue.serverTimestamp(),
  });
}

async function getUnreadCount(userId) {
  const unread = await firestore
    .collection(`users/${userId}/notifications`)
    .where('read', '==', false)
    .count()
    .get();
  
  return unread.data().count;
}
```

### 4.3 Retention Policy

```javascript
// Scheduled: Daily at 3 AM
exports.cleanupOldNotifications = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    
    const users = await firestore.collection('users').get();
    
    for (const user of users.docs) {
      const oldNotifications = await firestore
        .collection(`users/${user.id}/notifications`)
        .where('read', '==', true)
        .where('createdAt', '<', thirtyDaysAgo)
        .limit(500)
        .get();
      
      const batch = firestore.batch();
      oldNotifications.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
    }
  });
```

---

## 5. Edge Case Handling

### 5.1 App Killed During Acceptance Window

**Problem:** Freelancer's app is killed, FCM might not reach in time

**Solution:**
1. FCM data message triggers background sync
2. 30s timeout is enforced server-side
3. If no response, auto-reassign
4. SMS fallback for critical assignments

```javascript
// FCM data message for background handling
const message = {
  data: {
    type: 'job_request',
    bookingId: 'B123',
    deadline: deadline.toISOString(),
    requiresAction: 'true',
  },
  android: {
    priority: 'high',
    data: { click_action: 'FLUTTER_NOTIFICATION_CLICK' },
  },
};
```

### 5.2 Notifications Disabled

**Problem:** User has OS-level notifications disabled

**Solution:**
1. App detects notification permission status
2. Shows in-app banner: "Enable notifications to not miss bookings"
3. All notifications still go to in-app inbox
4. SMS fallback for critical events

### 5.3 Multiple Devices

**Problem:** User logged in on multiple devices

**Solution:**
```javascript
// Store all FCM tokens per user
fcmTokens: ['token_phone1', 'token_phone2', 'token_tablet']

// Send to all devices
const response = await admin.messaging().sendEachForMulticast({
  tokens: fcmTokens,
  // ... message
});
```

### 5.4 Invalid/Expired Tokens

```javascript
// Cleanup invalid tokens after failed send
response.responses.forEach((resp, idx) => {
  if (resp.error?.code === 'messaging/registration-token-not-registered') {
    tokensToRemove.push(fcmTokens[idx]);
  }
});

await firestore.doc(`users/${userId}`).update({
  fcmTokens: FieldValue.arrayRemove(...tokensToRemove),
});
```

### 5.5 High-Frequency Events

**Problem:** Assignment retries can spam notifications

**Solution:**
```javascript
// Deduplicate within time window
const recentNotifications = await firestore
  .collection(`users/${userId}/notifications`)
  .where('type', '==', event.type)
  .where('bookingId', '==', event.data.bookingId)
  .where('createdAt', '>', fiveMinutesAgo)
  .get();

if (!recentNotifications.empty) {
  // Update existing instead of creating new
  await recentNotifications.docs[0].ref.update({
    body: event.body,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return;
}
```

---

## 6. Delivery Logging

### 6.1 Log Structure

```javascript
/notification_logs/{logId}

{
  notificationId: 'N123',
  userId: 'U456',
  channel: 'fcm',              // fcm | sms | inbox
  status: 'delivered',         // pending | delivered | failed | skipped | throttled | exhausted
  attempt: 1,
  errorMessage: null,
  metadata: { successCount: 2, failedTokens: [] },
  date: '2026-02-02',
  timestamp: Timestamp,
}
```

### 6.2 Logging Function

```javascript
async function logDeliveryAttempt(notificationId, channel, status, metadata = null) {
  await firestore.collection('notification_logs').add({
    notificationId,
    channel,
    status,
    metadata: typeof metadata === 'string' ? { error: metadata } : metadata,
    date: new Date().toISOString().slice(0, 10),
    timestamp: FieldValue.serverTimestamp(),
  });
  
  // Update inbox entry status
  const [, userId] = notificationId.split('_');
  if (userId && status === 'delivered') {
    await firestore.doc(`users/${userId}/notifications/${notificationId}`).update({
      deliveryStatus: `${channel}_delivered`,
    });
  }
}
```

---

## 7. Monitoring & Alerting

### 7.1 Key Metrics

| Metric | Query | Alert Threshold |
|--------|-------|-----------------|
| FCM Delivery Rate | delivered / (delivered + failed) | < 90% |
| SMS Fallback Rate | sms_delivered / total_critical | > 20% |
| Retry Success Rate | retry_delivered / total_retries | < 50% |
| Daily SMS Cost | SUM(sms_usage.cost) | > ₹500 |
| Notification Latency | AVG(deliveredAt - createdAt) | > 5s |

### 7.2 Monitoring Queries

```javascript
// Daily notification report
async function generateDailyReport(date) {
  const logs = await firestore
    .collection('notification_logs')
    .where('date', '==', date)
    .get();
  
  const stats = {
    total: 0,
    fcm: { delivered: 0, failed: 0, skipped: 0 },
    sms: { delivered: 0, failed: 0, throttled: 0 },
  };
  
  logs.docs.forEach(doc => {
    const { channel, status } = doc.data();
    stats.total++;
    stats[channel][status] = (stats[channel][status] || 0) + 1;
  });
  
  return stats;
}
```

### 7.3 Alerts

```javascript
// Scheduled: Every hour
exports.checkNotificationHealth = functions.pubsub
  .schedule('0 * * * *')
  .onRun(async () => {
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    
    const logs = await firestore
      .collection('notification_logs')
      .where('timestamp', '>', oneHourAgo)
      .get();
    
    let delivered = 0, failed = 0;
    logs.docs.forEach(doc => {
      if (doc.data().status === 'delivered') delivered++;
      if (doc.data().status === 'failed') failed++;
    });
    
    const deliveryRate = delivered / (delivered + failed);
    
    if (deliveryRate < 0.9) {
      await notifyAdmins('notification_health_alert', {
        deliveryRate: (deliveryRate * 100).toFixed(1) + '%',
        delivered,
        failed,
      });
    }
  });
```

---

## 8. Abuse & Cost Control

### 8.1 Throttling

```javascript
const THROTTLE_LIMITS = {
  fcm: { perMinute: 10, perHour: 60 },
  sms: { perDay: 5 },
};

async function checkThrottle(userId, channel) {
  const limits = THROTTLE_LIMITS[channel];
  
  if (channel === 'sms') {
    const today = new Date().toISOString().slice(0, 10);
    const count = await firestore
      .collection('notification_logs')
      .where('userId', '==', userId)
      .where('channel', '==', 'sms')
      .where('date', '==', today)
      .count()
      .get();
    
    return count.data().count < limits.perDay;
  }
  
  // FCM throttle (per minute)
  const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
  const recentCount = await firestore
    .collection('notification_logs')
    .where('userId', '==', userId)
    .where('channel', '==', 'fcm')
    .where('timestamp', '>', oneMinuteAgo)
    .count()
    .get();
  
  return recentCount.data().count < limits.perMinute;
}
```

### 8.2 Deduplication

```javascript
async function shouldSendNotification(userId, type, bookingId) {
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
  
  const recent = await firestore
    .collection(`users/${userId}/notifications`)
    .where('type', '==', type)
    .where('bookingId', '==', bookingId)
    .where('createdAt', '>', fiveMinutesAgo)
    .limit(1)
    .get();
  
  return recent.empty;
}
```

### 8.3 Cost Tracking

```javascript
// Monthly SMS cost report
async function getMonthlySMSCost() {
  const startOfMonth = new Date();
  startOfMonth.setDate(1);
  startOfMonth.setHours(0, 0, 0, 0);
  
  const usage = await firestore
    .collection('sms_usage')
    .where('timestamp', '>=', startOfMonth)
    .get();
  
  const totalCost = usage.docs.reduce((sum, doc) => sum + doc.data().cost, 0);
  return totalCost;
}
```

---

## 9. Truth Reconstruction

**User can always reconstruct correct state from:**

1. **Firestore real-time subscriptions** - Booking status, payment status
2. **In-app notification inbox** - All events persisted
3. **Manual refresh** - Pull latest data from Firestore

**App startup logic:**
```
App launches
   ↓
Subscribe to bookings where status != COMPLETED
   ↓
Check for pending actions:
   - Freelancer: Check for pending job requests
   - Vendor: Check for pending acceptance requests
   ↓
Show any action-required banners
   ↓
Sync notification inbox
```

---

## Document Status

**Status:** Production-Ready  
**Version:** 1.0  
**Last Updated:** 2026-02-02

**This notification & trust layer is ready for implementation.** 🚀
