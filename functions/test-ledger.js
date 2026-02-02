/**
 * Test Ledger System (Mock) Step A8.3
 */

const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8081';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9098';

admin.initializeApp({ projectId: 'jayple-app-2026' });

const db = admin.firestore();
const auth = admin.auth();

async function runTest() {
    console.log('🧪 Testing Ledger System (Step A8.3)\n');

    const cityId = 'trichy';
    const homeServiceId = 'svc_led_home';
    const custUid = 'cust_led';
    const flUid = 'fl_led';

    // Setup
    try { await auth.createUser({ uid: custUid, email: 'cust_led@test.com', password: 'password123' }); } catch (e) { }
    try { await auth.createUser({ uid: flUid, email: 'fl_led@test.com', password: 'password123' }); } catch (e) { }

    await db.doc(`users/${custUid}`).set({ activeRole: 'customer', cityId });
    await db.doc(`users/${flUid}`).set({ activeRole: 'freelancer', cityId, userId: flUid });

    await db.doc(`cities/${cityId}/services/${homeServiceId}`).set({ name: 'Ledger Cut', category: 'haircut', type: 'home', price: 1000 });

    await db.doc(`cities/${cityId}/freelancers/${flUid}`).set({
        userId: flUid, priorityTier: 'gold', isOnline: true, status: 'active',
        serviceCategories: ['haircut'], lastActiveAt: admin.firestore.Timestamp.now()
    });

    const custToken = await fetchAuthToken('cust_led@test.com');
    const flToken = await fetchAuthToken('fl_led@test.com');

    // TEST 1
    console.log('🔍 Test 1: Complete Booking -> Ledger Entries');
    let b1 = await createBooking(custToken, cityId, homeServiceId, 'home');
    await respond(flToken, b1.bookingId, cityId, 'ACCEPT');
    await authorize(custToken, b1.bookingId, cityId);
    await complete(flToken, b1.bookingId, cityId);

    const snap1 = await db.collection('ledger').where('userId', '==', flUid).orderBy('createdAt', 'asc').get();
    if (snap1.size !== 2) throw new Error(`Expected 2 ledger entries, got ${snap1.size}`);

    const e1 = snap1.docs[0].data(); // Earning (Oldest)
    const e2 = snap1.docs[1].data(); // Comm (Newest)

    if (e1.entryType !== 'EARNING') throw new Error(`Expected EARNING, got ${e1.entryType}`);
    if (e2.entryType !== 'COMMISSION') throw new Error(`Expected COMMISSION, got ${e2.entryType}`);

    if (e1.balanceAfter !== 1000) throw new Error(`Expected 1000, got ${e1.balanceAfter}`);
    if (e2.balanceAfter !== 900) throw new Error(`Expected 900, got ${e2.balanceAfter}`);

    console.log('   ✓ Ledger Entries Correct (Balance: 900)');

    // TEST 2
    console.log('\n🔍 Test 2: Idempotency (Re-run Complete)');
    try { await complete(flToken, b1.bookingId, cityId); } catch (e) { }
    const snap2 = await db.collection('ledger').where('userId', '==', flUid).get();
    if (snap2.size !== 2) throw new Error('Duplicates found!');
    console.log('   ✓ No Duplicates');

    // TEST 3
    console.log('\n🔍 Test 3: Second Booking (Chain Balance)');
    let b2 = await createBooking(custToken, cityId, homeServiceId, 'home');
    await respond(flToken, b2.bookingId, cityId, 'ACCEPT');
    await authorize(custToken, b2.bookingId, cityId);
    await complete(flToken, b2.bookingId, cityId);

    const snap3 = await db.collection('ledger').where('userId', '==', flUid).orderBy('createdAt', 'asc').get();
    if (snap3.size !== 4) throw new Error(`Expected 4 entries, got ${snap3.size}`);

    const e3 = snap3.docs[2].data();
    const e4 = snap3.docs[3].data();

    if (e3.balanceAfter !== 1900) throw new Error(`Expected 1900, got ${e3.balanceAfter}`);
    if (e4.balanceAfter !== 1800) throw new Error(`Expected 1800, got ${e4.balanceAfter}`);

    console.log('   ✓ Balance Chaining Correct (Balance: 1800)');

    // TEST 4
    console.log('\n🔍 Test 4: Refund First Booking');

    await cancel(custToken, b1.bookingId, cityId);

    // Wait a brief moment for async trigger? No, it's transactional.

    const snap4 = await db.collection('ledger').where('userId', '==', flUid).orderBy('createdAt', 'asc').get();

    if (snap4.size !== 5) throw new Error(`Expected 5 entries, got ${snap4.size}`);

    const e5 = snap4.docs[4].data();
    if (e5.entryType !== 'REFUND') throw new Error(`Expected REFUND, got ${e5.entryType}`);
    if (e5.balanceAfter !== 800) throw new Error(`Expected 800, got ${e5.balanceAfter}`);

    console.log('   ✓ Refund Ledger Entry Correct (Final Balance: 800)');
    console.log('\n✅ Ledger Tests Passed!');
    process.exit(0);
}

// Helpers
async function fetchAuthToken(email) {
    const res = await fetch('http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: 'password123', returnSecureToken: true })
    });
    return (await res.json()).idToken;
}
async function createBooking(token, cityId, serviceId, type) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { type, cityId, serviceId, scheduledAt: Date.now() + 100000 } })
    });
    return (await res.json()).result;
}
async function respond(token, bookingId, cityId, action) {
    await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/freelancerRespondToBooking', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId, action } })
    });
}
async function authorize(token, bookingId, cityId) {
    await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/authorizePayment', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId } })
    });
}
async function complete(token, bookingId, cityId) {
    await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/completeBooking', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId } })
    });
}
async function cancel(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/cancelBooking', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId } })
    });
    if (res.status !== 200) {
        const json = await res.json();
        console.error('Cancel Failed:', JSON.stringify(json, null, 2));
        throw new Error('cancelBooking failed');
    }
}
async function getBooking(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/getBookingById', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId } })
    });
    return (await res.json()).result.booking;
}

runTest();
