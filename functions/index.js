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

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();

// ============================================
// HELPER: Require Authentication
// ============================================
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

    const { type, cityId, serviceId, scheduledAt, idempotencyKey } = data;

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

    // 4. Check idempotency (if key provided)
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

    // 5. Create booking in transaction
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
        await db.runTransaction(async (transaction) => {
            // Create booking document
            transaction.set(bookingRef, bookingData);

            // Create status event subcollection entry
            const statusEventRef = bookingRef.collection('status_events').doc();
            transaction.set(statusEventRef, statusEventData);
        });

        functions.logger.info('Booking created successfully', {
            bookingId,
            customerId: uid,
            type,
            cityId,
            serviceId
        });

        return {
            bookingId,
            status: 'CREATED',
        };

    } catch (error) {
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
// PLACEHOLDER FUNCTIONS (NOT IMPLEMENTED)
// ============================================

/**
 * Accept a booking (vendor or freelancer)
 */
exports.acceptBooking = functions.https.onCall((data, context) => {
    requireAuth(context);
    return { status: 'NOT_IMPLEMENTED', message: 'acceptBooking placeholder' };
});

/**
 * Reject a booking (freelancer only)
 */
exports.rejectBooking = functions.https.onCall((data, context) => {
    requireAuth(context);
    return { status: 'NOT_IMPLEMENTED', message: 'rejectBooking placeholder' };
});

/**
 * Cancel a booking
 */
exports.cancelBooking = functions.https.onCall((data, context) => {
    requireAuth(context);
    return { status: 'NOT_IMPLEMENTED', message: 'cancelBooking placeholder' };
});

/**
 * Complete a booking
 */
exports.completeBooking = functions.https.onCall((data, context) => {
    requireAuth(context);
    return { status: 'NOT_IMPLEMENTED', message: 'completeBooking placeholder' };
});

/**
 * Submit a review
 */
exports.submitReview = functions.https.onCall((data, context) => {
    requireAuth(context);
    return { status: 'NOT_IMPLEMENTED', message: 'submitReview placeholder' };
});

/**
 * Switch user role
 */
exports.switchRole = functions.https.onCall((data, context) => {
    requireAuth(context);
    return { status: 'NOT_IMPLEMENTED', message: 'switchRole placeholder' };
});

// ============================================
// HEALTH CHECK
// ============================================

exports.healthCheck = functions.https.onCall((_data, _context) => {
    return {
        status: 'OK',
        timestamp: new Date().toISOString(),
        runtime: 'Node.js 18',
        project: 'jayple-app-2026',
    };
});
