/**
 * Jayple Cloud Functions
 * 
 * Runtime: Node.js 18
 * Plan: Spark (Free)
 * Project: jayple-app-2026
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getFunctions } = require('firebase-admin/functions');

// Initialize Firebase Admin
admin.initializeApp({
    projectId: 'jayple-app-2026',
    serviceAccountId: 'firebase-adminsdk-fake@jayple-app-2026.iam.gserviceaccount.com'
});

const db = admin.firestore();

// ============================================
// HELPER: Require Authentication
function requireAuth(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'User must be authenticated to call this function.'
        );
    }
    return context.auth.uid;
}

// ============================================
// HELPER: Validate Input
// ============================================
function validateBookingInput(data) {
    const errors = [];

    // Validate type
    if (!data.type) {
        errors.push('type is required');
    } else if (!['inShop', 'home'].includes(data.type)) {
        errors.push('type must be either "inShop" or "home"');
    }

    // Validate cityId
    if (!data.cityId || typeof data.cityId !== 'string') {
        errors.push('cityId is required and must be a string');
    }

    // Validate serviceId
    if (!data.serviceId || typeof data.serviceId !== 'string') {
        errors.push('serviceId is required and must be a string');
    }

    // Validate scheduledAt
    if (!data.scheduledAt) {
        errors.push('scheduledAt is required');
    }

    // Validate idempotencyKey (optional but recommended)
    if (data.idempotencyKey && typeof data.idempotencyKey !== 'string') {
        errors.push('idempotencyKey must be a string if provided');
    }

    return errors;
}

// ============================================
// HELPER: Find Best Freelancer (Read-Only)
// ============================================
/**
 * Internal Helper: Find Best Freelancer (Read-Only)
 * 
 * Logic:
 * 1. Find eligible freelancers (Active, Online, Matching Service, Same City)
 * 2. Sort by Tier (Gold > Silver > Bronze) then Last Active (Asc)
 * 3. Return top match or null
 * 
 * @returns {Object|null} Freelancer data with id, or null
 */
async function findBestFreelancer(transaction, cityId, serviceCategory) {
    // 1. Query Eligible Freelancers
    const freelancersRef = db.collection(`cities/${cityId}/freelancers`);
    const q = freelancersRef
        .where('status', '==', 'active')
        .where('isOnline', '==', true)
        .where('serviceCategories', 'array-contains', serviceCategory);

    // READ within transaction
    const snapshot = await transaction.get(q);

    if (snapshot.empty) {
        return null;
    }

    // 2. Sort Freelancers (In-Memory)
    const freelancers = [];
    snapshot.forEach(doc => {
        freelancers.push({ id: doc.id, ...doc.data() });
    });

    const tierScore = { 'gold': 3, 'silver': 2, 'bronze': 1 };

    freelancers.sort((a, b) => {
        // Primary: Tier (Desc)
        const scoreA = tierScore[a.priorityTier] || 0;
        const scoreB = tierScore[b.priorityTier] || 0;
        if (scoreA !== scoreB) return scoreB - scoreA;

        // Secondary: Last Active (Asc) - Earliest first
        const timeA = a.lastActiveAt?.toMillis?.() || 0;
        const timeB = b.lastActiveAt?.toMillis?.() || 0;
        return timeA - timeB;
    });

    return freelancers[0];
}

// ============================================
// BOOKING FUNCTIONS
// ============================================

/**
 * Create a new booking (in-shop or home service)
 * 
 * This is the ONLY way to create a booking.
 * All bookings must go through this function.
 * 
 * @param {Object} data - Booking data
 * @param {string} data.type - "inShop" or "home"
 * @param {string} data.cityId - City identifier
 * @param {string} data.serviceId - Service identifier
 * @param {number|Object} data.scheduledAt - Scheduled timestamp
 * @param {string} [data.idempotencyKey] - Optional key for idempotency
 * 
 * @returns {Object} { bookingId, status }
 */
