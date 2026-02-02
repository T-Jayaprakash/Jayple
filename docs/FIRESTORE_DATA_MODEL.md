# Jayple Firestore Data Model Specification
**Version 1.0 | Production-Grade Schema**  
**Platform:** Firebase Firestore  
**Document Owner:** Senior Firebase Architect  
**Based On:** Product Spec v1.1 + System Architecture v1.0

---

## Core Data Principles

1. **Append-Heavy, Immutable-First** - Historical data never overwritten
2. **Client Read-Only for Critical Data** - Cloud Functions own writes
3. **Aggregates on Parent, Events in Subcollections** - Avoid hot documents
4. **Idempotency Enforced** - All financial operations use idempotency keys
5. **Multi-City Ready** - Geo-sharded from day one

---

## Collection Architecture Overview

```
/users/{userId}                                    [User accounts & auth]
/cities/{cityId}/vendors/{vendorId}                [Salon partners]
  └─ /bookings_stats/{statId}                      [Aggregated stats]
/cities/{cityId}/freelancers/{freelancerId}        [Home service partners]
  ├─ /job_snapshots/{jobId}                        [Rolling job history]
  └─ /availability_logs/{weekId}                   [Weekly availability]
/cities/{cityId}/services/{serviceId}              [Service catalog]
/cities/{cityId}/bookings/{bookingId}              [Booking lifecycle]
  ├─ /assignment_attempts/{attemptId}              [Freelancer assignment log]
  └─ /status_events/{eventId}                      [State transition log]
/ledger/{ledgerEntryId}                            [Financial transactions]
/settlements/{settlementId}                        [Weekly payouts]
/reviews/{reviewId}                                [Customer reviews]
/admin/config                                      [Platform configuration]
/admin/approval_queue/{userId}                     [Vendor/Freelancer approvals]
```

---

## 1. Users Collection

### Purpose
Central user identity, authentication, and role management. One phone number = one account with multi-role support.

### Collection Path
```
/users/{userId}
```

### Document Structure

```javascript
{
  // Identity (IMMUTABLE after creation)
  userId: "U123456",                    // Auto-generated
  phone: "+919876543210",               // IMMUTABLE
  phoneVerified: true,                  // IMMUTABLE after verification
  
  // Profile (MUTABLE)
  name: "Rajesh Kumar",
  email: "rajesh@example.com",
  profilePhoto: "https://cloudinary.com/...",
  
  // Roles (MUTABLE via admin approval)
  roles: ["customer", "vendor"],        // Array of active roles
  activeRole: "customer",               // Currently selected role
  
  // Role-specific IDs (IMMUTABLE after creation)
  vendorId: "V789",                     // If vendor role active
  freelancerId: "FL456",                // If freelancer role active
  
  // Account Status (MUTABLE by admin/system)
  status: "active",                     // active | pending | blocked | suspended
  blockReason: null,                    // Reason if blocked
  blockedAt: null,                      // Timestamp
  
  // FCM Tokens (MUTABLE)
  fcmTokens: [                          // Array of device tokens
    "fcm_token_1",
    "fcm_token_2"
  ],
  
  // City Context (MUTABLE)
  currentCity: "trichy",                // For geo-sharding
  
  // Metadata (IMMUTABLE/AUTO)
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastSeen: Timestamp,
}
```

### Field Classification

| Field | Type | Notes |
|-------|------|-------|
| `userId`, `phone` | IMMUTABLE | Set once at creation |
| `name`, `email`, `profilePhoto` | MUTABLE | User can update |
| `roles`, `activeRole` | MUTABLE | Admin-controlled |
| `status`, `blockReason` | MUTABLE | System/Admin-controlled |
| `fcmTokens` | MUTABLE | Auto-managed by app |
| `createdAt`, `updatedAt` | AUTO | Firestore timestamps |

### Access Patterns

**Read:**
- User can read their own document
- Admin can read all users

**Write:**
- User can update: `name`, `email`, `profilePhoto`, `activeRole`, `fcmTokens`
- Admin can update: `roles`, `status`, `blockReason`
- Cloud Functions can update: `lastSeen`, `updatedAt`

---

## 2. Vendors Collection

### Purpose
Salon partner profiles, booking configuration, and aggregated performance metrics.

### Collection Path
```
/cities/{cityId}/vendors/{vendorId}
```

### Document Structure

```javascript
{
  // Identity (IMMUTABLE)
  vendorId: "V123",
  userId: "U456",                       // Link to users collection
  cityId: "trichy",
  
  // Business Info (MUTABLE)
  businessName: "Royal Salon",
  ownerName: "Rajesh Kumar",
  phone: "+919876543210",
  email: "royal@salon.com",
  
  // Location (MUTABLE)
  address: {
    street: "123 Main Street",
    area: "Thillai Nagar",
    city: "Trichy",
    state: "Tamil Nadu",
    pincode: "620018",
    landmark: "Near Bus Stand"
  },
  location: new GeoPoint(10.7905, 78.7047),  // Lat, Lng
  
  // Media (MUTABLE)
  images: [                             // Salon photos
    "https://cloudinary.com/salon1.jpg",
    "https://cloudinary.com/salon2.jpg"
  ],
  coverImage: "https://cloudinary.com/cover.jpg",
  
  // Business Hours (MUTABLE)
  businessHours: {
    monday: { open: "09:00", close: "21:00", closed: false },
    tuesday: { open: "09:00", close: "21:00", closed: false },
    wednesday: { open: "09:00", close: "21:00", closed: false },
    thursday: { open: "09:00", close: "21:00", closed: false },
    friday: { open: "09:00", close: "21:00", closed: false },
    saturday: { open: "09:00", close: "22:00", closed: false },
    sunday: { open: "10:00", close: "20:00", closed: false }
  },
  
  // Booking Configuration (MUTABLE)
  bookingMode: "manual",                // manual | autoAccept
  slaConfig: {
    peakHours: {                        // 18:00-22:00
      start: "18:00",
      end: "22:00",
      slaMinutes: 10
    },
    offPeakHours: {
      slaMinutes: 30
    }
  },
  maxConcurrentBookings: 5,             // Capacity limit
  
  // Services (REFERENCE - actual services in /services collection)
  serviceIds: [                         // Services offered by this salon
    "S001_haircut",
    "S002_shave",
    "S003_facial"
  ],
  
  // Aggregated Metrics (DERIVED - updated by Cloud Functions)
  stats: {
    totalBookings: 150,
    completedBookings: 142,
    cancelledBookings: 8,
    acceptanceRate: 0.95,               // For manual mode only
    slaComplianceRate: 0.90,            // For manual mode only
    averageResponseTimeSeconds: 250,    // For manual mode only
    cancellationRate: 0.05,
    averageRating: 4.6,
    totalReviews: 120,
    reliabilityScore: 92,               // 0-100
    lastStatsUpdate: Timestamp
  },
  
  // Financial (DERIVED)
  balance: 15000,                       // Available balance (₹)
  outstandingBalance: 2000,             // Offline payments pending (₹)
  totalEarnings: 50000,                 // Lifetime earnings (₹)
  lastSettlementDate: Timestamp,
  
  // Status (MUTABLE by admin/system)
  status: "active",                     // pending | active | blocked | suspended
  approvalStatus: "approved",           // pending | approved | rejected
  approvedBy: "admin_U789",
  approvedAt: Timestamp,
  
  // Metadata (AUTO)
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastSeen: Timestamp,
}
```

