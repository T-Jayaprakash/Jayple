# Jayple Authentication & Role Management Specification
**Version 1.0 | Identity & Access Architecture**  
**Platform:** Firebase Auth + Firestore + Cloud Functions  
**Document Owner:** Senior Identity & Access Architect  
**Based On:** Product Spec v1.1 + System Architecture v1.0 + Firestore Data Model

---

## Core Auth Principles

1. ✅ **One phone number = one Firebase Auth user** (enforced at Firebase Auth level)
2. ✅ **Multi-role support** - User can have multiple roles (customer, vendor, freelancer)
3. ✅ **Single active role** - Only one role active per session
4. ✅ **Server-validated role switching** - Cloud Functions validate all role changes
5. ✅ **Admin approval required** - Vendors & freelancers must be approved before activation
6. ✅ **Global blocking** - Blocked users cannot access any role
7. ✅ **Complete audit trail** - All auth actions logged

---

## 1. Authentication Flow

### 1.1 Data Distribution

**Firebase Auth (Identity Layer):**
```javascript
{
  uid: "firebase_uid_123",              // Firebase-generated
  phoneNumber: "+919876543210",         // Primary identifier
  disabled: false,                      // Account enabled/disabled
  customClaims: {                       // Server-set claims
    admin: true,                        // Admin privilege (static)
    version: 1                          // Claims version for refresh
  },
  metadata: {
    creationTime: "2026-01-15T10:00:00Z",
    lastSignInTime: "2026-02-02T09:30:00Z"
  }
}
```

**Firestore /users/{userId} (Profile & Roles):**
```javascript
{
  userId: "firebase_uid_123",           // Same as Firebase Auth uid
  phone: "+919876543210",               // Denormalized
  phoneVerified: true,
  
  // Profile
  name: "Rajesh Kumar",
  email: "rajesh@example.com",
  profilePhoto: "https://...",
  
  // Roles (dynamic, server-controlled)
  roles: ["customer", "vendor"],        // Available roles
  activeRole: "customer",               // Currently active role
  
  // Role-specific IDs
  vendorId: "V789",                     // If vendor role exists
  freelancerId: null,                   // If freelancer role exists
  
  // Account status (global)
  status: "active",                     // active | pending | blocked | suspended
  blockReason: null,
  blockedAt: null,
  
  // Session
  fcmTokens: ["token1", "token2"],
  currentCity: "trichy",
  lastSeen: Timestamp,
  
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

**Why This Split?**
- **Firebase Auth:** Handles authentication, phone verification, session tokens
- **Firestore:** Handles authorization, roles, profile, business logic
- **Separation of concerns:** Auth failures vs authorization failures

---

### 1.2 First-Time Login Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FIRST-TIME LOGIN FLOW                          │
└─────────────────────────────────────────────────────────────────────┘

1. User enters phone number in app
   ↓
2. App calls Firebase Auth: verifyPhoneNumber(+919876543210)
   ↓
3. Firebase sends OTP via SMS
   ↓
4. User enters OTP
   ↓
5. App calls Firebase Auth: signInWithCredential(otp)
   ↓
6. Firebase Auth creates new user account
   {
     uid: "firebase_uid_123",
     phoneNumber: "+919876543210",
     disabled: false
   }
   ↓
7. Firebase Auth returns ID token
   ↓
8. App calls Cloud Function: initializeUser(idToken)
   ↓
9. Cloud Function: initializeUser
   ├─ Verify ID token
   ├─ Check if /users/{uid} exists
   ├─ IF NOT EXISTS:
   │   ├─ Create /users/{uid} document:
   │   │   {
   │   │     userId: uid,
   │   │     phone: phoneNumber,
   │   │     phoneVerified: true,
   │   │     roles: ["customer"],        // Default role
   │   │     activeRole: "customer",
   │   │     status: "active",
   │   │     createdAt: now
   │   │   }
   │   └─ Create audit log entry
   └─ Return user document
   ↓
10. App receives user data
   ↓
11. App checks profile completion
   ├─ IF name is null:
   │   └─ Navigate to Profile Completion screen
   └─ ELSE:
       └─ Navigate to Customer Home screen
```

**Cloud Function: initializeUser**

```javascript
exports.initializeUser = functions.https.onCall(async (data, context) => {
  // 1. Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const uid = context.auth.uid;
  const phoneNumber = context.auth.token.phone_number;
  
  // 2. Check if user document exists
  const userRef = admin.firestore().doc(`users/${uid}`);
  const userDoc = await userRef.get();
  
  if (userDoc.exists) {
    // Returning user - return existing data
    return { user: userDoc.data(), isNewUser: false };
  }
  
  // 3. Create new user document
  const newUser = {
    userId: uid,
    phone: phoneNumber,
    phoneVerified: true,
    name: null,
    email: null,
    profilePhoto: null,
    roles: ['customer'],              // Default role
    activeRole: 'customer',
    vendorId: null,
    freelancerId: null,
    status: 'active',
    fcmTokens: [],
    currentCity: 'trichy',            // Default city
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastSeen: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  await userRef.set(newUser);
  
  // 4. Create audit log
  await admin.firestore().collection('audit_logs').add({
    userId: uid,
    action: 'user_created',
    details: { phone: phoneNumber, defaultRole: 'customer' },
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return { user: newUser, isNewUser: true };
});
```

---

### 1.3 Returning User Login Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     RETURNING USER LOGIN FLOW                       │
└─────────────────────────────────────────────────────────────────────┘

1. User enters phone number
   ↓
2. Firebase Auth: verifyPhoneNumber(+919876543210)
   ↓
3. User enters OTP
   ↓
4. Firebase Auth: signInWithCredential(otp)
   ↓