exports.createBooking = functions.https.onCall(async (data, context) => {
    // 1. Require authentication
    const uid = requireAuth(context);
    const { type, cityId, serviceId, scheduledAt, idempotencyKey } = data;

    functions.logger.info('createBooking called', { uid, data });

    // 2. Validate input
    const validationErrors = validateBookingInput(data);
    if (validationErrors.length > 0) {
        functions.logger.warn('Validation failed', { uid, errors: validationErrors });
        throw new functions.https.HttpsError(
            'invalid-argument',
            `Invalid booking data: ${validationErrors.join(', ')}`
        );
    }

    // 3. Validate user has activeRole = "customer"
    const userDoc = await db.doc(`users/${uid}`).get();

    if (!userDoc.exists) {
        functions.logger.warn('User document not found', { uid });
        throw new functions.https.HttpsError(
            'failed-precondition',
            'User profile not found. Please complete your profile first.'
        );
    }

    const userData = userDoc.data();

    if (userData.activeRole !== 'customer') {
        functions.logger.warn('User is not in customer role', { uid, activeRole: userData.activeRole });
        throw new functions.https.HttpsError(
            'failed-precondition',
            `You must be in customer role to create a booking. Current role: ${userData.activeRole}`
        );
    }

    // 4. Validate Service & Get Category
    const serviceDoc = await db.doc(`cities/${cityId}/services/${serviceId}`).get();
    if (!serviceDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Service not found.');
    }
    const serviceData = serviceDoc.data();
    const serviceCategory = serviceData.category;  // e.g., "haircut", "facial"

    if (!serviceCategory) {
        throw new functions.https.HttpsError('failed-precondition', 'Service has no category.');
    }

    // 5. Check idempotency (if key provided)
    if (idempotencyKey) {
        const existingBooking = await db
            .collection(`cities/${cityId}/bookings`)
            .where('idempotencyKey', '==', idempotencyKey)
            .limit(1)
            .get();

        if (!existingBooking.empty) {
            const existing = existingBooking.docs[0].data();
            functions.logger.info('Idempotent request - returning existing booking', {
                bookingId: existing.bookingId,
                idempotencyKey
            });
            return {
                bookingId: existing.bookingId,
                status: existing.status,
                alreadyExists: true,
            };
        }
    }

    // 6. Create booking in transaction
    const bookingRef = db.collection(`cities/${cityId}/bookings`).doc();
    const bookingId = bookingRef.id;
    const now = FieldValue.serverTimestamp();

    // Parse scheduledAt to Firestore Timestamp
    let scheduledTimestamp;
    if (typeof scheduledAt === 'number') {
        scheduledTimestamp = Timestamp.fromMillis(scheduledAt);
    } else if (scheduledAt._seconds) {
        scheduledTimestamp = new Timestamp(scheduledAt._seconds, scheduledAt._nanoseconds || 0);
    } else {
        scheduledTimestamp = Timestamp.fromDate(new Date(scheduledAt));
    }

    const bookingData = {
        bookingId,
        customerId: uid,
        type,
        serviceId,
        serviceCategory, // Storing category for easier lookups
        cityId,
        scheduledAt: scheduledTimestamp,
        status: 'CREATED',
        idempotencyKey: idempotencyKey || null,
        createdAt: now,
        updatedAt: now,
    };

    const statusEventData = {
        from: null,
        to: 'CREATED',
        actor: 'customer',
        actorId: uid,
        timestamp: now,
    };

    try {
        const result = await db.runTransaction(async (transaction) => {
            let assignedFreelancer = null;
            let assignmentStatus = 'CREATED';

            // A. Read: Find Freelancer (Home Bookings Only)
            if (type === 'home') {
                assignedFreelancer = await findBestFreelancer(
                    transaction,
                    cityId,
                    serviceCategory
                );

                if (assignedFreelancer) {
                    assignmentStatus = 'ASSIGNED';
                    bookingData.freelancerId = assignedFreelancer.id;
                    bookingData.status = 'ASSIGNED';
                } else {
                    assignmentStatus = 'FAILED';
                    bookingData.status = 'FAILED';
                    bookingData.failureReason = 'NO_FREELANCER_AVAILABLE';
                }
            }

            // B. Write: Create booking document
            transaction.set(bookingRef, bookingData);

            // C. Write: Create status event (CREATED)
            const createdEventRef = bookingRef.collection('status_events').doc();
            transaction.set(createdEventRef, statusEventData);

            // D. Write: Assignment Status Event (if home booking)
            if (type === 'home') {
                const assignEventRef = bookingRef.collection('status_events').doc();
                if (assignedFreelancer) {
                    transaction.set(assignEventRef, {
                        from: 'CREATED',
                        to: 'ASSIGNED',
                        actor: 'system',
                        timestamp: now,
                        freelancerId: assignedFreelancer.id
                    });
                } else {
                    transaction.set(assignEventRef, {
                        from: 'CREATED',
                        to: 'FAILED',
                        actor: 'system',
                        timestamp: now,
                        reason: 'NO_FREELANCER_AVAILABLE'
                    });
                }
            }

            return {
                bookingId,
                status: assignmentStatus
            };
        });

        functions.logger.info('Booking process completed', {
            bookingId,
            status: result.status
        });

        // 7. Handle Assignment Success -> Enqueue Timeout Task
        if (result.status === 'ASSIGNED') {
            try {
                const queue = getFunctions().taskQueue('onFreelancerAssignmentTimeout');
                await queue.enqueue({
                    bookingId: result.bookingId,
                    cityId
                }, {
                    scheduleDelaySeconds: 30, // 30s timeout
                    dispatchDeadlineSeconds: 60 * 5 // 5 mins
                });
                functions.logger.info('Assignment timeout task enqueued', { bookingId: result.bookingId });
            } catch (queueError) {
                functions.logger.error('Failed to enqueue timeout task', {
                    bookingId: result.bookingId,
                    error: queueError.message
                });
                // Note: We don't fail the booking if enqueue fails, but we assume it works.
            }
        }

        // 8. Handle Assignment Failure
        if (result.status === 'FAILED') {
            throw new functions.https.HttpsError(
                'resource-exhausted',
                'NO_FREELANCER_AVAILABLE'
            );
        }

        return result;

    } catch (error) {
        // Re-throw HttpsErrors logic
        if (error.code === 'resource-exhausted') {
            throw error;
        }

        functions.logger.error('Failed to create booking', {
            uid,
            error: error.message,
            data
        });
        throw new functions.https.HttpsError(
            'internal',
            'Failed to create booking. Please try again.'
        );
    }
});