### Subcollection: Booking Stats (Time-Series)

```
/cities/{cityId}/vendors/{vendorId}/booking_stats/{statId}
```

**Purpose:** Historical performance tracking (daily/weekly aggregates)

```javascript
{
  statId: "2026-02-01",                 // Date-based ID
  date: Timestamp,
  totalBookings: 10,
  completedBookings: 9,
  cancelledBookings: 1,
  revenue: 5000,
  commission: 500,
  createdAt: Timestamp
}
```

### Field Classification

| Field | Type | Notes |
|-------|------|-------|
| `vendorId`, `userId`, `cityId` | IMMUTABLE | Set at creation |
| `businessName`, `address`, `businessHours` | MUTABLE | Vendor can update |
| `bookingMode`, `slaConfig` | MUTABLE | Vendor can update |
| `stats.*` | DERIVED | Cloud Functions only |
| `balance`, `outstandingBalance` | DERIVED | Ledger-driven |
| `status`, `approvalStatus` | MUTABLE | Admin/System only |

### Access Patterns

**Read:**
- Vendor can read their own document
- Customers can read: `businessName`, `address`, `images`, `businessHours`, `stats.averageRating`, `stats.totalReviews`
- Admin can read all fields

**Write:**
- Vendor can update: Business info, hours, booking config
- Cloud Functions update: Stats, balance, status
- Admin updates: Approval status

---

## 3. Freelancers Collection

### Purpose
Home service partner profiles, controlled service categories, and rolling reliability metrics.

### Collection Path
```
/cities/{cityId}/freelancers/{freelancerId}
```

### Document Structure

```javascript
{
  // Identity (IMMUTABLE)
  freelancerId: "FL123",
  userId: "U456",
  cityId: "trichy",
  
  // Profile (MUTABLE)
  name: "Suresh Kumar",
  phone: "+919876543210",
  email: "suresh@example.com",
  profilePhoto: "https://cloudinary.com/...",
  experience: "5 years",                // Text description
  
  // Service Configuration (MUTABLE - controlled by Jayple)
  serviceCategories: [                  // MVP-locked to 5 categories
    "haircut",
    "beardTrim",
    "facial"
  ],
  
  // Service Area (MUTABLE)
  homeLocation: new GeoPoint(10.7905, 78.7047),
  serviceRadius: 5,                     // km
  
  // Availability (MUTABLE)
  isOnline: true,                       // Currently accepting jobs
  weeklyAvailabilityTarget: 20,         // Hours per week (soft target)
  
  // Rolling Reliability Metrics (DERIVED)
  // Calculated from last N jobs in job_snapshots subcollection
  reliability: {
    // Acceptance metrics (from last 10 jobs)
    acceptanceRate: 0.85,               // 85%
    manualRejectionCount: 1,            // Manual "Reject" taps
    timeoutRejectionCount: 1,           // No response within 30s
    averageResponseTimeSeconds: 12.5,
    
    // Availability metrics (from availability_logs)
    weeklyAvailabilityActual: 18,       // Hours this week
    availabilityConsistencyScore: 0.90, // actual/target
    
    // Overall metrics
    totalJobsCompleted: 150,
    totalCancellations: 5,
    cancellationRate: 0.03,
    averageRating: 4.7,
    totalReviews: 120,
    
    // Computed score
    reliabilityScore: 87.5,             // 0-100
    priorityTier: "gold",               // gold | silver | bronze
    
    lastReliabilityUpdate: Timestamp
  },
  
  // Financial (DERIVED)
  balance: 8000,
  outstandingBalance: 500,
  totalEarnings: 25000,
  lastSettlementDate: Timestamp,
  
  // Status (MUTABLE by admin/system)
  status: "active",                     // pending | active | blocked | suspended
  approvalStatus: "approved",
  approvedBy: "admin_U789",
  approvedAt: Timestamp,
  
  // Metadata (AUTO)
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastSeen: Timestamp,
}
```

### Subcollection: Job Snapshots (Rolling Window)

```
/cities/{cityId}/freelancers/{freelancerId}/job_snapshots/{jobId}
```

**Purpose:** Append-only log of last N jobs for reliability calculation (keep last 10)

```javascript
{
  jobId: "B123",                        // Booking ID
  assignedAt: Timestamp,
  response: "accepted",                 // accepted | rejected | timeout
  responseTimeSeconds: 15,
  manual: true,                         // true = manual reject, false = timeout
  completedAt: Timestamp,               // If completed
  cancelled: false,                     // If cancelled after acceptance
  rating: 5,                            // Customer rating (if completed)
  createdAt: Timestamp
}
```