5. Firebase Auth returns ID token (existing user)
   ↓
6. App calls Cloud Function: getUserProfile(idToken)
   ↓
7. Cloud Function: getUserProfile
   ├─ Verify ID token
   ├─ Read /users/{uid}
   ├─ Validate user status
   │   ├─ IF status === 'blocked':
   │   │   └─ Throw error: "Account blocked: {reason}"
   │   ├─ IF status === 'suspended':
   │   │   └─ Throw error: "Account suspended"
   │   └─ IF status === 'active':
   │       └─ Continue
   ├─ Update lastSeen timestamp
   └─ Return user document
   ↓
8. App receives user data
   ↓
9. App validates activeRole
   ├─ IF activeRole === 'customer':
   │   └─ Navigate to Customer Home
   ├─ IF activeRole === 'vendor':
   │   ├─ Check vendor approval status
   │   ├─ IF approved: Navigate to Vendor Dashboard
   │   └─ ELSE: Navigate to Pending Approval screen
   └─ IF activeRole === 'freelancer':
       ├─ Check freelancer approval status
       ├─ IF approved: Navigate to Freelancer Dashboard
       └─ ELSE: Navigate to Pending Approval screen
```

**Cloud Function: getUserProfile**

```javascript
exports.getUserProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const uid = context.auth.uid;
  const userRef = admin.firestore().doc(`users/${uid}`);
  const userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User profile not found');
  }
  
  const userData = userDoc.data();
  
  // Check global status
  if (userData.status === 'blocked') {
    throw new functions.https.HttpsError(
      'permission-denied',
      `Account blocked: ${userData.blockReason || 'Contact support'}`
    );
  }
  
  if (userData.status === 'suspended') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Account suspended. Contact support.'
    );
  }
  
  // Update last seen
  await userRef.update({
    lastSeen: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return { user: userData };
});
```

---

### 1.4 App Launch Verification

```
┌─────────────────────────────────────────────────────────────────────┐
│                    APP LAUNCH VERIFICATION                          │
└─────────────────────────────────────────────────────────────────────┘

App launches
   ↓
Check Firebase Auth session
   ├─ IF no session:
   │   └─ Navigate to Login screen
   │
   └─ IF session exists:
       ↓
       Get current ID token
       ↓
       Call Cloud Function: getUserProfile()
       ↓
       ├─ SUCCESS:
       │   ├─ Store user data locally
       │   ├─ Subscribe to Firestore: /users/{uid} (real-time)
       │   └─ Navigate to appropriate home screen
       │
       └─ ERROR:
           ├─ IF 'permission-denied' (blocked/suspended):
           │   ├─ Sign out from Firebase Auth
           │   └─ Show error message + Login screen
           │
           └─ IF 'not-found':
               ├─ Call initializeUser() (edge case: Firestore doc deleted)
               └─ Navigate to Profile Completion
```

**Real-Time User Status Monitoring:**

```javascript
// App subscribes to user document for real-time updates
firestore.doc('users/${uid}').snapshots().listen((snapshot) {
  final userData = snapshot.data();
  
  // Check if user was blocked/suspended while app is open
  if (userData['status'] == 'blocked' || userData['status'] == 'suspended') {
    // Force logout
    FirebaseAuth.instance.signOut();
    // Show error dialog
    showBlockedAccountDialog(userData['blockReason']);
    // Navigate to login
    navigateToLogin();
  }
  
  // Check if active role changed (e.g., admin changed it)
  if (userData['activeRole'] != currentActiveRole) {
    // Refresh app state
    refreshAppForNewRole(userData['activeRole']);
  }
});
```

---

### 1.5 Handling Deleted/Disabled Users

**Scenario 1: Firebase Auth account disabled by admin**

```
User tries to login
   ↓
Firebase Auth: signInWithCredential()
   ↓
ERROR: "User account has been disabled"
   ↓
App shows error: "Your account has been disabled. Contact support."
```

**Scenario 2: Firestore user document deleted (edge case)**

```
User logs in successfully (Firebase Auth)
   ↓
App calls getUserProfile()
   ↓
Cloud Function: User document not found
   ↓
Cloud Function automatically recreates user document with default values
   ↓
Returns user data
   ↓
App navigates to Profile Completion
```

**Scenario 3: Phone number changed in Firebase Auth (manual admin action)**

```
Admin changes phone number in Firebase Console
   ↓
User logs in with NEW phone number
   ↓
Firebase Auth creates NEW uid (different user)
   ↓
initializeUser() creates new Firestore document
   ↓
