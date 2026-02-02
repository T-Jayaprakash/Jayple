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
    if (!data.type) errors.push('type is required');
    else if (!['inShop', 'home'].includes(data.type)) errors.push('type must be either "inShop" or "home"');
    if (!data.cityId || typeof data.cityId !== 'string') errors.push('cityId is required and must be a string');
    if (!data.serviceId || typeof data.serviceId !== 'string') errors.push('serviceId is required and must be a string');
    if (!data.scheduledAt) errors.push('scheduledAt is required');
    if (data.idempotencyKey && typeof data.idempotencyKey !== 'string') errors.push('idempotencyKey must be a string if provided');
    return errors;
}

// ============================================
// HELPER: Assignment Logic
// ============================================

async function findBestFreelancer(transaction, cityId, serviceCategory, excludedIds = []) {
    const freelancersRef = db.collection(`cities/${cityId}/freelancers`);
    const q = freelancersRef
        .where('status', '==', 'active')
        .where('isOnline', '==', true)
        .where('serviceCategories', 'array-contains', serviceCategory);

    const snapshot = await transaction.get(q);
    if (snapshot.empty) return null;

    const freelancers = [];
    snapshot.forEach(doc => {
        if (!excludedIds.includes(doc.id)) {
            freelancers.push({ id: doc.id, ...doc.data() });
        }
    });

    if (freelancers.length === 0) return null;

    const tierScore = { 'gold': 3, 'silver': 2, 'bronze': 1 };
    freelancers.sort((a, b) => {
        const scoreA = tierScore[a.priorityTier] || 0;
        const scoreB = tierScore[b.priorityTier] || 0;
        if (scoreA !== scoreB) return scoreB - scoreA;
        const timeA = a.lastActiveAt?.toMillis?.() || 0;
        const timeB = b.lastActiveAt?.toMillis?.() || 0;
        return timeA - timeB;
    });

    return freelancers[0];
}

async function findReplacement(transaction, bookingData) {
    const attempts = bookingData.assignmentAttempts || [];
    if (attempts.length >= 3) return { success: false, reason: 'MAX_ASSIGNMENT_ATTEMPTS' };

    const currentFreelancerId = bookingData.freelancerId;
    const pastIds = attempts.map(a => a.freelancerId);
    const excludedIds = [...new Set([currentFreelancerId, ...pastIds].filter(Boolean))];

    const nextFreelancer = await findBestFreelancer(
        transaction,
        bookingData.cityId,
        bookingData.serviceCategory,
        excludedIds
    );

    if (!nextFreelancer) return { success: false, reason: 'NO_REPLACEMENT_AVAILABLE' };

    return { success: true, freelancer: nextFreelancer };
}

function writeReassignment(transaction, bookingRef, bookingData, replacementResult, timestamp) {
    const attempts = bookingData.assignmentAttempts || [];

    if (replacementResult.success) {
        const attemptEntry = {
            freelancerId: bookingData.freelancerId,
            assignedAt: bookingData.updatedAt || timestamp,
            failedAt: timestamp
        };

        transaction.update(bookingRef, {
            freelancerId: replacementResult.freelancer.id,
            status: 'ASSIGNED',
            updatedAt: timestamp,
            assignmentAttempts: FieldValue.arrayUnion(attemptEntry)
        });

        const eventRef = bookingRef.collection('status_events').doc();
        transaction.set(eventRef, {
            from: 'ASSIGNED',
            to: 'REASSIGNED',
            actor: 'system',
            attemptNumber: attempts.length + 1,
            freelancerId: replacementResult.freelancer.id,
            timestamp: timestamp
        });

        return { status: 'ASSIGNED', freelancerId: replacementResult.freelancer.id };
    } else {
        transaction.update(bookingRef, {
            status: 'FAILED',
            updatedAt: timestamp,
            failureReason: replacementResult.reason
        });

        const eventRef = bookingRef.collection('status_events').doc();
        transaction.set(eventRef, {
            from: 'ASSIGNED',
            to: 'FAILED',
            actor: 'system',
            reason: replacementResult.reason,
            timestamp: timestamp
        });

        return { status: 'FAILED' };
    }
}

async function enqueueAssignmentTimeout(bookingId, cityId) {
    try {
        const queue = getFunctions().taskQueue('onFreelancerAssignmentTimeout');
        await queue.enqueue({ bookingId, cityId }, {
            scheduleDelaySeconds: 30,
            dispatchDeadlineSeconds: 60 * 5
        });
    } catch (e) {
        // Ignore in emulator
    }
}

// ============================================
// BOOKING FUNCTIONS
// ============================================