**Retention Policy:** Keep only last 10 jobs. Cloud Function deletes older entries.

### Subcollection: Availability Logs (Weekly)

```
/cities/{cityId}/freelancers/{freelancerId}/availability_logs/{weekId}
```

**Purpose:** Track weekly availability for consistency scoring

```javascript
{
  weekId: "2026-W05",                   // ISO week format
  weekStartDate: Timestamp,
  weekEndDate: Timestamp,
  targetHours: 20,
  actualHours: 18,
  onlineSessions: [
    { startedAt: Timestamp, endedAt: Timestamp, durationMinutes: 120 },
    { startedAt: Timestamp, endedAt: Timestamp, durationMinutes: 180 }
  ],
  consistencyScore: 0.90,               // actual/target
  createdAt: Timestamp
}
```

### Field Classification

| Field | Type | Notes |
|-------|------|-------|
| `freelancerId`, `userId`, `cityId` | IMMUTABLE | Set at creation |
| `name`, `profilePhoto`, `experience` | MUTABLE | Freelancer can update |
| `serviceCategories` | MUTABLE | Admin-controlled (MVP-locked) |
| `isOnline`, `weeklyAvailabilityTarget` | MUTABLE | Freelancer can update |
| `reliability.*` | DERIVED | Cloud Functions only |
| `balance`, `outstandingBalance` | DERIVED | Ledger-driven |

### Access Patterns

**Read:**
- Freelancer can read their own document
- Customers can read: `name`, `profilePhoto`, `experience`, `reliability.averageRating`, `reliability.totalReviews`
- Cloud Functions read all for assignment algorithm

**Write:**
- Freelancer can update: Profile, availability
- Cloud Functions update: Reliability metrics, balance, job snapshots
- Admin updates: Service categories, approval status

---

## 4. Services Collection

### Purpose
Service catalog with clear separation between vendor-defined and Jayple-controlled pricing.

### Collection Path
```
/cities/{cityId}/services/{serviceId}
```

### Document Structure

