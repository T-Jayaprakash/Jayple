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
// PAYMENT FUNCTIONS & HELPERS
// ============================================

async function capturePayment(transaction, bookingRef, bookingData) {
    const payment = bookingData.payment;
    if (!payment || payment.status !== 'AUTHORIZED') return;

    const now = Timestamp.now();
    const newPayment = {
        ...payment,
        status: 'CAPTURED',
        updatedAt: now
    };

    transaction.update(bookingRef, { payment: newPayment });

    const eventRef = bookingRef.collection('status_events').doc();
    transaction.set(eventRef, {
        from: 'PAYMENT_AUTHORIZED', to: 'PAYMENT_CAPTURED', actor: 'system', timestamp: now
    });
}

// ============================================
// LEDGER HELPERS
// ============================================

async function getLedgerInfo(t, userId) {
    const snap = await t.get(db.collection('ledger').where('userId', '==', userId).orderBy('createdAt', 'desc').limit(1));
    if (snap.empty) return { balance: 0 };
    return { balance: snap.docs[0].data().balanceAfter };
}

function writeLedgerEntry(t, ref, data) {
    t.set(ref, data);
}

// ============================================

async function processRefund(transaction, bookingRef, bookingData) {
    const payment = bookingData.payment;
    if (payment.status !== 'CAPTURED') throw new functions.https.HttpsError('failed-precondition', 'Payment not CAPTURED');
    if (payment.mode === 'OFFLINE') throw new functions.https.HttpsError('failed-precondition', 'Cannot refund OFFLINE');

    const now = Timestamp.now();

    // Ledger Logic: Refund (Must Read First)
    const providerId = bookingData.freelancerId || bookingData.salonId;
    const providerType = bookingData.freelancerId ? 'freelancer' : 'vendor';

    const refundId = `${bookingData.bookingId}_REFUND`;
    const refundRef = db.collection('ledger').doc(refundId);

    const ledgerSnap = await transaction.get(db.collection('ledger').where('userId', '==', providerId).orderBy('createdAt', 'desc').limit(1));
    const refundDoc = await transaction.get(refundRef);

    let currentBalance = 0;
    if (!ledgerSnap.empty) currentBalance = ledgerSnap.docs[0].data().balanceAfter;

    const amount = bookingData.payment.amount; // Refund Full Amount

    // Write Ledger
    if (!refundDoc.exists) {
        const newBalance = currentBalance - amount; // Debit
        transaction.set(refundRef, {
            ledgerId: refundId,
            userId: providerId,
            userType: providerType,
            bookingId: bookingData.bookingId,
            entryType: 'REFUND',
            direction: 'DEBIT',
            amount: amount,
            paymentMode: payment.mode,
            paymentStatusAtEvent: 'REFUNDED',
            balanceBefore: currentBalance,
            balanceAfter: newBalance,
            idempotencyKey: refundId,
            metadata: { triggeredBy: 'system', reason: 'Refund' },
            createdAt: now
        });
    }

    // Write Payment Update
    const newPayment = {
        ...payment,
        status: 'REFUNDED',
        providerRef: `MOCK_REFUND_${now.toMillis()}`,
        updatedAt: now
    };

    transaction.update(bookingRef, { payment: newPayment });

    const eventRef = bookingRef.collection('status_events').doc();
    transaction.set(eventRef, {
        from: 'PAYMENT_CAPTURED', to: 'PAYMENT_REFUNDED', actor: 'system', timestamp: now
    });
}

exports.authorizePayment = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId } = data;
    const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);

    try {
        await db.runTransaction(async (t) => {
            const doc = await t.get(bookingRef);
            if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Not found');
            const d = doc.data();

            if (d.customerId !== uid) throw new functions.https.HttpsError('permission-denied', 'Not yours');
            if (d.status !== 'CONFIRMED') throw new functions.https.HttpsError('failed-precondition', 'Must be CONFIRMED');

            const payment = d.payment || {};
            if (payment.mode !== 'ONLINE') throw new functions.https.HttpsError('failed-precondition', 'Not ONLINE');
            if (payment.status !== 'PENDING') throw new functions.https.HttpsError('failed-precondition', `Status ${payment.status}`);

            const now = Timestamp.now();
            const newPayment = {
                ...payment,
                status: 'AUTHORIZED',
                providerRef: `MOCK_AUTH_${now.toMillis()}`,
                updatedAt: now
            };

            t.update(bookingRef, { payment: newPayment });

            const eventRef = bookingRef.collection('status_events').doc();
            t.set(eventRef, {
                from: 'PAYMENT_PENDING', to: 'PAYMENT_AUTHORIZED', actor: 'customer', timestamp: now
            });
        });
        return { bookingId, paymentStatus: 'AUTHORIZED' };
    } catch (e) {
        if (e instanceof functions.https.HttpsError) throw e;
        throw new functions.https.HttpsError('internal', e.message);
    }
});