// ============================================
// READ-ONLY BOOKING FUNCTIONS
// ============================================

/**
 * Sanitize booking data - return only safe fields
 */
function sanitizeBooking(bookingData) {
    // Helper to convert Firestore Timestamp to ISO string
    const toISOString = (value) => {
        if (!value) return null;
        if (value.toDate && typeof value.toDate === 'function') {
            return value.toDate().toISOString();
        }
        return value;
    };

    return {
        bookingId: bookingData.bookingId || null,
        type: bookingData.type || null,
        status: bookingData.status || null,
        serviceId: bookingData.serviceId || null,
        cityId: bookingData.cityId || null,
        scheduledAt: toISOString(bookingData.scheduledAt),
        createdAt: toISOString(bookingData.createdAt),
    };
}

/**
 * Get bookings for the authenticated user based on their active role
 */
exports.getMyBookings = functions.https.onCall(async (data, context) => {
    // 1. Require authentication
    const uid = requireAuth(context);

    try {
        const userDoc = await db.doc(`users/${uid}`).get();
        if (!userDoc.exists) throw new functions.https.HttpsError('failed-precondition', 'User profile not found.');

        const userData = userDoc.data();
        const activeRole = userData.activeRole;
        if (!activeRole) throw new functions.https.HttpsError('failed-precondition', 'No active role set.');

        const cityId = userData.cityId || 'trichy';
        const bookingsRef = db.collection(`cities/${cityId}/bookings`);
        let query;

        if (activeRole === 'customer') {
            query = bookingsRef.where('customerId', '==', uid).orderBy('createdAt', 'desc').limit(20);
        } else if (activeRole === 'vendor') {
            const vendorId = userData.vendorId || uid;
            query = bookingsRef.where('salonId', '==', vendorId).orderBy('createdAt', 'desc').limit(20);
        } else if (activeRole === 'freelancer') {
            query = bookingsRef.where('freelancerId', '==', uid).orderBy('createdAt', 'desc').limit(20);
        } else {
            throw new functions.https.HttpsError('invalid-argument', `Invalid role: ${activeRole}`);
        }

        const snapshot = await query.get();
        const bookings = snapshot.docs.map(doc => sanitizeBooking(doc.data()));
        return { bookings };

    } catch (error) {
        if (error instanceof functions.https.HttpsError) throw error;
        functions.logger.error('Failed to fetch bookings', { uid, error: error.message });
        throw new functions.https.HttpsError('internal', 'Failed to fetch bookings.');
    }
});