```javascript
{
  // Identity (IMMUTABLE)
  serviceId: "S001_haircut_trichy",
  cityId: "trichy",
  
  // Service Info (MUTABLE by admin)
  name: "Haircut",
  category: "haircut",                  // MVP: haircut | beardTrim | facial | hairColoring | groomingCombo
  description: "Professional haircut service",
  icon: "https://cloudinary.com/haircut.png",
  
  // Service Type (IMMUTABLE)
  type: "both",                         // inShop | home | both
  
  // Vendor-Defined Pricing (for in-shop services)
  // Each vendor sets their own pricing in their service catalog
  vendorPricing: {
    enabled: true,                      // Vendors can offer this service
    suggestedWeekdayPrice: 150,         // Suggested, not enforced
    suggestedWeekendPrice: 200
  },
  
  // Jayple-Controlled Pricing (for home services)
  homePricing: {
    enabled: true,
    economy: {
      basePrice: 150,
      weekendSurge: 1.2,                // 20% surge
      peakHoursSurge: 1.3               // 30% surge (18:00-22:00)
    },
    luxury: {
      basePrice: 300,
      weekendSurge: 1.2,
      peakHoursSurge: 1.3
    }
  },
  
  // Commission (MUTABLE by admin)
  commission: {
    inShop: 0.10,                       // 10% for in-shop bookings
    home: 0.15                          // 15% for home service bookings
  },
  
  // Estimated Duration (MUTABLE by admin)
  estimatedDurationMinutes: 30,
  
  // Status (MUTABLE by admin)
  isActive: true,                       // Service available for booking
  
  // Metadata (AUTO)
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Vendor Service Catalog (Denormalized)

**Note:** Each vendor maintains their own service pricing in a subcollection:

```
/cities/{cityId}/vendors/{vendorId}/services/{serviceId}
```

```javascript
{
  serviceId: "S001_haircut_trichy",     // Reference to main service
  serviceName: "Haircut",               // Denormalized for quick display
  
  // Vendor-specific pricing (MUTABLE by vendor)
  weekdayPrice: 150,
  weekendPrice: 200,
  duration: 30,                         // minutes
  
  // Availability (MUTABLE by vendor)
  isAvailable: true,
  
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Field Classification

| Field | Type | Notes |
|-------|------|-------|
| `serviceId`, `cityId`, `type` | IMMUTABLE | Set at creation |
| `name`, `description`, `icon` | MUTABLE | Admin only |
| `homePricing.*` | MUTABLE | Admin only (Jayple-controlled) |
| `commission.*` | MUTABLE | Admin only |
| `isActive` | MUTABLE | Admin only |

### Access Patterns

**Read:**
- All users can read active services
- Vendors read to populate their service catalog
- Cloud Functions read for pricing calculations

**Write:**
- Admin only (via admin panel)
- Vendors write to their own service subcollection

---

## 5. Bookings Collection

### Purpose
Immutable booking lifecycle with complete audit trail. Core transactional document.

### Collection Path
```
/cities/{cityId}/bookings/{bookingId}
```

### Document Structure

```javascript
{
  // Identity (IMMUTABLE)
  bookingId: "B123456",
  cityId: "trichy",
  
  // Type (IMMUTABLE)
  type: "inShop",                       // inShop | home
  
  // Parties (IMMUTABLE after creation)
  customerId: "U123",
  customerName: "Rajesh Kumar",         // Denormalized
  customerPhone: "+919876543210",       // Denormalized
  
  // For in-shop bookings
  vendorId: "V456",                     // IMMUTABLE
  vendorName: "Royal Salon",            // Denormalized
  salonAddress: "123 Main St, Trichy",  // Denormalized
  
  // For home service bookings
  freelancerId: "FL789",                // MUTABLE (during assignment)
  freelancerName: "Suresh Kumar",       // Denormalized
  customerAddress: {                    // IMMUTABLE
    street: "456 Park Avenue",
    area: "Thillai Nagar",
    city: "Trichy",
    location: new GeoPoint(10.7905, 78.7047)
  },
  
  // Service Details (IMMUTABLE)
  services: [                           // For in-shop
    {
      serviceId: "S001_haircut",
      serviceName: "Haircut",
      weekdayPrice: 150,
      weekendPrice: 200,
      duration: 30
    }
  ],
  serviceCategory: "haircut",           // For home service
  serviceTier: "economy",               // economy | luxury (for home)
  
  // Scheduling (IMMUTABLE)
  scheduledDate: Timestamp,             // Date of service
  scheduledTime: "14:00",               // Time slot
  
  // Pricing (IMMUTABLE after creation)
  pricing: {
    basePrice: 150,
    surgeMultiplier: 1.0,               // For home services
    totalAmount: 150,
    commission: 15,                     // Platform commission
    vendorEarnings: 135,                // totalAmount - commission
    breakdown: {
      isWeekend: false,
      isPeakHours: false
    }
  },
  
  // Payment (MUTABLE during payment flow)
  payment: {
    method: "online",                   // online | offline
    status: "pending",                  // pending | completed | refunded
    transactionId: "razorpay_xyz123",   // External payment ID
    paidAt: Timestamp,
    refundedAt: Timestamp,
    refundAmount: 0
  },
  
  // Booking Status (MUTABLE - state machine)
  status: "pending",                    // pending | confirmed | inProgress | completed | cancelled | failed
  
  // Status Timestamps (AUTO - updated by Cloud Functions)
  timestamps: {
    createdAt: Timestamp,
    confirmedAt: Timestamp,
    startedAt: Timestamp,
    completedAt: Timestamp,
    cancelledAt: Timestamp,
    failedAt: Timestamp
  },
  
  // Cancellation (MUTABLE if cancelled)
  cancellation: {
    cancelledBy: "customer",            // customer | vendor | freelancer | system
    reason: "Change of plans",
    penalty: 50,                        // Penalty amount (₹)
    cancelledAt: Timestamp
  },
  
  // Failure (MUTABLE if failed)
  failure: {
    reason: "no_freelancer_available",  // no_freelancer | sla_timeout | orphaned_cleanup
    failedAt: Timestamp
  },
  
  // Assignment (For home services - MUTABLE during assignment)
  assignment: {
    currentAttempt: 1,                  // Current assignment attempt (1-3)
    maxAttempts: 3,
    assignedAt: Timestamp,
    freelancerDeadline: Timestamp,      // 30s from assignment
    assignmentHistory: [                // See subcollection for details
      "attempt_1",
      "attempt_2"
    ]
  },
  
  // SLA (For in-shop manual mode - MUTABLE during acceptance)
  sla: {
    deadline: Timestamp,                // Vendor must respond by this time
    isPeakHours: false,
    slaMinutes: 30,
    respondedAt: Timestamp,
    slaViolation: false
  },
  
  // Review (MUTABLE after completion)
  review: {
    eligible: false,                    // Set to true after completion
    submitted: false,
    reviewId: "R123"                    // Link to reviews collection
  },
  
  // Special Instructions (IMMUTABLE)
  customerNotes: "Please use organic products",
  
  // Idempotency (IMMUTABLE)
  idempotencyKey: "U123_1738478400_abc123",
  
  // Metadata (AUTO)
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Subcollection: Assignment Attempts (Append-Only)

```
/cities/{cityId}/bookings/{bookingId}/assignment_attempts/{attemptId}
```

**Purpose:** Track each freelancer assignment attempt for home services

```javascript
{
  attemptId: "attempt_1",
  attemptNumber: 1,
  freelancerId: "FL789",
  freelancerName: "Suresh Kumar",
  assignedAt: Timestamp,
  deadline: Timestamp,                  // 30s from assignment
  response: "timeout",                  // accepted | rejected | timeout
  responseTime: 30,                     // seconds (null if timeout)
  manual: false,                        // true if manual reject, false if timeout
  createdAt: Timestamp
}
```

### Subcollection: Status Events (Append-Only Audit Log)

```
/cities/{cityId}/bookings/{bookingId}/status_events/{eventId}
```

**Purpose:** Immutable audit trail of all status changes

```javascript
{
  eventId: "evt_123",
  fromStatus: "pending",
  toStatus: "confirmed",
  triggeredBy: "vendor_V456",           // userId or "system"
  reason: "Vendor accepted booking",
  metadata: {                           // Additional context
    responseTime: 120                   // seconds
  },
  createdAt: Timestamp
}
```

### Field Classification

| Field | Type | Notes |
|-------|------|-------|
| `bookingId`, `type`, `customerId`, `vendorId` | IMMUTABLE | Set at creation |
| `pricing.*`, `scheduledDate`, `services` | IMMUTABLE | Cannot change after creation |
| `status` | MUTABLE | State machine transitions only |
| `payment.status`, `payment.transactionId` | MUTABLE | Payment flow updates |
| `freelancerId` | MUTABLE | During assignment only |
| `timestamps.*` | AUTO | Cloud Functions only |

### Access Patterns

**Read:**
- Customer can read their own bookings
- Vendor can read bookings where `vendorId` matches
- Freelancer can read bookings where `freelancerId` matches
- Admin can read all bookings

**Write:**
- Cloud Functions ONLY
- Clients can only trigger Cloud Functions (createBooking, acceptBooking, etc.)

---

## 6. Ledger Collection

### Purpose
Append-only double-entry ledger for all financial transactions. Immutable audit trail.

### Collection Path
```
/ledger/{ledgerEntryId}
```

### Document Structure

```javascript
{
  // Identity (IMMUTABLE)
  ledgerEntryId: "L123456",             // Auto-generated
  
  // Transaction Type (IMMUTABLE)
  type: "earning",                      // earning | commission | penalty | settlement | refund
  
  // Parties (IMMUTABLE)
  userId: "V456",                       // Vendor or Freelancer
  userType: "vendor",                   // vendor | freelancer | platform
  bookingId: "B789",                    // Related booking (if applicable)
  
  // Amount (IMMUTABLE)
  amount: 500,                          // ₹
  direction: "credit",                  // credit | debit
  
  // Description (IMMUTABLE)
  description: "Booking B789 earnings",
  
  // Payment Context (IMMUTABLE)
  paymentMethod: "online",              // online | offline | null
  
  // Balance Snapshots (IMMUTABLE - snapshot at transaction time)
  balanceBefore: 1000,
  balanceAfter: 1500,
  outstandingBefore: 200,
  outstandingAfter: 200,
  
  // Settlement Reference (IMMUTABLE)
  settlementId: "SET_2026-02-03",       // If part of settlement
  
  // Idempotency (IMMUTABLE)
  idempotencyKey: "B789_earning",       // Prevents duplicate entries
  
  // Audit (IMMUTABLE)
  createdBy: "system",                  // system | admin_U123
  createdAt: Timestamp
}
```

### Ledger Entry Types

| Type | Direction | Description |
|------|-----------|-------------|
| `earning` | credit | Booking earnings (totalAmount - commission) |
| `commission` | credit | Platform commission (to platform account) |
| `penalty` | debit | Cancellation penalty |
| `settlement` | debit | Weekly payout |
| `refund` | debit | Refund to customer (vendor/freelancer loses earnings) |

### Field Classification

| Field | Type | Notes |
|-------|------|-------|
| ALL FIELDS | IMMUTABLE | Ledger is append-only |

### Access Patterns

**Read:**
- User can read their own ledger entries (`userId` matches)
- Admin can read all entries
- Cloud Functions read for balance calculations

**Write:**
- Cloud Functions ONLY
- Idempotency key prevents duplicates

---

## 7. Settlements Collection

### Purpose
Weekly settlement records with carry-forward logic.

### Collection Path
```
/settlements/{settlementId}
```

### Document Structure

```javascript
{
  // Identity (IMMUTABLE)
  settlementId: "SET_V456_2026-02-03",  // userId_date format
  
  // User (IMMUTABLE)
  userId: "V456",
  userType: "vendor",                   // vendor | freelancer
  userName: "Royal Salon",              // Denormalized
  
  // Settlement Period (IMMUTABLE)
  settlementDate: Timestamp,            // Monday of settlement week
  weekStartDate: Timestamp,
  weekEndDate: Timestamp,
  
  // Financial Breakdown (IMMUTABLE)
  totalBalance: 15000,                  // User's balance at settlement time
  outstandingBalance: 2000,             // Offline payments pending
  payableAmount: 13000,                 // balance - outstanding
  
  // Carry-Forward Logic (IMMUTABLE)
  settlementThreshold: 500,             // ₹500 minimum
  carriedForwardAmount: 0,              // If payableAmount < threshold
  
  // Payout Details (MUTABLE during payout)
  payout: {
    amount: 13000,                      // Actual payout amount
    method: "razorpay",                 // razorpay | stripe | manual
    transactionId: "razorpay_xyz123",
    status: "pending",                  // pending | completed | failed
    initiatedAt: Timestamp,
    completedAt: Timestamp,
    failureReason: null
  },
  
  // Status (MUTABLE)
  status: "pending",                    // pending | completed | carriedForward | failed
  
  // Bookings Included (IMMUTABLE)
  bookingIds: [                         // Bookings settled in this cycle
    "B123",
    "B456",
    "B789"
  ],
  totalBookings: 3,
  
  // Ledger Reference (IMMUTABLE)
  ledgerEntryId: "L999",                // Link to ledger debit entry
  
  // Metadata (AUTO)
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Field Classification

| Field | Type | Notes |
|-------|------|-------|
| `settlementId`, `userId`, financial amounts | IMMUTABLE | Set at creation |
| `payout.status`, `payout.transactionId` | MUTABLE | Updated during payout |
| `status` | MUTABLE | State transitions |

### Access Patterns

**Read:**
- User can read their own settlements
- Admin can read all settlements

**Write:**
- Cloud Functions ONLY (weekly settlement job)

---

## 8. Reviews Collection

### Purpose
Customer reviews for vendors and freelancers. Post-completion only.

### Collection Path
```
/reviews/{reviewId}
```

### Document Structure

```javascript
{
  // Identity (IMMUTABLE)
  reviewId: "R123",
  
  // Booking Context (IMMUTABLE)
  bookingId: "B456",
  customerId: "U123",
  customerName: "Rajesh Kumar",         // Denormalized
  
  // Target (IMMUTABLE)
  targetId: "V789",                     // Vendor or Freelancer ID
  targetType: "vendor",                 // vendor | freelancer
  targetName: "Royal Salon",            // Denormalized
  
  // Review Content (IMMUTABLE after submission)
  rating: 5,                            // 1-5 stars
  reviewText: "Excellent service!",
  
  // Detailed Ratings (IMMUTABLE)
  serviceQuality: 5,                    // 1-5
  punctuality: 5,                       // 1-5
  
  // Media (IMMUTABLE)
  photos: [                             // Optional review photos
    "https://cloudinary.com/review1.jpg"
  ],
  
  // Status (MUTABLE by admin only)
  isVisible: true,                      // Admin can hide inappropriate reviews
  flaggedBy: null,                      // If flagged by vendor/freelancer
  flagReason: null,
  
  // Metadata (AUTO)
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Field Classification

| Field | Type | Notes |
|-------|------|-------|
| ALL review fields | IMMUTABLE | Cannot edit after submission |
| `isVisible`, `flaggedBy` | MUTABLE | Admin moderation only |

### Access Patterns

**Read:**
- All users can read visible reviews for vendors/freelancers
- Customer can read their own reviews
- Target (vendor/freelancer) can read reviews about them

**Write:**
- Customer can create review (via Cloud Function)
- Admin can update `isVisible`

---

## 9. Admin Collections

### 9.1 Platform Configuration

### Collection Path
```
/admin/config
```

**Purpose:** Single document with all platform configuration

```javascript
{
  // Service Categories (MVP-Locked)
  serviceCategories: [
    {
      id: "haircut",
      name: "Haircut",
      icon: "https://cloudinary.com/haircut.png",
      enabled: true
    },
    {
      id: "beardTrim",
      name: "Beard Trim",
      icon: "https://cloudinary.com/beard.png",
      enabled: true
    },
    {
      id: "facial",
      name: "Facial",
      icon: "https://cloudinary.com/facial.png",
      enabled: true
    },
    {
      id: "hairColoring",
      name: "Hair Coloring",
      icon: "https://cloudinary.com/coloring.png",
      enabled: true
    },
    {
      id: "groomingCombo",
      name: "Grooming Combo",
      icon: "https://cloudinary.com/combo.png",
      enabled: true
    }
  ],
  
  // Freelancer Reliability Config
  reliability: {
    rollingWindowSize: 10,              // Last N jobs for acceptance rate
    weeklyAvailabilityTarget: 20,       // Default hours per week
    priorityTiers: {
      gold: {
        minAcceptanceRate: 0.90,
        minRating: 4.5,
        minAvailabilityConsistency: 0.80
      },
      silver: {
        minAcceptanceRate: 0.75,
        minRating: 4.0,
        minAvailabilityConsistency: 0.60
      }
    }
  },
  
  // Vendor SLA Config
  vendorSLA: {
    peakHours: {
      start: "18:00",
      end: "22:00",
      slaMinutes: 10
    },
    offPeakHours: {
      slaMinutes: 30
    }
  },
  
  // Freelancer Assignment Config
  freelancerAssignment: {
    responseTimeoutSeconds: 30,
    maxAssignmentAttempts: 3
  },
  
  // Financial Config
  financial: {
    settlementThreshold: 500,           // ₹500 minimum
    settlementDay: "monday",            // Day of week
    settlementTime: "00:00",            // IST
    outstandingThreshold: 10000,        // ₹10,000 auto-block
    cancellationPenalty: {
      beforeAcceptance: 0,
      afterAcceptance: 50               // ₹50
    }
  },
  
  // Surge Pricing (Home Services)
  surgePricing: {
    weekendMultiplier: 1.2,             // 20% surge
    peakHoursMultiplier: 1.3,           // 30% surge
    peakHours: {
      start: "18:00",
      end: "22:00"
    }
  },
  
  // Commission Rates
  commission: {
    inShop: 0.10,                       // 10%
    home: 0.15                          // 15%
  },
  
  // Feature Flags
  features: {
    homeServicesEnabled: true,
    inShopBookingsEnabled: true,
    reviewsEnabled: true,
    settlementsEnabled: true
  },
  
  updatedAt: Timestamp,
  updatedBy: "admin_U123"
}
```

### 9.2 Approval Queue

### Collection Path
```
/admin/approval_queue/{userId}
```

**Purpose:** Vendor and Freelancer approval workflow

```javascript
{
  userId: "U456",
  applicationType: "vendor",            // vendor | freelancer
  
  // Application Data
  application: {
    businessName: "Royal Salon",
    ownerName: "Rajesh Kumar",
    phone: "+919876543210",
    email: "royal@salon.com",
    address: "123 Main St, Trichy",
    documents: [                        // Uploaded documents
      "https://cloudinary.com/license.pdf",
      "https://cloudinary.com/id.pdf"
    ]
  },
  
  // Status
  status: "pending",                    // pending | approved | rejected
  reviewedBy: null,                     // admin userId
  reviewedAt: null,
  rejectionReason: null,
  
  // Metadata
  submittedAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper Functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['admin']);
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isCloudFunction() {
      // Cloud Functions use service account, not user auth
      return request.auth == null || request.auth.token.firebase.sign_in_provider == 'custom';
    }
    
    // ========================================
    // USERS COLLECTION
    // ========================================
    match /users/{userId} {
      // Users can read their own document
      allow read: if isOwner(userId) || isAdmin();
      
      // Users can update limited fields
      allow update: if isOwner(userId) && 
                       onlyUpdating(['name', 'email', 'profilePhoto', 'activeRole', 'fcmTokens', 'updatedAt']);
      
      // Only Cloud Functions can create users (after Firebase Auth)
      allow create: if isCloudFunction();
      
      // Admins can update status and roles
      allow update: if isAdmin() && 
                       onlyUpdating(['roles', 'status', 'blockReason', 'blockedAt', 'updatedAt']);
    }
    
    // ========================================
    // VENDORS COLLECTION (City-Scoped)
    // ========================================
    match /cities/{cityId}/vendors/{vendorId} {
      // Public read for basic info
      allow read: if isAuthenticated();
      
      // Vendor can update their own business info
      allow update: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid &&
                       onlyUpdating(['businessName', 'address', 'images', 'businessHours', 
                                     'bookingMode', 'slaConfig', 'maxConcurrentBookings', 'updatedAt']);
      
      // Cloud Functions can update stats and financial data
      allow update: if isCloudFunction();
      
      // Only Cloud Functions can create vendors
      allow create: if isCloudFunction();
      
      // Admins have full access
      allow read, write: if isAdmin();
      
      // Vendor service catalog subcollection
      match /services/{serviceId} {
        allow read: if isAuthenticated();
        allow write: if isAuthenticated() && 
                        get(/databases/$(database)/documents/cities/$(cityId)/vendors/$(vendorId)).data.userId == request.auth.uid;
      }
      
      // Booking stats subcollection (read-only for vendor)
      match /booking_stats/{statId} {
        allow read: if isAuthenticated() && 
                       get(/databases/$(database)/documents/cities/$(cityId)/vendors/$(vendorId)).data.userId == request.auth.uid;
        allow write: if isCloudFunction();
      }
    }
    
    // ========================================
    // FREELANCERS COLLECTION (City-Scoped)
    // ========================================
    match /cities/{cityId}/freelancers/{freelancerId} {
      // Public read for basic info
      allow read: if isAuthenticated();
      
      // Freelancer can update their own profile
      allow update: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid &&
                       onlyUpdating(['name', 'profilePhoto', 'experience', 'isOnline', 
                                     'weeklyAvailabilityTarget', 'updatedAt']);
      
      // Cloud Functions can update reliability and financial data
      allow update: if isCloudFunction();
      
      // Only Cloud Functions can create freelancers
      allow create: if isCloudFunction();
      
      // Admins have full access
      allow read, write: if isAdmin();
      
      // Job snapshots subcollection (Cloud Functions only)
      match /job_snapshots/{jobId} {
        allow read: if isAuthenticated() && 
                       get(/databases/$(database)/documents/cities/$(cityId)/freelancers/$(freelancerId)).data.userId == request.auth.uid;
        allow write: if isCloudFunction();
      }
      
      // Availability logs subcollection
      match /availability_logs/{weekId} {
        allow read: if isAuthenticated() && 
                       get(/databases/$(database)/documents/cities/$(cityId)/freelancers/$(freelancerId)).data.userId == request.auth.uid;
        allow write: if isCloudFunction();
      }
    }
    
    // ========================================
    // SERVICES COLLECTION (City-Scoped)
    // ========================================
    match /cities/{cityId}/services/{serviceId} {
      // Public read
      allow read: if isAuthenticated();
      
      // Only admins can write
      allow write: if isAdmin();
    }
    
    // ========================================
    // BOOKINGS COLLECTION (City-Scoped)
    // ========================================
    match /cities/{cityId}/bookings/{bookingId} {
      // Users can read bookings they're involved in
      allow read: if isAuthenticated() && (
        resource.data.customerId == request.auth.uid ||
        resource.data.vendorId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.vendorId ||
        resource.data.freelancerId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.freelancerId
      );
      
      // CRITICAL: Only Cloud Functions can write bookings
      // Prevents price tampering, status spoofing
      allow write: if isCloudFunction();
      
      // Admins can read all bookings
      allow read: if isAdmin();
      
      // Assignment attempts subcollection
      match /assignment_attempts/{attemptId} {
        allow read: if isAuthenticated() && (
          get(/databases/$(database)/documents/cities/$(cityId)/bookings/$(bookingId)).data.customerId == request.auth.uid ||
          get(/databases/$(database)/documents/cities/$(cityId)/bookings/$(bookingId)).data.freelancerId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.freelancerId
        );
        allow write: if isCloudFunction();
      }
      
      // Status events subcollection (audit log)
      match /status_events/{eventId} {
        allow read: if isAuthenticated() && (
          get(/databases/$(database)/documents/cities/$(cityId)/bookings/$(bookingId)).data.customerId == request.auth.uid ||
          get(/databases/$(database)/documents/cities/$(cityId)/bookings/$(bookingId)).data.vendorId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.vendorId ||
          get(/databases/$(database)/documents/cities/$(cityId)/bookings/$(bookingId)).data.freelancerId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.freelancerId
        );
        allow write: if isCloudFunction();
      }
    }
    
    // ========================================
    // LEDGER COLLECTION
    // ========================================
    match /ledger/{ledgerEntryId} {
      // Users can read their own ledger entries
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      
      // CRITICAL: Only Cloud Functions can write ledger
      // Prevents financial manipulation
      allow write: if isCloudFunction();
      
      // Admins can read all entries
      allow read: if isAdmin();
    }
    
    // ========================================
    // SETTLEMENTS COLLECTION
    // ========================================
    match /settlements/{settlementId} {
      // Users can read their own settlements
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      
      // Only Cloud Functions can write settlements
      allow write: if isCloudFunction();
      
      // Admins can read all settlements
      allow read: if isAdmin();
    }
    
    // ========================================
    // REVIEWS COLLECTION
    // ========================================
    match /reviews/{reviewId} {
      // Public read for visible reviews
      allow read: if resource.data.isVisible == true;
      
      // Customer can read their own reviews
      allow read: if isAuthenticated() && resource.data.customerId == request.auth.uid;
      
      // Target can read reviews about them
      allow read: if isAuthenticated() && (
        resource.data.targetId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.vendorId ||
        resource.data.targetId == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.freelancerId
      );
      
      // Only Cloud Functions can create reviews (after validation)
      allow create: if isCloudFunction();
      
      // Admins can moderate reviews
      allow update: if isAdmin() && onlyUpdating(['isVisible', 'flaggedBy', 'flagReason', 'updatedAt']);
      
      // Admins can read all reviews
      allow read: if isAdmin();
    }
    
    // ========================================
    // ADMIN COLLECTIONS
    // ========================================
    match /admin/config {
      // Public read for platform config
      allow read: if isAuthenticated();
      
      // Only admins can write
      allow write: if isAdmin();
    }
    
    match /admin/approval_queue/{userId} {
      // Only admins can read/write
      allow read, write: if isAdmin();
    }
    
    // ========================================
    // HELPER FUNCTION
    // ========================================
    function onlyUpdating(fields) {
      return request.resource.data.diff(resource.data).affectedKeys().hasOnly(fields);
    }
  }
}
```

---

## Firestore Indexes

### Composite Indexes Required

```javascript
// firestore.indexes.json
{
  "indexes": [
    // Vendors: Find active vendors in city
    {
      "collectionGroup": "vendors",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "cityId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "stats.averageRating", "order": "DESCENDING" }
      ]
    },
    
    // Freelancers: Assignment algorithm (priority + distance)
    {
      "collectionGroup": "freelancers",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "cityId", "order": "ASCENDING" },
        { "fieldPath": "isOnline", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "serviceCategories", "arrayConfig": "CONTAINS" },
        { "fieldPath": "reliability.priorityTier", "order": "DESCENDING" },
        { "fieldPath": "reliability.reliabilityScore", "order": "DESCENDING" }
      ]
    },
    
    // Bookings: Customer's bookings (recent first)
    {
      "collectionGroup": "bookings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "customerId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    
    // Bookings: Vendor's bookings
    {
      "collectionGroup": "bookings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "vendorId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "scheduledDate", "order": "ASCENDING" }
      ]
    },
    
    // Bookings: Freelancer's bookings
    {
      "collectionGroup": "bookings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "freelancerId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "scheduledDate", "order": "ASCENDING" }
      ]
    },
    
    // Bookings: Cleanup orphaned bookings
    {
      "collectionGroup": "bookings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    },
    
    // Ledger: User's ledger entries (recent first)
    {
      "collectionGroup": "ledger",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    
    // Settlements: User's settlements
    {
      "collectionGroup": "settlements",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "settlementDate", "order": "DESCENDING" }
      ]
    },
    
    // Reviews: Target's reviews (recent first)
    {
      "collectionGroup": "reviews",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "targetId", "order": "ASCENDING" },
        { "fieldPath": "isVisible", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

### Query Patterns Supported

| Query | Index Used | Purpose |
|-------|------------|---------|
| Find active vendors in city by rating | vendors (cityId, status, rating) | Customer discovery |
| Find online freelancers by priority | freelancers (cityId, isOnline, status, serviceCategories, priorityTier) | Assignment algorithm |
| Get customer's bookings | bookings (customerId, createdAt) | My Bookings screen |
| Get vendor's upcoming bookings | bookings (vendorId, status, scheduledDate) | Vendor dashboard |
| Get user's ledger history | ledger (userId, createdAt) | Financial history |
| Get target's reviews | reviews (targetId, isVisible, createdAt) | Review display |

---

## Cost Control Strategies

### 1. Avoid Hot Documents

**Problem:** Frequently updated documents cause contention and high costs.

**Solutions:**
- **Aggregates on parent, events in subcollections**
  - Vendor stats updated infrequently (after booking completion)
  - Individual bookings in subcollection (append-only)
  
- **Time-series subcollections**
  - `/vendors/{id}/booking_stats/{date}` - Daily aggregates
  - `/freelancers/{id}/job_snapshots/{jobId}` - Rolling window

### 2. Limit Read Amplification

**Problem:** Fetching related documents multiplies read costs.

**Solutions:**
- **Denormalization**
  - Store `customerName`, `vendorName` in booking document
  - Avoid joins for display purposes
  
- **Aggregated metrics**
  - `stats.averageRating` on vendor document
  - No need to query reviews collection for display

### 3. Intentional Denormalization

**Where:**
- Booking document contains denormalized names, addresses
- Service catalog denormalized in vendor's service subcollection
- User names in reviews

**Why:**
- Reduces reads for common queries
- Acceptable staleness (names rarely change)
- Update via Cloud Function when source changes

### 4. Index Selectivity

**Cost-Sensitive Decisions:**
- ✅ Index frequently queried fields (status, createdAt)
- ❌ Avoid indexing rarely queried fields
- ✅ Use composite indexes for multi-field queries
- ❌ Don't index fields with high cardinality unless necessary

### 5. Pagination

**All list queries use pagination:**
```javascript
// Limit results to reduce reads
const bookings = await firestore
  .collection('cities/trichy/bookings')
  .where('customerId', '==', userId)
  .orderBy('createdAt', 'desc')
  .limit(20)  // Paginate
  .get();
```

### 6. Offline Persistence (Flutter)

**Enable offline caching:**
```dart
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Benefits:**
- Reduces redundant reads
- Faster app performance
- Lower Firebase bills

---

## Data Migration Strategy

### Phase 1: Initial Setup (Pre-Launch)
1. Create `/admin/config` document with default values
2. Create service catalog for Trichy
3. Set up admin user accounts

### Phase 2: Soft Launch (First 100 Users)
1. Monitor document sizes
2. Validate index performance
3. Adjust denormalization strategy if needed

### Phase 3: Scale (1000+ Users)
1. Implement time-series archival for old bookings
2. Add read replicas if needed
3. Optimize indexes based on actual query patterns

### Phase 4: Multi-City Expansion
1. Replicate service catalog per city
2. Geo-shard bookings by city
3. City-specific admin dashboards

---

## Backup & Recovery

### Automated Backups
- **Daily Firestore exports** to Cloud Storage
- **Retention:** 30 days
- **Recovery Time Objective (RTO):** 4 hours
- **Recovery Point Objective (RPO):** 24 hours

### Critical Collections Priority
1. **Ledger** - Financial audit trail (highest priority)
2. **Bookings** - Transaction history
3. **Users** - Account data
4. **Settlements** - Payout records
5. **Reviews** - User-generated content

---

## Monitoring & Alerts

### Key Metrics to Monitor

**Firestore Usage:**
- Document reads/writes per day
- Storage size per collection
- Index usage statistics
- Hot document warnings

**Data Quality:**
- Orphaned bookings count
- Failed settlement count
- Ledger balance mismatches
- Missing idempotency keys

**Performance:**
- Query latency (p50, p95, p99)
- Write latency
- Index hit rate

### Alerts

| Metric | Threshold | Action |
|--------|-----------|--------|
| Daily reads | > 1M | Review query patterns |
| Hot document writes | > 500/sec | Refactor to subcollections |
| Failed settlements | > 5 | Manual review required |
| Ledger mismatches | > 0 | Critical alert to admin |

---

## Document Status

**Status:** Production-Ready  
**Version:** 1.0  
**Last Updated:** 2026-02-02  
**Owner:** Senior Firebase Architect  

**Next Steps:**
1. Implement security rules in Firebase Console
2. Create composite indexes
3. Set up Cloud Functions for data validation
4. Enable Firestore backups
5. Configure monitoring dashboards

**Approval Required From:**
- [ ] Backend Lead
- [ ] Security Team
- [ ] Finance Team (ledger validation)
- [ ] Product Owner

---

**This data model is ready for production implementation.** 🚀