exports.failPayment = functions.https.onCall(async (data, context) => {
    requireAuth(context);
    const { bookingId, cityId } = data;
    const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);

    try {
        await db.runTransaction(async (t) => {
            const doc = await t.get(bookingRef);
            if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Not found');
            const d = doc.data();
            const payment = d.payment;

            if (d.status === 'COMPLETED') throw new functions.https.HttpsError('failed-precondition', 'Booking COMPLETED');
            if (payment.mode === 'OFFLINE') throw new functions.https.HttpsError('failed-precondition', 'OFFLINE payment');
            if (payment.status !== 'AUTHORIZED') throw new functions.https.HttpsError('failed-precondition', 'Not AUTHORIZED');
            if (payment.status === 'CAPTURED') throw new functions.https.HttpsError('failed-precondition', 'Already CAPTURED');

            const now = Timestamp.now();
            const newPayment = {
                ...payment,
                status: 'FAILED',
                updatedAt: now
            };

            t.update(bookingRef, { status: 'FAILED', failureReason: 'PAYMENT_FAILED', payment: newPayment, updatedAt: now });

            t.set(bookingRef.collection('status_events').doc(), {
                from: 'PAYMENT_AUTHORIZED', to: 'PAYMENT_FAILED', actor: 'system', timestamp: now
            });
            t.set(bookingRef.collection('status_events').doc(), {
                from: d.status, to: 'FAILED', actor: 'system', reason: 'PAYMENT_FAILED', timestamp: now
            });
        });
        return { status: 'FAILED', paymentStatus: 'FAILED' };
    } catch (e) {
        if (e instanceof functions.https.HttpsError) throw e;
        throw new functions.https.HttpsError('internal', e.message);
    }
});

exports.refundPayment = functions.https.onCall(async (data, context) => {
    requireAuth(context);
    const { bookingId, cityId } = data;
    const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);

    try {
        await db.runTransaction(async (t) => {
            const doc = await t.get(bookingRef);
            if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Not found');
            const d = doc.data();

            if (!['CANCELLED', 'FAILED'].includes(d.status)) throw new functions.https.HttpsError('failed-precondition', 'Booking must be CANCELLED or FAILED');

            await processRefund(t, bookingRef, d);
        });
        return { paymentStatus: 'REFUNDED' };
    } catch (e) {
        if (e instanceof functions.https.HttpsError) throw e;
        throw new functions.https.HttpsError('internal', e.message);
    }
});


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
    const serviceData = serviceDoc.data();
    const serviceCategory = serviceData.category;
    const price = serviceData.price || 0;

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

    const paymentMode = type === 'home' ? 'ONLINE' : 'OFFLINE';
    const paymentStatus = paymentMode === 'ONLINE' ? 'PENDING' : 'NOT_REQUIRED';

    const bookingData = {
        bookingId, customerId: uid, type, serviceId, serviceCategory, cityId,
        scheduledAt: scheduledTimestamp, status: 'CREATED', idempotencyKey: idempotencyKey || null,
        createdAt: now, updatedAt: now, assignmentAttempts: [],
        payment: {
            mode: paymentMode,
            status: paymentStatus,
            amount: price,
            currency: 'INR',
            provider: 'MOCK',
            providerRef: null,
            updatedAt: now
        }
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
        scheduledAt: d.scheduledAt?.toDate?.().toISOString(), createdAt: d.createdAt?.toDate?.().toISOString(),
        payment: d.payment
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
            scheduledAt: d.scheduledAt?.toDate?.().toISOString(), createdAt: d.createdAt?.toDate?.().toISOString(),
            payment: d.payment
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

            let replacementResult = null;
            if (action === 'REJECT') {
                replacementResult = await findReplacement(t, d);
            }

            const now = Timestamp.now();

            if (action === 'ACCEPT') {
                t.update(bookingRef, { status: 'CONFIRMED', updatedAt: now });
                t.set(bookingRef.collection('status_events').doc(), {
                    from: 'ASSIGNED', to: 'CONFIRMED', actor: 'freelancer', actorId: uid, timestamp: now
                });
                return { status: 'CONFIRMED' };
            } else {
                t.set(bookingRef.collection('status_events').doc(), {
                    from: 'ASSIGNED', to: 'REJECTED', actor: 'freelancer', actorId: uid, timestamp: now
                });
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

exports.completeBooking = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId } = data;
    const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);

    try {
        await db.runTransaction(async (t) => {
            const doc = await t.get(bookingRef);
            if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Not found');
            const d = doc.data();

            if (d.freelancerId !== uid && d.vendorId !== uid && d.salonId !== uid)
                throw new functions.https.HttpsError('permission-denied', 'Denied');

            if (d.status !== 'CONFIRMED' && d.status !== 'IN_PROGRESS')
                throw new functions.https.HttpsError('failed-precondition', `Invalid status ${d.status}`);

            const now = Timestamp.now();

            // Ledger Logic: Earning & Commission checks (Must Read First)
            const providerId = d.freelancerId || d.salonId;
            const providerType = d.freelancerId ? 'freelancer' : 'vendor';
            const amount = d.payment ? d.payment.amount : 0; // Or fetch service price if payment obj missing (offline)
            // Note: If OFFLINE, payment obj exists with amount.

            const earningId = `${bookingId}_EARNING`;
            const commId = `${bookingId}_COMMISSION`;

            const earningRef = db.collection('ledger').doc(earningId);
            const commRef = db.collection('ledger').doc(commId);
            const ledgerSnap = await t.get(db.collection('ledger').where('userId', '==', providerId).orderBy('createdAt', 'desc').limit(1));

            const earningDoc = await t.get(earningRef);
            // const commDoc = await t.get(commRef);

            // Writes
            t.update(bookingRef, { status: 'COMPLETED', updatedAt: now });
            t.set(bookingRef.collection('status_events').doc(), {
                from: d.status, to: 'COMPLETED', actor: 'provider', actorId: uid, timestamp: now
            });

            // Write Ledger Entries
            let currentBalance = 0;
            if (!ledgerSnap.empty) currentBalance = ledgerSnap.docs[0].data().balanceAfter;

            if (!earningDoc.exists && amount > 0) {
                const balanceAfterEarning = currentBalance + amount;
                t.set(earningRef, {
                    ledgerId: earningId, userId: providerId, userType: providerType, bookingId,
                    entryType: 'EARNING', direction: 'CREDIT', amount,
                    paymentMode: d.payment.mode, paymentStatusAtEvent: 'CAPTURED', // Assumed captured/settled
                    balanceBefore: currentBalance, balanceAfter: balanceAfterEarning,
                    idempotencyKey: earningId, metadata: { triggeredBy: 'system' }, createdAt: now
                });
                currentBalance = balanceAfterEarning;

                const commAmount = amount * 0.10; // 10%
                const balanceAfterComm = currentBalance - commAmount;

                // Ensure sequence for ordering
                const commTime = new Timestamp(now.seconds, now.nanoseconds + 1000);

                t.set(commRef, {
                    ledgerId: commId, userId: providerId, userType: providerType, bookingId,
                    entryType: 'COMMISSION', direction: 'DEBIT', amount: commAmount,
                    paymentMode: d.payment.mode, paymentStatusAtEvent: 'CAPTURED',
                    balanceBefore: currentBalance, balanceAfter: balanceAfterComm,
                    idempotencyKey: commId, metadata: { triggeredBy: 'system' }, createdAt: commTime
                });
            }

            if (d.payment && d.payment.mode === 'ONLINE' && d.payment.status === 'AUTHORIZED') {
                await capturePayment(t, bookingRef, d);
            }
        });
        return { status: 'COMPLETED' };
    } catch (e) {
        if (e instanceof functions.https.HttpsError) throw e;
        throw new functions.https.HttpsError('internal', e.message);
    }
});