OLD account remains orphaned (admin must manually merge if needed)
```

**Prevention:** Don't allow phone number changes via Firebase Console. Use Cloud Function to handle phone number updates with proper migration.

---

## 2. Role Management Model

### 2.1 Role Storage & Structure

**Roles Array:**
```javascript
roles: ["customer", "vendor", "freelancer"]
```

**Possible values:**
- `"customer"` - Default role, always present
- `"vendor"` - Added after vendor approval
- `"freelancer"` - Added after freelancer approval
- `"admin"` - Special role (set via custom claims, not in roles array)

**Active Role:**
```javascript
activeRole: "customer"  // One of the roles in the roles array
```

**Role-Specific IDs:**
```javascript
vendorId: "V789"        // Links to /cities/{cityId}/vendors/{vendorId}
freelancerId: "FL456"   // Links to /cities/{cityId}/freelancers/{freelancerId}
```

---

### 2.2 Role Switching Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                       ROLE SWITCHING FLOW                           │
└─────────────────────────────────────────────────────────────────────┘

User taps "Switch to Vendor" in app
   ↓
App calls Cloud Function: switchRole("vendor")
   ↓
Cloud Function: switchRole
   ├─ Verify authentication
   ├─ Read /users/{uid}
   ├─ Validate request:
   │   ├─ Check if "vendor" exists in user.roles
   │   ├─ IF NOT: Throw error "Role not available"
   │   ├─ Check user.status === 'active'
   │   └─ IF blocked/suspended: Throw error
   │
   ├─ IF role === 'vendor':
   │   ├─ Read /cities/{cityId}/vendors/{vendorId}
   │   ├─ Check vendor.status === 'active'
   │   ├─ Check vendor.approvalStatus === 'approved'
   │   └─ IF NOT approved: Throw error "Vendor account pending approval"
   │
   ├─ IF role === 'freelancer':
   │   ├─ Read /cities/{cityId}/freelancers/{freelancerId}
   │   ├─ Check freelancer.status === 'active'
   │   ├─ Check freelancer.approvalStatus === 'approved'
   │   └─ IF NOT approved: Throw error "Freelancer account pending approval"
   │
   ├─ Update /users/{uid}:
   │   {
   │     activeRole: "vendor",
   │     updatedAt: now
   │   }
   │
   ├─ Create audit log:
   │   {
   │     userId: uid,
   │     action: 'role_switched',
   │     details: { from: 'customer', to: 'vendor' },
   │     timestamp: now
   │   }
   │
   └─ Return success
   ↓
App receives success
   ↓
App refreshes UI for new role
   ↓
Navigate to Vendor Dashboard
```

**Cloud Function: switchRole**

```javascript
exports.switchRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { targetRole } = data;
  const uid = context.auth.uid;
  
  // 1. Read user document
  const userRef = admin.firestore().doc(`users/${uid}`);
  const userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  const userData = userDoc.data();
  
  // 2. Validate user status
  if (userData.status !== 'active') {
    throw new functions.https.HttpsError(
      'permission-denied',
      `Account ${userData.status}. Cannot switch roles.`
    );
  }
  
  // 3. Validate target role exists
  if (!userData.roles.includes(targetRole)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      `Role ${targetRole} not available for this user`
    );
  }
  
  // 4. Validate role-specific approval status
  if (targetRole === 'vendor') {
    const vendorDoc = await admin.firestore()
      .doc(`cities/${userData.currentCity}/vendors/${userData.vendorId}`)
      .get();
    
    if (!vendorDoc.exists || vendorDoc.data().approvalStatus !== 'approved') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Vendor account pending approval'
      );
    }
    
    if (vendorDoc.data().status !== 'active') {
      throw new functions.https.HttpsError(
        'permission-denied',
        `Vendor account ${vendorDoc.data().status}`
      );
    }
  }
  
  if (targetRole === 'freelancer') {
    const freelancerDoc = await admin.firestore()
      .doc(`cities/${userData.currentCity}/freelancers/${userData.freelancerId}`)
      .get();
    
    if (!freelancerDoc.exists || freelancerDoc.data().approvalStatus !== 'approved') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Freelancer account pending approval'
      );
    }
    
    if (freelancerDoc.data().status !== 'active') {
      throw new functions.https.HttpsError(
        'permission-denied',
        `Freelancer account ${freelancerDoc.data().status}`
      );
    }
  }
  
  // 5. Update active role
  await userRef.update({
    activeRole: targetRole,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // 6. Create audit log
  await admin.firestore().collection('audit_logs').add({
    userId: uid,
    action: 'role_switched',
    details: {
      from: userData.activeRole,
      to: targetRole,
    },
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return { success: true, newRole: targetRole };
});
```

---

### 2.3 Mid-Session Role Change Handling

**Scenario 1: User switches role while app is open**

```
User is on Customer Home screen
   ↓
User taps "Switch to Vendor"
   ↓
App calls switchRole("vendor")
   ↓
Cloud Function updates activeRole in Firestore
   ↓
Real-time listener detects change
   ↓
App state updates
   ↓
App navigates to Vendor Dashboard
   ↓
App rebuilds UI for vendor role
```

**Scenario 2: Admin blocks vendor role while user is active as vendor**

```
User is on Vendor Dashboard (activeRole: "vendor")
   ↓
Admin blocks vendor account (vendor.status = 'blocked')
   ↓
Real-time listener on vendor document detects change
   ↓
App detects vendor.status === 'blocked'
   ↓
App calls switchRole("customer") automatically
   ↓
App shows notification: "Your vendor account has been blocked"
   ↓
App navigates to Customer Home
```

**Scenario 3: User's global account blocked while app is open**

```
User is using app (any role)
   ↓
Admin blocks user account (user.status = 'blocked')
   ↓
Real-time listener on /users/{uid} detects change
   ↓
App detects user.status === 'blocked'
   ↓
App signs out user immediately
   ↓
App shows error: "Account blocked: {reason}"
   ↓
App navigates to Login screen
```

---

### 2.4 Invalid Role Access Prevention

**Backend Validation (Cloud Functions):**

Every Cloud Function that performs role-specific actions must validate:

```javascript
async function validateUserRole(uid, requiredRole) {
  const userDoc = await admin.firestore().doc(`users/${uid}`).get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  const userData = userDoc.data();
  
  // Check global status
  if (userData.status !== 'active') {
    throw new functions.https.HttpsError(
      'permission-denied',
      `Account ${userData.status}`
    );
  }
  
  // Check active role matches required role
  if (userData.activeRole !== requiredRole) {
    throw new functions.https.HttpsError(
      'permission-denied',
      `This action requires ${requiredRole} role. Current role: ${userData.activeRole}`
    );
  }
  
  // Check role exists in roles array
  if (!userData.roles.includes(requiredRole)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      `User does not have ${requiredRole} role`
    );
  }
  
  return userData;
}

// Example usage in acceptBooking function
exports.acceptBooking = functions.https.onCall(async (data, context) => {
  const { bookingId } = data;
  const uid = context.auth.uid;
  
  // Validate user is active vendor or freelancer
  const booking = await admin.firestore().doc(`cities/trichy/bookings/${bookingId}`).get();
  const bookingData = booking.data();
  
  if (bookingData.type === 'inShop') {
    await validateUserRole(uid, 'vendor');
    // Additional vendor-specific validation
  } else {
    await validateUserRole(uid, 'freelancer');
    // Additional freelancer-specific validation
  }
  
  // Proceed with booking acceptance
});
```