exports.createBooking = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { type, cityId, serviceId, scheduledAt, idempotencyKey } = data;

    const validationErrors = validateBookingInput(data);
    if (validationErrors.length > 0) throw new functions.https.HttpsError('invalid-argument', `Invalid: ${validationErrors.join(', ')}`);

    const userDoc = await db.doc(`users/${uid}`).get();
    if (!userDoc.exists || userDoc.data().activeRole !== 'customer') throw new functions.https.HttpsError('failed-precondition', 'Must be customer.');

    const serviceDoc = await db.doc(`cities/${cityId}/services/${serviceId}`).get();
    if (!serviceDoc.exists) throw new functions.https.HttpsError('not-found', 'Service not found.');
    const serviceCategory = serviceDoc.data().category;

    if (idempotencyKey) {
        const existing = await db.collection(`cities/${cityId}/bookings`).where('idempotencyKey', '==', idempotencyKey).limit(1).get();
        if (!existing.empty) return { bookingId: existing.docs[0].id, status: existing.docs[0].data().status, alreadyExists: true };
    }

    const bookingRef = db.collection(`cities/${cityId}/bookings`).doc();
    const bookingId = bookingRef.id;
    const now = FieldValue.serverTimestamp();

    let scheduledTimestamp;
    if (typeof scheduledAt === 'number') scheduledTimestamp = Timestamp.fromMillis(scheduledAt);
    else if (scheduledAt._seconds) scheduledTimestamp = new Timestamp(scheduledAt._seconds, scheduledAt._nanoseconds || 0);
    else scheduledTimestamp = Timestamp.fromDate(new Date(scheduledAt));

    const bookingData = {
        bookingId, customerId: uid, type, serviceId, serviceCategory, cityId,
        scheduledAt: scheduledTimestamp, status: 'CREATED', idempotencyKey: idempotencyKey || null,
        createdAt: now, updatedAt: now, assignmentAttempts: []
    };

    try {
        const result = await db.runTransaction(async (transaction) => {
            let assignedFreelancer = null;
            let assignmentStatus = 'CREATED';

            if (type === 'home') {
                assignedFreelancer = await findBestFreelancer(transaction, cityId, serviceCategory, []);
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

            transaction.set(bookingRef, bookingData);
            transaction.set(bookingRef.collection('status_events').doc(), {
                from: null, to: 'CREATED', actor: 'customer', actorId: uid, timestamp: now,
            });

            if (type === 'home') {
                const eventRef = bookingRef.collection('status_events').doc();
                if (assignedFreelancer) {
                    transaction.set(eventRef, {
                        from: 'CREATED', to: 'ASSIGNED', actor: 'system', timestamp: now, freelancerId: assignedFreelancer.id
                    });
                } else {
                    transaction.set(eventRef, {
                        from: 'CREATED', to: 'FAILED', actor: 'system', timestamp: now, reason: 'NO_FREELANCER_AVAILABLE'
                    });
                }
            }
            return { bookingId, status: assignmentStatus };
        });

        if (result.status === 'ASSIGNED') await enqueueAssignmentTimeout(result.bookingId, cityId);
        if (result.status === 'FAILED') throw new functions.https.HttpsError('resource-exhausted', 'NO_FREELANCER_AVAILABLE');

        return result;
    } catch (e) {
        if (e.code === 'resource-exhausted') throw e;
        throw new functions.https.HttpsError('internal', 'Create failed.');
    }
});

exports.getMyBookings = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const userDoc = await db.doc(`users/${uid}`).get();
    const { activeRole, cityId = 'trichy', vendorId } = userDoc.data();
    let query = db.collection(`cities/${cityId}/bookings`).orderBy('createdAt', 'desc').limit(20);

    if (activeRole === 'customer') query = query.where('customerId', '==', uid);
    else if (activeRole === 'vendor') query = query.where('salonId', '==', vendorId || uid);
    else if (activeRole === 'freelancer') query = query.where('freelancerId', '==', uid);
    else throw new functions.https.HttpsError('invalid-argument', 'Invalid role.');

    const snap = await query.get();
    const sanitize = d => ({
        bookingId: d.bookingId, type: d.type, status: d.status, serviceId: d.serviceId,
        cityId: d.cityId, freelancerId: d.freelancerId,
        scheduledAt: d.scheduledAt?.toDate?.().toISOString(), createdAt: d.createdAt?.toDate?.().toISOString()
    });
    return { bookings: snap.docs.map(d => sanitize(d.data())) };
});

