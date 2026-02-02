/**
 * Test Refunds and Failures (Mock) Step A8.2
 */

const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8081';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9098';

admin.initializeApp({ projectId: 'jayple-app-2026' });

const db = admin.firestore();
const auth = admin.auth();

async function runTest() {
    console.log('🧪 Testing Refunds & Failures (Step A8.2)\n');

    const cityId = 'trichy';
    const homeServiceId = 'svc_pay_home';
    const custUid = 'cust_ref';
    const flUid = 'fl_ref';

    // Setup
    try { await auth.createUser({ uid: custUid, email: 'cust_ref@test.com', password: 'password123' }); } catch (e) { }
    try { await auth.createUser({ uid: flUid, email: 'fl_ref@test.com', password: 'password123' }); } catch (e) { }

    await db.doc(`users/${custUid}`).set({ activeRole: 'customer', cityId });
    await db.doc(`users/${flUid}`).set({ activeRole: 'freelancer', cityId, userId: flUid });

    // Services & Freelancer
    await db.doc(`cities/${cityId}/services/${homeServiceId}`).set({ name: 'Home Cut', category: 'haircut', type: 'home', price: 500 });
    await db.doc(`cities/${cityId}/freelancers/${flUid}`).set({
        userId: flUid, priorityTier: 'gold', isOnline: true, status: 'active',
        serviceCategories: ['haircut'], lastActiveAt: admin.firestore.Timestamp.now()
    });

    const custToken = await fetchAuthToken('cust_ref@test.com');
    const flToken = await fetchAuthToken('fl_ref@test.com');

    // TEST 1: Fail Payment (Auth -> Failed)
    console.log('🔍 Test 1: failPayment (Auth -> Failed)');
    let b1 = await createBooking(custToken, cityId, homeServiceId, 'home');
    await respond(flToken, b1.bookingId, cityId, 'ACCEPT');
    await authorize(custToken, b1.bookingId, cityId);

    // Fail it
    await failPayment(custToken, b1.bookingId, cityId); // Using Cust Token as "System" for mock
    let d1 = await getBooking(custToken, b1.bookingId, cityId);
    if (d1.status !== 'FAILED') throw new Error(`Expected FAILED, got ${d1.status}`);
    if (d1.payment.status !== 'FAILED') throw new Error(`Expected Payment FAILED, got ${d1.payment.status}`);
    console.log('   ✓ Payment Failed Correctly');

    // TEST 2: Cancel Authorized (No Refund)
    console.log('\n🔍 Test 2: Cancel Authorized (No Refund)');
    let b2 = await createBooking(custToken, cityId, homeServiceId, 'home');
    await respond(flToken, b2.bookingId, cityId, 'ACCEPT');
    await authorize(custToken, b2.bookingId, cityId);

    await cancel(custToken, b2.bookingId, cityId);
    let d2 = await getBooking(custToken, b2.bookingId, cityId);
    if (d2.status !== 'CANCELLED') throw new Error(`Expected CANCELLED, got ${d2.status}`);
    if (d2.payment.status !== 'AUTHORIZED') throw new Error(`Expected AUTHORIZED, got ${d2.payment.status}`);
    console.log('   ✓ Cancelled without Refund (Correct)');

    // TEST 3: Cancel Completed (Refund)
    console.log('\n🔍 Test 3: Cancel Completed (Refund)');
    let b3 = await createBooking(custToken, cityId, homeServiceId, 'home');
    await respond(flToken, b3.bookingId, cityId, 'ACCEPT');
    await authorize(custToken, b3.bookingId, cityId);
    await complete(flToken, b3.bookingId, cityId);

    await cancel(custToken, b3.bookingId, cityId);
    let d3 = await getBooking(custToken, b3.bookingId, cityId);
    if (d3.status !== 'CANCELLED') throw new Error(`Expected CANCELLED, got ${d3.status}`);
    if (d3.payment.status !== 'REFUNDED') throw new Error(`Expected REFUNDED, got ${d3.payment.status}`);
    if (!d3.payment.providerRef.startsWith('MOCK_REFUND')) throw new Error('Missing Refund Ref');
    console.log('   ✓ Cancelled with refund (Correct)');

    console.log('\n✅ Refund/Failure Tests Passed!');
    process.exit(0);
}

// Helpers (Same as test-payment.js but included here for self-containment)
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
async function failPayment(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/failPayment', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId } })
    });
    if (res.status !== 200) { try { console.error(await res.json()); } catch (e) { } throw new Error('failPayment failed'); }
}
async function cancel(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/cancelBooking', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId } })
    });
    if (res.status !== 200) throw new Error('cancelBooking failed');
}
async function getBooking(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/getBookingById', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId } })
    });
    return (await res.json()).result.booking;
}

runTest();