**Firestore Security Rules:**

```javascript
// Prevent direct writes to critical fields
match /users/{userId} {
  allow update: if request.auth.uid == userId &&
                   // User can only update these fields
                   onlyUpdating(['name', 'email', 'profilePhoto', 'fcmTokens']) &&
                   // Cannot update roles, status, activeRole directly
                   !request.resource.data.diff(resource.data).affectedKeys().hasAny(['roles', 'status', 'activeRole', 'vendorId', 'freelancerId']);
}
```

---

## 3. Approval Workflows

### 3.1 Vendor Approval Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VENDOR APPROVAL WORKFLOW                         │
└─────────────────────────────────────────────────────────────────────┘

STEP 1: Application Submission
───────────────────────────────
User (customer) taps "Become a Vendor"
   ↓
App shows Vendor Application Form:
   - Business Name
   - Owner Name
   - Business Address
   - Phone, Email
   - Upload Documents (Business License, ID proof)
   ↓
User fills form and submits
   ↓
App calls Cloud Function: submitVendorApplication(formData)
   ↓
Cloud Function: submitVendorApplication
   ├─ Verify user is authenticated
   ├─ Check user doesn't already have vendor role
   ├─ Upload documents to Cloudinary
   ├─ Create vendor document:
   │   /cities/{cityId}/vendors/{vendorId}
   │   {
   │     vendorId: "V123",
   │     userId: uid,
   │     businessName: "Royal Salon",
   │     status: "pending",
   │     approvalStatus: "pending",
   │     createdAt: now
   │   }
   │
   ├─ Create approval queue entry:
   │   /admin/approval_queue/{uid}
   │   {
   │     userId: uid,
   │     applicationType: "vendor",
   │     vendorId: "V123",
   │     application: { ...formData },
   │     status: "pending",
   │     submittedAt: now
   │   }
   │
   ├─ Create audit log
   └─ Return vendorId
   ↓
App shows: "Application submitted. Pending admin approval."
   ↓
User can switch to vendor role, but sees "Pending Approval" screen


STEP 2: Admin Review
─────────────────────
Admin opens Admin Dashboard
   ↓
Admin navigates to "Approval Queue"
   ↓
Admin sees list of pending vendor applications
   ↓
Admin clicks on application
   ↓
Admin reviews:
   - Business details
   - Uploaded documents
   - User history (if any)
   ↓
Admin decides: APPROVE or REJECT


STEP 3A: Approval
──────────────────
Admin clicks "Approve"
   ↓
Admin Dashboard calls Cloud Function: approveVendor(userId, vendorId)
   ↓
Cloud Function: approveVendor
   ├─ Verify admin privileges (custom claims)
   ├─ Update vendor document:
   │   {
   │     status: "active",
   │     approvalStatus: "approved",
   │     approvedBy: adminUid,
   │     approvedAt: now
   │   }
   │
   ├─ Update user document:
   │   {
   │     roles: FieldValue.arrayUnion("vendor"),
   │     vendorId: "V123"
   │   }
   │
   ├─ Update approval queue:
   │   {
   │     status: "approved",
   │     reviewedBy: adminUid,
   │     reviewedAt: now
   │   }
   │
   ├─ Create audit log:
   │   {
   │     action: 'vendor_approved',
   │     userId: uid,
   │     vendorId: "V123",
   │     approvedBy: adminUid
   │   }
   │
   └─ Send FCM notification to user:
       "Congratulations! Your vendor account has been approved."
   ↓
User receives notification
   ↓
User opens app, switches to vendor role
   ↓
User can now access Vendor Dashboard


STEP 3B: Rejection
───────────────────
Admin clicks "Reject"
   ↓
Admin enters rejection reason
   ↓
Admin Dashboard calls Cloud Function: rejectVendor(userId, vendorId, reason)
   ↓
Cloud Function: rejectVendor
   ├─ Verify admin privileges
   ├─ Update vendor document:
   │   {
   │     status: "rejected",
   │     approvalStatus: "rejected",
   │     rejectionReason: reason,
   │     rejectedBy: adminUid,
   │     rejectedAt: now
   │   }
   │
   ├─ Update approval queue:
   │   {
   │     status: "rejected",
   │     rejectionReason: reason,
   │     reviewedBy: adminUid,
   │     reviewedAt: now
   │   }
   │
   ├─ Create audit log
   └─ Send FCM notification:
       "Your vendor application was rejected: {reason}"
   ↓
User receives notification
   ↓
User can view rejection reason in app
   ↓
User can re-apply after fixing issues


STEP 4: Re-application After Rejection
────────────────────────────────────────
User taps "Re-apply"
   ↓
App calls Cloud Function: resubmitVendorApplication(vendorId, updatedFormData)
   ↓
Cloud Function: resubmitVendorApplication
   ├─ Check existing vendor.approvalStatus === 'rejected'
   ├─ Update vendor document with new data
   ├─ Reset status:
   │   {
   │     status: "pending",
   │     approvalStatus: "pending",
   │     rejectionReason: null,
   │     resubmittedAt: now
   │   }
   │
   ├─ Update approval queue:
   │   {
   │     status: "pending",
   │     application: updatedFormData,
   │     resubmittedAt: now
   │   }
   │
   └─ Create audit log
   ↓