exports.cancelBooking = functions.https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const { bookingId, cityId } = data;
    const bookingRef = db.doc(`cities/${cityId}/bookings/${bookingId}`);

    try {
        await db.runTransaction(async (t) => {
            const doc = await t.get(bookingRef);
            if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Not found');
            const d = doc.data();

            if (d.customerId !== uid) throw new functions.https.HttpsError('permission-denied', 'Not yours');

            if (['FAILED', 'CANCELLED'].includes(d.status)) throw new functions.https.HttpsError('failed-precondition', 'Cannot cancel final state');

            const now = Timestamp.now();

            // Refund Check First (Reads must come before Writes)
            const payment = d.payment;
            if (payment && payment.mode === 'ONLINE') {
                if (payment.status === 'CAPTURED') {
                    await processRefund(t, bookingRef, d);
                }
            }

            t.update(bookingRef, { status: 'CANCELLED', updatedAt: now });
            t.set(bookingRef.collection('status_events').doc(), {
                from: d.status, to: 'CANCELLED', actor: 'customer', actorId: uid, timestamp: now
            });
        });
        return { status: 'CANCELLED' };
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
                const now = Timestamp.now();
                t.set(bookingRef.collection('status_events').doc(), { from: 'ASSIGNED', to: 'TIMEOUT', actor: 'system', timestamp: now });
                writeReassignment(t, bookingRef, d, replacementResult, now);
            }
        });

        const outputDoc = await bookingRef.get();
        if (outputDoc.exists && outputDoc.data().status === 'ASSIGNED') await enqueueAssignmentTimeout(bookingId, cityId);
    } catch (e) { }
});

exports.acceptBooking = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.submitReview = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.switchRole = functions.https.onCall(() => ({ status: 'NOT_IMPLEMENTED' }));
exports.healthCheck = functions.https.onCall(() => ({ status: 'OK', timestamp: new Date().toISOString() }));
