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
 * 
 * - Customer: bookings where customerId == uid
 * - Vendor: bookings where salonId == vendorId
 * - Freelancer: bookings where freelancerId == uid
 * 
 * Returns last 20 bookings ordered by createdAt desc
 */
exports.getMyBookings = functions.https.onCall(async (data, context) => {
    // 1. Require authentication
    const uid = requireAuth(context);

    functions.logger.info('getMyBookings called', { uid });

    try {
        // 2. Fetch user document to get activeRole
        const userDoc = await db.doc(`users/${uid}`).get();

        if (!userDoc.exists) {
            functions.logger.warn('User document not found', { uid });
            throw new functions.https.HttpsError(
                'failed-precondition',
                'User profile not found.'
            );
        }

        const userData = userDoc.data();
        const activeRole = userData.activeRole;

        if (!activeRole) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'No active role set for user.'
            );
        }

        functions.logger.info('Fetching bookings for role', { uid, activeRole });

        // 3. Get cityId from user (default to 'trichy' if not set)
        const cityId = userData.cityId || 'trichy';

        // 4. Build query based on role
        let query;
        const bookingsRef = db.collection(`cities/${cityId}/bookings`);

        if (activeRole === 'customer') {
            query = bookingsRef
                .where('customerId', '==', uid)
                .orderBy('createdAt', 'desc')
                .limit(20);
        } else if (activeRole === 'vendor') {
            // Vendor sees bookings for their salon
            const vendorId = userData.vendorId || uid;
            query = bookingsRef
                .where('salonId', '==', vendorId)
                .orderBy('createdAt', 'desc')
                .limit(20);
        } else if (activeRole === 'freelancer') {
            query = bookingsRef
                .where('freelancerId', '==', uid)
                .orderBy('createdAt', 'desc')
                .limit(20);
        } else {
            throw new functions.https.HttpsError(
                'invalid-argument',
                `Invalid role: ${activeRole}`
            );
        }

        // 5. Execute query
        const snapshot = await query.get();

        // 6. Sanitize and return bookings
        const bookings = [];
        snapshot.forEach(doc => {
            bookings.push(sanitizeBooking(doc.data()));
        });

        functions.logger.info('Returning bookings', {
            uid,
            activeRole,
            count: bookings.length
        });

        return { bookings };

    } catch (error) {
        // Re-throw HttpsErrors
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        functions.logger.error('Failed to fetch bookings', {
            uid,
            error: error.message
        });
        throw new functions.https.HttpsError(
            'internal',
            'Failed to fetch bookings.'
        );
    }
});

/**
 * Get a specific booking by ID
 * 
 * Only returns the booking if the caller is involved:
 * - customerId OR vendorId OR freelancerId
 * 
 * @param {Object} data - { bookingId, cityId }
 */
exports.getBookingById = functions.https.onCall(async (data, context) => {
    // 1. Require authentication
    const uid = requireAuth(context);

    functions.logger.info('getBookingById called', { uid, data });

    // 2. Validate input
    const { bookingId, cityId } = data;

    if (!bookingId || typeof bookingId !== 'string') {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'bookingId is required and must be a string.'
        );
    }

    if (!cityId || typeof cityId !== 'string') {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'cityId is required and must be a string.'
        );
    }

    try {
        // 3. Fetch booking document
        const bookingDoc = await db.doc(`cities/${cityId}/bookings/${bookingId}`).get();

        if (!bookingDoc.exists) {
            throw new functions.https.HttpsError(
                'not-found',
                'Booking not found.'
            );
        }

        const bookingData = bookingDoc.data();

        // 4. Verify caller is involved in the booking
        const isCustomer = bookingData.customerId === uid;
        const isVendor = bookingData.vendorId === uid || bookingData.salonId === uid;
        const isFreelancer = bookingData.freelancerId === uid;

        if (!isCustomer && !isVendor && !isFreelancer) {
            functions.logger.warn('Permission denied - user not involved', {
                uid,
                bookingId,
                customerId: bookingData.customerId,
                vendorId: bookingData.vendorId,
                freelancerId: bookingData.freelancerId
            });
            throw new functions.https.HttpsError(
                'permission-denied',
                'You do not have permission to view this booking.'
            );
        }

        // 5. Return sanitized booking
        functions.logger.info('Returning booking', { uid, bookingId });

        return { booking: sanitizeBooking(bookingData) };

    } catch (error) {
        // Re-throw HttpsErrors
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        functions.logger.error('Failed to fetch booking', {
            uid,
            bookingId,
            error: error.message
        });
        throw new functions.https.HttpsError(
            'internal',
            'Failed to fetch booking.'
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