exports.getBookingById = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId } = data;
    const doc = await db.doc(`cities/${cityId}/bookings/${bookingId}`).get();
    if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Not found.');
    const d = doc.data();
    if (d.customerId !== uid && d.vendorId !== uid && d.salonId !== uid && d.freelancerId !== uid) throw new functions.https.HttpsError('permission-denied', 'Denied.');

    return {
        booking: {
            bookingId: d.bookingId, type: d.type, status: d.status, serviceId: d.serviceId, cityId: d.cityId, freelancerId: d.freelancerId, assignmentAttempts: d.assignmentAttempts,
            scheduledAt: d.scheduledAt?.toDate?.().toISOString(), createdAt: d.createdAt?.toDate?.().toISOString()
        }
    };
});

exports.freelancerRespondToBooking = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId, action } = data;
    if (!['ACCEPT', 'REJECT'].includes(action)) throw new functions.https.HttpsError('invalid-argument', 'Invalid action.');

    try {
        const result = await db.runTransaction(async (t) => {
            const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);
            const doc = await t.get(bookingRef);
            if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Not found.');
            const d = doc.data();

            if (d.type !== 'home') throw new functions.https.HttpsError('failed-precondition', 'Not home.');
            if (d.status !== 'ASSIGNED') throw new functions.https.HttpsError('failed-precondition', `Status ${d.status}.`);
            if (d.freelancerId !== uid) throw new functions.https.HttpsError('permission-denied', 'Not yours.');

            // Look for replacement NOW (Must be before Writes)
            let replacementResult = null;
            if (action === 'REJECT') {
                replacementResult = await findReplacement(t, d);
            }

            const now = Timestamp.now(); // Use Concrete Timestamp for Array compatibility

            if (action === 'ACCEPT') {
                t.update(bookingRef, { status: 'CONFIRMED', updatedAt: now });
                t.set(bookingRef.collection('status_events').doc(), {
                    from: 'ASSIGNED', to: 'CONFIRMED', actor: 'freelancer', actorId: uid, timestamp: now
                });
                return { status: 'CONFIRMED' };
            } else {
                // REJECT
                t.set(bookingRef.collection('status_events').doc(), {
                    from: 'ASSIGNED', to: 'REJECTED', actor: 'freelancer', actorId: uid, timestamp: now
                });

                // writes based on replacementResult (Already Read)
                return writeReassignment(t, bookingRef, d, replacementResult, now);
            }
        });

        if (result.status === 'ASSIGNED') await enqueueAssignmentTimeout(bookingId, cityId);
        return { bookingId, status: result.status };
    } catch (e) {
        if (e instanceof functions.https.HttpsError) throw e;
        throw new functions.https.HttpsError('internal', e.message);
    }
});

exports.onFreelancerAssignmentTimeout = functions.tasks.taskQueue({
    retryConfig: { maxAttempts: 1 },
    rateLimits: { maxConcurrentDispatches: 6 }
}).onDispatch(async (data) => {
    const { bookingId, cityId } = data;
    const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);

    try {
        await db.runTransaction(async (t) => {
            const doc = await t.get(bookingRef);
            if (!doc.exists) return;
            const d = doc.data();

            if (d.status === 'ASSIGNED') {
                const replacementResult = await findReplacement(t, d);
                const now = Timestamp.now(); // Use Concrete Timestamp

                t.set(bookingRef.collection('status_events').doc(), {
                    from: 'ASSIGNED', to: 'TIMEOUT', actor: 'system', timestamp: now
                });

                writeReassignment(t, bookingRef, d, replacementResult, now);
            }
        });

        const outputDoc = await bookingRef.get();
        if (outputDoc.exists && outputDoc.data().status === 'ASSIGNED') {
            await enqueueAssignmentTimeout(bookingId, cityId);
        }
    } catch (e) { }
});

exports.vendorRespondToBooking = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId, action } = data;
    const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);
    try {
        await db.runTransaction(async (t) => {
            const doc = await t.get(bookingRef);
            const d = doc.data();
            if (d.salonId && d.salonId !== uid && d.vendorId !== uid) throw new functions.https.HttpsError('permission-denied', 'No');
            const newStatus = action === 'ACCEPT' ? 'CONFIRMED' : 'REJECTED';
            const now = FieldValue.serverTimestamp();
            t.update(bookingRef, { status: newStatus, updatedAt: now });
            t.set(bookingRef.collection('status_events').doc(), { from: 'CREATED', to: newStatus, actor: 'vendor', actorId: uid, timestamp: now });
        });
        return { bookingId, status: action === 'ACCEPT' ? 'CONFIRMED' : 'REJECTED' };
    } catch (e) { throw new functions.https.HttpsError('internal', e.message); }
});

exports.acceptBooking = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.rejectBooking = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.cancelBooking = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.completeBooking = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.submitReview = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.switchRole = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.healthCheck = functions.https.onCall(() => ({ status: 'OK', timestamp: new Date().toISOString() }));