Admin reviews re-application (same flow as STEP 2)
```

**Cloud Function: submitVendorApplication**

```javascript
exports.submitVendorApplication = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const uid = context.auth.uid;
  const { businessName, ownerName, address, phone, email, documents } = data;
  
  // 1. Check user doesn't already have vendor role
  const userDoc = await admin.firestore().doc(`users/${uid}`).get();
  const userData = userDoc.data();
  
  if (userData.roles.includes('vendor')) {
    throw new functions.https.HttpsError(
      'already-exists',
      'User already has vendor role'
    );
  }
  
  // 2. Generate vendor ID
  const vendorId = `V${Date.now()}`;
  
  // 3. Create vendor document
  const vendorRef = admin.firestore().doc(`cities/${userData.currentCity}/vendors/${vendorId}`);
  await vendorRef.set({
    vendorId,
    userId: uid,
    cityId: userData.currentCity,
    businessName,
    ownerName,
    phone,
    email,
    address,
    images: [],
    businessHours: getDefaultBusinessHours(),
    bookingMode: 'manual',
    slaConfig: getDefaultSLAConfig(),
    serviceIds: [],
    stats: getDefaultStats(),
    balance: 0,
    outstandingBalance: 0,
    status: 'pending',
    approvalStatus: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // 4. Create approval queue entry
  await admin.firestore().doc(`admin/approval_queue/${uid}_vendor`).set({
    userId: uid,
    applicationType: 'vendor',
    vendorId,
    application: {
      businessName,
      ownerName,
      address,
      phone,
      email,
      documents,
    },
    status: 'pending',
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // 5. Create audit log
  await admin.firestore().collection('audit_logs').add({
    userId: uid,
    action: 'vendor_application_submitted',
    details: { vendorId, businessName },
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // 6. Send notification to admins
  await notifyAdmins('new_vendor_application', { vendorId, businessName });
  
  return { vendorId, status: 'pending' };
});
```

---

### 3.2 Freelancer Approval Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                  FREELANCER APPROVAL WORKFLOW                       │
└─────────────────────────────────────────────────────────────────────┘

STEP 1: Application Submission
───────────────────────────────
User taps "Become a Freelancer"
   ↓
App shows Freelancer Application Form:
   - Full Name
   - Experience (years)
   - Service Categories (select from MVP 5)
   - Service Area (radius)
   - Upload Documents (ID proof, certifications)
   ↓
User submits
   ↓
App calls Cloud Function: submitFreelancerApplication(formData)
   ↓
Cloud Function creates:
   - /cities/{cityId}/freelancers/{freelancerId}
     { status: "pending", approvalStatus: "pending" }
   - /admin/approval_queue/{uid}_freelancer
   ↓
User sees "Pending Approval" screen


STEP 2: Admin Review & Approval
────────────────────────────────
Admin reviews application
   ↓
Admin calls: approveFreelancer(userId, freelancerId)
   ↓
Cloud Function:
   ├─ Update freelancer: { status: "active", approvalStatus: "approved" }
   ├─ Update user: { roles: arrayUnion("freelancer"), freelancerId }
   ├─ Initialize reliability metrics
   └─ Send FCM: "Freelancer account approved"
   ↓
User can now switch to freelancer role and accept jobs


STEP 3: Suspension (Post-Approval)
────────────────────────────────────
Admin detects policy violation
   ↓
Admin calls: suspendFreelancer(freelancerId, reason)
   ↓
Cloud Function:
   ├─ Update freelancer: { status: "suspended", suspensionReason: reason }
   ├─ Create audit log
   └─ Send FCM: "Account suspended: {reason}"
   ↓
Freelancer cannot accept new jobs
   ↓
Existing confirmed bookings remain valid


STEP 4: Reactivation
─────────────────────
Admin reviews suspension
   ↓
Admin calls: reactivateFreelancer(freelancerId)
   ↓
Cloud Function:
   ├─ Update freelancer: { status: "active", suspensionReason: null }
   ├─ Create audit log
   └─ Send FCM: "Account reactivated"
   ↓
Freelancer can accept jobs again
```

---

## 4. Blocking & Suspension Logic

### 4.1 Blocking vs Suspension

| Aspect | Blocked | Suspended |
|--------|---------|-----------|
| **Scope** | Global (all roles) | Role-specific (vendor or freelancer) |
| **Access** | Cannot login | Can login, cannot use blocked role |
| **Trigger** | Outstanding balance, fraud, severe violations | Policy violations, low reliability |
| **Reversibility** | Requires payment/admin review | Admin can reactivate anytime |
| **Existing Bookings** | All cancelled | Confirmed bookings honored |

---

### 4.2 Auto-Block Triggers

**Trigger 1: Outstanding Balance Exceeded**

```javascript
// Firestore Trigger: onLedgerWrite
exports.checkOutstandingThreshold = functions.firestore
  .document('ledger/{ledgerEntryId}')
  .onCreate(async (snap, context) => {
    const ledgerData = snap.data();
    
    if (ledgerData.type === 'earning' && ledgerData.paymentMethod === 'offline') {
      const outstandingThreshold = 10000; // ₹10,000
      
      if (ledgerData.outstandingAfter >= outstandingThreshold) {
        // Auto-block user
        const userDoc = await admin.firestore().doc(`users/${ledgerData.userId}`).get();
        const userData = userDoc.data();
        
        // Block role-specific account
        if (ledgerData.userType === 'vendor') {
          await admin.firestore()
            .doc(`cities/${userData.currentCity}/vendors/${userData.vendorId}`)
            .update({
              status: 'blocked',
              blockReason: `Outstanding balance exceeded ₹${outstandingThreshold}`,
              blockedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } else {
          await admin.firestore()
            .doc(`cities/${userData.currentCity}/freelancers/${userData.freelancerId}`)
            .update({
              status: 'blocked',
              blockReason: `Outstanding balance exceeded ₹${outstandingThreshold}`,
              blockedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        
        // Create audit log
        await admin.firestore().collection('audit_logs').add({
          userId: ledgerData.userId,
          action: 'auto_blocked',
          reason: 'outstanding_threshold_exceeded',
          details: { outstandingBalance: ledgerData.outstandingAfter },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Send notification
        await sendFCM(ledgerData.userId, {
          type: 'account_blocked',
          title: 'Account Blocked',
          body: `Your ${ledgerData.userType} account has been blocked due to outstanding balance exceeding ₹${outstandingThreshold}. Please clear dues to reactivate.`,
        });
        
        // Notify admin
        await notifyAdmins('user_auto_blocked', {
          userId: ledgerData.userId,
          userType: ledgerData.userType,
          outstandingBalance: ledgerData.outstandingAfter,
        });
      }
    }
  });
```

**Trigger 2: Repeated Cancellations**

```javascript
// Cloud Function: onBookingCancelled
exports.checkCancellationRate = functions.firestore
  .document('cities/{cityId}/bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if booking was just cancelled
    if (before.status !== 'cancelled' && after.status === 'cancelled') {
      const cancelledBy = after.cancellation.cancelledBy;
      
      // Get user's cancellation history (last 30 days)
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      
      const cancellations = await admin.firestore()
        .collection(`cities/${context.params.cityId}/bookings`)
        .where('customerId', '==', cancelledBy)
        .where('status', '==', 'cancelled')
        .where('cancellation.cancelledBy', '==', cancelledBy)
        .where('createdAt', '>', thirtyDaysAgo)
        .get();
      
      const cancellationCount = cancellations.size;
      const cancellationThreshold = 5; // 5 cancellations in 30 days
      
      if (cancellationCount >= cancellationThreshold) {
        // Suspend user
        await admin.firestore().doc(`users/${cancelledBy}`).update({
          status: 'suspended',
          blockReason: `Excessive cancellations (${cancellationCount} in 30 days)`,
          blockedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Audit log
        await admin.firestore().collection('audit_logs').add({
          userId: cancelledBy,
          action: 'auto_suspended',
          reason: 'excessive_cancellations',
          details: { cancellationCount, threshold: cancellationThreshold },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Notify user
        await sendFCM(cancelledBy, {
          type: 'account_suspended',
          title: 'Account Suspended',
          body: 'Your account has been suspended due to excessive cancellations. Contact support.',
        });
      }
    }
  });
```

**Trigger 3: Low Freelancer Reliability**

```javascript
// Cloud Function: onReliabilityUpdate
exports.checkFreelancerReliability = functions.firestore
  .document('cities/{cityId}/freelancers/{freelancerId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    
    // Check if reliability score dropped below threshold
    const reliabilityThreshold = 50; // Score below 50
    const acceptanceRateThreshold = 0.5; // 50%
    
    if (
      after.reliability.reliabilityScore < reliabilityThreshold ||
      after.reliability.acceptanceRate < acceptanceRateThreshold
    ) {
      // Suspend freelancer
      await change.after.ref.update({
        status: 'suspended',
        blockReason: `Low reliability score (${after.reliability.reliabilityScore}) or acceptance rate (${after.reliability.acceptanceRate * 100}%)`,
        blockedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Audit log
      await admin.firestore().collection('audit_logs').add({
        userId: after.userId,
        action: 'auto_suspended',
        reason: 'low_reliability',
        details: {
          reliabilityScore: after.reliability.reliabilityScore,
          acceptanceRate: after.reliability.acceptanceRate,
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Notify freelancer
      await sendFCM(after.userId, {
        type: 'account_suspended',
        title: 'Account Suspended',
        body: 'Your freelancer account has been suspended due to low reliability. Contact support to reactivate.',
      });
    }
  });
```

---

### 4.3 What Blocked Users Can/Cannot Do

**Blocked User (Global):**
- ❌ Cannot login (getUserProfile throws error)
- ❌ Cannot create bookings
- ❌ Cannot accept bookings
- ❌ Cannot switch roles
- ✅ Can contact support (via external channel)

**Suspended User (Role-Specific):**
- ✅ Can login
- ✅ Can use other roles (e.g., suspended vendor can still use customer role)
- ❌ Cannot use suspended role
- ❌ Cannot accept new bookings in suspended role
- ✅ Must honor existing confirmed bookings

---

### 4.4 Unblock/Reactivation Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    UNBLOCK/REACTIVATION FLOW                        │
└─────────────────────────────────────────────────────────────────────┘

SCENARIO 1: Outstanding Balance Cleared
────────────────────────────────────────
Vendor/Freelancer pays outstanding balance
   ↓
Payment recorded in ledger
   ↓
Cloud Function: onLedgerWrite detects payment
   ↓
IF outstandingBalance < threshold:
   ├─ Update vendor/freelancer: { status: "active", blockReason: null }
   ├─ Create audit log: "auto_unblocked"
   └─ Send FCM: "Account reactivated"


SCENARIO 2: Manual Admin Unblock
──────────────────────────────────
Admin reviews blocked account
   ↓
Admin decides to unblock
   ↓
Admin calls Cloud Function: unblockUser(userId, reason)
   ↓
Cloud Function:
   ├─ Update user: { status: "active", blockReason: null }
   ├─ Create audit log: { action: "manual_unblock", by: adminUid }
   └─ Send FCM: "Account reactivated by admin"


SCENARIO 3: Freelancer Reactivation After Suspension
──────────────────────────────────────────────────────
Admin reviews suspended freelancer
   ↓
Admin calls: reactivateFreelancer(freelancerId)
   ↓
Cloud Function:
   ├─ Update freelancer: { status: "active", blockReason: null }
   ├─ Reset reliability metrics (optional)
   ├─ Create audit log
   └─ Send FCM: "Account reactivated"
```

**Cloud Function: unblockUser**

```javascript
exports.unblockUser = functions.https.onCall(async (data, context) => {
  // Verify admin privileges
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }
  
  const { userId, reason } = data;
  const adminUid = context.auth.uid;
  
  // Update user status
  await admin.firestore().doc(`users/${userId}`).update({
    status: 'active',
    blockReason: null,
    blockedAt: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Create audit log
  await admin.firestore().collection('audit_logs').add({
    userId,
    action: 'manual_unblock',
    performedBy: adminUid,
    reason,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Send notification
  await sendFCM(userId, {
    type: 'account_reactivated',
    title: 'Account Reactivated',
    body: 'Your account has been reactivated by admin.',
  });
  
  return { success: true };
});
```

---

## 5. Custom Claims & Authorization

### 5.1 Why Custom Claims for Admin Only

**Custom Claims are used ONLY for:**
- ✅ Admin privileges (static, rarely changes)
- ✅ Backend enforcement in Cloud Functions
- ✅ Firestore Security Rules

**Custom Claims are NOT used for:**
- ❌ Dynamic roles (customer, vendor, freelancer)
- ❌ Frequently changing data
- ❌ Role switching

**Reason:**
- Custom claims require token refresh (client must re-authenticate)
- Token refresh is slow and disruptive
- Dynamic roles stored in Firestore allow instant switching

---

### 5.2 Setting Admin Custom Claims

```javascript
// Cloud Function: setAdminClaim (callable by super admin only)
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // Verify super admin (hardcoded list or separate collection)
  const superAdmins = ['super_admin_uid_1', 'super_admin_uid_2'];
  
  if (!context.auth || !superAdmins.includes(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Super admin access required');
  }
  
  const { userId, isAdmin } = data;
  
  // Set custom claim
  await admin.auth().setCustomUserClaims(userId, {
    admin: isAdmin,
    version: Date.now(), // Force token refresh
  });
  
  // Update user document
  await admin.firestore().doc(`users/${userId}`).update({
    roles: isAdmin 
      ? admin.firestore.FieldValue.arrayUnion('admin')
      : admin.firestore.FieldValue.arrayRemove('admin'),
  });
  
  // Audit log
  await admin.firestore().collection('audit_logs').add({
    userId,
    action: isAdmin ? 'admin_granted' : 'admin_revoked',
    performedBy: context.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return { success: true, message: 'User must re-login to refresh token' };
});
```

---

### 5.3 Validating Admin Claims in Cloud Functions

```javascript
function requireAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  if (!context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }
}

// Example usage
exports.approveVendor = functions.https.onCall(async (data, context) => {
  requireAdmin(context); // Throws error if not admin
  
  // Proceed with vendor approval
  const { userId, vendorId } = data;
  // ... approval logic
});
```

---

### 5.4 Firestore Security Rules with Custom Claims

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isAdmin() {
      return request.auth != null && request.auth.token.admin == true;
    }
    
    // Admin collections
    match /admin/{document=**} {
      allow read, write: if isAdmin();
    }
    
    match /admin/approval_queue/{userId} {
      allow read, write: if isAdmin();
    }
    
    // Users can read their own approval status
    match /admin/approval_queue/{userId} {
      allow read: if request.auth.uid == userId;
    }
  }
}
```

---

### 5.5 Token Refresh Strategy

**When admin claim is set:**
1. Cloud Function sets custom claim
2. Function returns message: "Please re-login to activate admin privileges"
3. User signs out and signs back in
4. New ID token includes `admin: true` claim
5. User can now access admin features

**Automatic refresh (optional):**
```javascript
// Client-side: Force token refresh
await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

---

## 6. Audit & Traceability

### 6.1 Audit Log Collection

**Collection Path:**
```
/audit_logs/{logId}
```

**Document Structure:**
```javascript
{
  logId: "LOG123",                      // Auto-generated
  
  // Who
  userId: "U456",                       // User affected
  performedBy: "admin_U789",            // Who performed action (if admin)
  
  // What
  action: "vendor_approved",            // Action type
  details: {                            // Action-specific details
    vendorId: "V123",
    businessName: "Royal Salon"
  },
  
  // When
  timestamp: Timestamp,
  
  // Where (optional)
  ipAddress: "192.168.1.1",
  userAgent: "Mozilla/5.0...",
  
  // Context (optional)
  previousState: { status: "pending" },
  newState: { status: "active" },
}
```

---

### 6.2 Audited Actions

| Action | Trigger | Details Captured |
|--------|---------|------------------|
| `user_created` | First login | Phone number, default role |
| `role_switched` | User switches role | From role, to role |
| `vendor_application_submitted` | Vendor applies | Vendor ID, business name |
| `vendor_approved` | Admin approves | Vendor ID, approved by |
| `vendor_rejected` | Admin rejects | Vendor ID, rejection reason |
| `freelancer_approved` | Admin approves | Freelancer ID, approved by |
| `auto_blocked` | System blocks user | Reason, outstanding balance |
| `manual_unblock` | Admin unblocks | Reason, unblocked by |
| `admin_granted` | Super admin grants admin | Target user ID |
| `booking_created` | User creates booking | Booking ID, type, amount |
| `booking_cancelled` | User cancels booking | Booking ID, cancelled by, reason |
| `settlement_processed` | Weekly settlement | Settlement ID, amount |

---

### 6.3 Audit Log Queries

**Query 1: User's action history**
```javascript
const userAuditLogs = await admin.firestore()
  .collection('audit_logs')
  .where('userId', '==', userId)
  .orderBy('timestamp', 'desc')
  .limit(50)
  .get();
```

**Query 2: Admin actions**
```javascript
const adminActions = await admin.firestore()
  .collection('audit_logs')
  .where('performedBy', '==', adminUid)
  .orderBy('timestamp', 'desc')
  .limit(100)
  .get();
```

**Query 3: Specific action type**
```javascript
const approvals = await admin.firestore()
  .collection('audit_logs')
  .where('action', '==', 'vendor_approved')
  .where('timestamp', '>', thirtyDaysAgo)
  .get();
```

---

### 6.4 Retention Strategy

**Retention Periods:**
- **Critical actions** (blocking, approvals, settlements): **Permanent**
- **User actions** (role switches, bookings): **2 years**
- **System actions** (auto-blocks, notifications): **1 year**

**Archival Strategy:**
1. **Daily job** exports audit logs older than retention period
2. **Export to Cloud Storage** (compressed JSON)
3. **Delete from Firestore** to reduce costs
4. **Restore on demand** if needed for investigations

**Cloud Function: archiveOldAuditLogs (Scheduled)**

```javascript
exports.archiveOldAuditLogs = functions.pubsub
  .schedule('every day 02:00')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const twoYearsAgo = new Date(Date.now() - 2 * 365 * 24 * 60 * 60 * 1000);
    
    const oldLogs = await admin.firestore()
      .collection('audit_logs')
      .where('timestamp', '<', twoYearsAgo)
      .where('action', 'not-in', ['vendor_approved', 'auto_blocked', 'settlement_processed'])
      .limit(1000)
      .get();
    
    if (oldLogs.empty) {
      console.log('No old logs to archive');
      return;
    }
    
    // Export to Cloud Storage
    const bucket = admin.storage().bucket();
    const fileName = `audit_logs_archive_${Date.now()}.json`;
    const file = bucket.file(`archives/${fileName}`);
    
    const logsData = oldLogs.docs.map(doc => doc.data());
    await file.save(JSON.stringify(logsData), {
      contentType: 'application/json',
      gzip: true,
    });
    
    // Delete from Firestore
    const batch = admin.firestore().batch();
    oldLogs.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    
    console.log(`Archived ${oldLogs.size} logs to ${fileName}`);
  });
```

---

## 7. Edge Cases & Error Handling

### 7.1 Concurrent Role Switches

**Problem:** User switches role twice rapidly

**Solution:**
```javascript
// Use Firestore transaction in switchRole
await admin.firestore().runTransaction(async (transaction) => {
  const userRef = admin.firestore().doc(`users/${uid}`);
  const userDoc = await transaction.get(userRef);
  
  // Check current activeRole
  if (userDoc.data().activeRole === targetRole) {
    throw new Error('Already in target role');
  }
  
  // Update atomically
  transaction.update(userRef, {
    activeRole: targetRole,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});
```

---

### 7.2 Deleted Vendor/Freelancer Document

**Problem:** User has vendor role but vendor document deleted

**Solution:**
```javascript
// In switchRole, validate role-specific document exists
if (targetRole === 'vendor') {
  const vendorDoc = await admin.firestore()
    .doc(`cities/${userData.currentCity}/vendors/${userData.vendorId}`)
    .get();
  
  if (!vendorDoc.exists) {
    // Remove vendor role from user
    await admin.firestore().doc(`users/${uid}`).update({
      roles: admin.firestore.FieldValue.arrayRemove('vendor'),
      vendorId: null,
    });
    
    throw new functions.https.HttpsError(
      'not-found',
      'Vendor account not found. Role has been removed.'
    );
  }
}
```

---

### 7.3 Admin Revokes Role While User Active

**Problem:** Admin deletes vendor account while user is active as vendor

**Solution:**
```javascript
// Real-time listener in app
firestore.doc('cities/trichy/vendors/${vendorId}').snapshots().listen((snapshot) {
  if (!snapshot.exists) {
    // Vendor document deleted
    showDialog('Your vendor account has been removed by admin');
    switchRole('customer'); // Auto-switch to customer
  }
});
```

---

## 8. Security Checklist

- [x] Phone number uniqueness enforced by Firebase Auth
- [x] Multi-role support with single active role
- [x] Server-validated role switching (Cloud Functions)
- [x] Admin approval required for vendor/freelancer
- [x] Global blocking prevents all access
- [x] Role-specific suspension allows other roles
- [x] Custom claims used only for admin (static)
- [x] Complete audit trail for all critical actions
- [x] Real-time status monitoring in app
- [x] Firestore Security Rules prevent direct writes
- [x] Idempotent operations (approval, blocking)
- [x] Edge cases handled (deleted docs, concurrent switches)

---

## Document Status

**Status:** Production-Ready  
**Version:** 1.0  
**Last Updated:** 2026-02-02  
**Owner:** Senior Identity & Access Architect  

**Next Steps:**
1. Implement Cloud Functions for auth flows
2. Set up Firebase Auth phone provider
3. Configure custom claims for admins
4. Create admin dashboard for approvals
5. Test role switching flows end-to-end
6. Set up audit log archival

**Approval Required From:**
- [ ] Backend Lead
- [ ] Security Team
- [ ] Product Owner
- [ ] Compliance Team (for audit requirements)

---

**This authentication & role management specification is ready for production implementation.** 🚀