/**
 * Get a specific booking by ID
 */
exports.getBookingById = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId } = data;

    if (!bookingId || !cityId) throw new functions.https.HttpsError('invalid-argument', 'Missing bookingId or cityId.');

    try {
        const bookingDoc = await db.doc(`cities/${cityId}/bookings/${bookingId}`).get();
        if (!bookingDoc.exists) throw new functions.https.HttpsError('not-found', 'Booking not found.');

        const bookingData = bookingDoc.data();
        const isAllowed =
            bookingData.customerId === uid ||
            bookingData.vendorId === uid ||
            bookingData.salonId === uid ||
            bookingData.freelancerId === uid;

        if (!isAllowed) throw new functions.https.HttpsError('permission-denied', 'Permission denied.');

        return { booking: sanitizeBooking(bookingData) };
    } catch (error) {
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError('internal', 'Failed to fetch booking.');
    }
});

// ============================================
// VENDOR BOOKING FUNCTIONS
// ============================================

/**
 * Vendor responds to an in-shop booking (ACCEPT or REJECT)
 */
exports.vendorRespondToBooking = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId, action } = data;

    if (!['ACCEPT', 'REJECT'].includes(action)) throw new functions.https.HttpsError('invalid-argument', 'Invalid action.');

    const userDoc = await db.doc(`users/${uid}`).get();
    if (userDoc.data().activeRole !== 'vendor') throw new functions.https.HttpsError('permission-denied', 'Must be a vendor.');

    const vendorSalonId = userDoc.data().salonId || userDoc.data().vendorId || uid;
    const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);

    try {
        await db.runTransaction(async (transaction) => {
            const bookingDoc = await transaction.get(bookingRef);
            if (!bookingDoc.exists) throw new functions.https.HttpsError('not-found', 'Booking not found.');

            const bookingData = bookingDoc.data();
            if (bookingData.type !== 'inShop') throw new functions.https.HttpsError('failed-precondition', 'Only inShop bookings.');
            if (bookingData.status !== 'CREATED') throw new functions.https.HttpsError('failed-precondition', 'Booking not CREATED.');
            if (bookingData.salonId !== vendorSalonId && bookingData.vendorId !== uid) throw new functions.https.HttpsError('permission-denied', 'Not your booking.');

            const newStatus = action === 'ACCEPT' ? 'CONFIRMED' : 'REJECTED';
            const now = FieldValue.serverTimestamp();

            transaction.update(bookingRef, { status: newStatus, updatedAt: now });
            transaction.set(bookingRef.collection('status_events').doc(), {
                from: 'CREATED',
                to: newStatus,
                actor: 'vendor',
                actorId: uid,
                timestamp: now,
            });
        });
        return { bookingId, status: action === 'ACCEPT' ? 'CONFIRMED' : 'REJECTED' };
    } catch (error) {
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError('internal', error.message);
    }
});

// ============================================
// FREELANCER BOOKING FUNCTIONS
// ============================================

/**
 * Freelancer responds to a home booking (ACCEPT or REJECT)
 * 
 * Rules:
 * - activeRole == freelancer
 * - booking.type == home
 * - booking.status == ASSIGNED
 * - booking.freelancerId == uid
 */
exports.freelancerRespondToBooking = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId, action } = data;

    functions.logger.info('freelancerRespondToBooking', { uid, bookingId, action });

    if (!['ACCEPT', 'REJECT'].includes(action)) {
        throw new functions.https.HttpsError('invalid-argument', 'Action must be ACCEPT or REJECT.');
    }

    try {
        // 1. Verify Role
        const userDoc = await db.doc(`users/${uid}`).get();
        if (!userDoc.exists || userDoc.data().activeRole !== 'freelancer') {
            throw new functions.https.HttpsError('permission-denied', 'Must be a freelancer.');
        }

        // 2. Transaction
        const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);
        const result = await db.runTransaction(async (transaction) => {
            const bookingDoc = await transaction.get(bookingRef);
            if (!bookingDoc.exists) throw new functions.https.HttpsError('not-found', 'Booking not found.');

            const booking = bookingDoc.data();

            // Checks
            if (booking.type !== 'home') throw new functions.https.HttpsError('failed-precondition', 'Only home bookings.');
            if (booking.status !== 'ASSIGNED') throw new functions.https.HttpsError('failed-precondition', `Current status is ${booking.status}.`);
            if (booking.freelancerId !== uid) throw new functions.https.HttpsError('permission-denied', 'This booking is not assigned to you.');

            const newStatus = action === 'ACCEPT' ? 'CONFIRMED' : 'REJECTED';
            const now = FieldValue.serverTimestamp();

            // Update
            transaction.update(bookingRef, {
                status: newStatus,
                updatedAt: now
            });

            // Event
            const eventRef = bookingRef.collection('status_events').doc();
            transaction.set(eventRef, {
                from: 'ASSIGNED',
                to: newStatus,
                actor: 'freelancer',
                actorId: uid,
                timestamp: now
            });

            return { bookingId, status: newStatus };
        });

        return result;

    } catch (error) {
        if (error instanceof functions.https.HttpsError) throw error;
        functions.logger.error('Error in freelancerRespondToBooking', error);
        throw new functions.https.HttpsError('internal', 'Internal error processing response.');
    }
});

/**
 * Assignment Timeout Handler
 * Triggered via Cloud Tasks ~30s after assignment
 */
exports.onFreelancerAssignmentTimeout = functions.tasks.taskQueue({
    retryConfig: {
        maxAttempts: 1, // NO RETRIES as per requirements
    },
    rateLimits: {
        maxConcurrentDispatches: 6
    }
}).onDispatch(async (data) => {
    const { bookingId, cityId } = data;
    functions.logger.info('onFreelancerAssignmentTimeout triggered', { bookingId });

    try {
        const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);
        const bookingDoc = await bookingRef.get();

        if (!bookingDoc.exists) return;

        const booking = bookingDoc.data();

        // Only act if still ASSIGNED
        if (booking.status === 'ASSIGNED') {
            const now = FieldValue.serverTimestamp();

            // Per requirements: DO NOT Reassign. DO NOT Modify Status (Only WRITE EVENT per prompt?)
            // Prompt says: "Write status event: from: ASSIGNED to: TIMEOUT actor: system"
            // Prompt says: "DO NOT: Modify booking.status"
            // Wait, if I don't modify booking status to TIMEOUT, it stays ASSIGNED? 
            // The prompt says "Write status event... to: TIMEOUT".
            // But "DO NOT: Modify booking.status".
            // This implies the booking REMAINS 'ASSIGNED' but we log a 'TIMEOUT' event?
            // This seems odd, but I MUST FOLLOW THE PROMPT.
            // "If still ASSIGNED: Write status event ... DO NOT Modify booking.status"
            // OK. I will do exactly that.

            const eventRef = bookingRef.collection('status_events').doc();
            await eventRef.set({
                from: 'ASSIGNED',
                to: 'TIMEOUT',
                actor: 'system',
                timestamp: now
            });

            functions.logger.info('Logged TIMEOUT event', { bookingId });
        } else {
            functions.logger.info('Booking no longer ASSIGNED', { bookingId, status: booking.status });
        }
    } catch (error) {
        functions.logger.error('Error in timeout handler', error);
    }
});


// ============================================
// PLACEHOLDER FUNCTIONS (NOT IMPLEMENTED)
// ============================================

exports.acceptBooking = functions.https.onCall((data, context) => {
    return { status: 'NOT_IMPLEMENTED' };
});

exports.rejectBooking = functions.https.onCall((data, context) => {
    return { status: 'NOT_IMPLEMENTED' };
});

exports.cancelBooking = functions.https.onCall((data, context) => {
    return { status: 'NOT_IMPLEMENTED' };
});

exports.completeBooking = functions.https.onCall((data, context) => {
    return { status: 'NOT_IMPLEMENTED' };
});

exports.submitReview = functions.https.onCall((data, context) => {
    return { status: 'NOT_IMPLEMENTED' };
});

exports.switchRole = functions.https.onCall((data, context) => {
    return { status: 'NOT_IMPLEMENTED' };
});

// ============================================
// HEALTH CHECK
// ============================================

exports.healthCheck = functions.https.onCall((_data, _context) => {
    return {
        status: 'OK',
        timestamp: new Date().toISOString(),
        runtime: 'Node.js 18',
    };
});
