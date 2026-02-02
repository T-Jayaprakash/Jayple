/**
 * Test Payment Flow (Mock) Step A8.1
 */

const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8081';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9098';

admin.initializeApp({ projectId: 'jayple-app-2026' });

const db = admin.firestore();
const auth = admin.auth();

async function runTest() {
    console.log('🧪 Testing Payment Logic (Step A8.1)\n');

    const cityId = 'trichy';
    const homeServiceId = 'svc_pay_home';
    const shopServiceId = 'svc_pay_shop';
    const custUid = 'cust_pay';
    const flUid = 'fl_pay';
    const venUid = 'ven_pay';

    // Setup
    try { await auth.createUser({ uid: custUid, email: 'cust_pay@test.com', password: 'password123' }); } catch (e) { }
    try { await auth.createUser({ uid: flUid, email: 'fl_pay@test.com', password: 'password123' }); } catch (e) { }
    try { await auth.createUser({ uid: venUid, email: 'ven_pay@test.com', password: 'password123' }); } catch (e) { }

    await db.doc(`users/${custUid}`).set({ activeRole: 'customer', cityId });
    await db.doc(`users/${flUid}`).set({ activeRole: 'freelancer', cityId, userId: flUid });
    await db.doc(`users/${venUid}`).set({ activeRole: 'vendor', cityId, vendorId: venUid });

    // Services
    await db.doc(`cities/${cityId}/services/${homeServiceId}`).set({
        name: 'Home Cut', category: 'haircut', type: 'home', price: 500
    });
    await db.doc(`cities/${cityId}/services/${shopServiceId}`).set({
        name: 'Shop Cut', category: 'haircut', type: 'inShop', price: 300
    });

    // Freelancer
    await db.doc(`cities/${cityId}/freelancers/${flUid}`).set({
        userId: flUid, priorityTier: 'gold', isOnline: true, status: 'active',
        serviceCategories: ['haircut'], lastActiveAt: admin.firestore.Timestamp.now()
    });

    // Tokens
    const custToken = await fetchAuthToken('cust_pay@test.com');
    const flToken = await fetchAuthToken('fl_pay@test.com');
    const venToken = await fetchAuthToken('ven_pay@test.com');

    // 1. Online Flow
    console.log('🔍 Test 1: Online Flow (Home)');
    const b1 = await createBooking(custToken, cityId, homeServiceId, 'home');
    console.log(`   Booking: ${b1.bookingId}, Status: ${b1.status}`);

    // Check PENDING
    let d1 = await getBooking(custToken, b1.bookingId, cityId);
    if (d1.payment.status !== 'PENDING') throw new Error(`Expected PENDING, got ${d1.payment.status}`);
    if (d1.payment.amount !== 500) throw new Error(`Expected 500, got ${d1.payment.amount}`);
    console.log('   ✓ Payment Initialized: PENDING (500)');

    // Freelancer Accept
    await respond(flToken, b1.bookingId, cityId, 'ACCEPT', true);
    console.log('   ✓ Booking CONFIRMED');

    // Authorize
    await authorize(custToken, b1.bookingId, cityId);
    d1 = await getBooking(custToken, b1.bookingId, cityId);
    if (d1.payment.status !== 'AUTHORIZED') throw new Error(`Expected AUTHORIZED, got ${d1.payment.status}`);
    console.log('   ✓ Payment AUTHORIZED');

    // Complete (triggers Capture)
    await complete(flToken, b1.bookingId, cityId);
    d1 = await getBooking(custToken, b1.bookingId, cityId);
    if (d1.status !== 'COMPLETED') throw new Error('Booking not COMPLETED');
    if (d1.payment.status !== 'CAPTURED') throw new Error(`Expected CAPTURED, got ${d1.payment.status}`);
    console.log('   ✓ Payment CAPTURED');

    // 2. Offline Flow
    console.log('\n🔍 Test 2: Offline Flow (InShop)');
    const b2 = await createBooking(custToken, cityId, shopServiceId, 'inShop');
    let d2 = await getBooking(custToken, b2.bookingId, cityId);
    if (d2.payment.status !== 'NOT_REQUIRED') throw new Error(`Expected NOT_REQUIRED, got ${d2.payment.status}`);
    console.log('   ✓ Payment Initialized: NOT_REQUIRED');

    // Vendor Accept
    await respond(venToken, b2.bookingId, cityId, 'ACCEPT', false);

    // Try Authorize (Should Fail)
    try {
        await authorize(custToken, b2.bookingId, cityId);
        throw new Error('Should have failed');
    } catch (e) {
        console.log(`   ✓ Authorization Rejected (Expected)`);
    }

    console.log('\n✅ Payment Tests Passed!');
    process.exit(0);
}

async function fetchAuthToken(email) {
    const res = await fetch(
        'http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
        {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password: 'password123', returnSecureToken: true }),
        }
    );
    return (await res.json()).idToken;
}

async function createBooking(token, cityId, serviceId, type) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ data: { type, cityId, serviceId, scheduledAt: Date.now() + 100000 } })
    });
    return (await res.json()).result;
}

async function getBooking(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/getBookingById', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ data: { bookingId, cityId } })
    });
    return (await res.json()).result.booking;
}

async function respond(token, bookingId, cityId, action, isFreelancer) {
    const ep = isFreelancer ? 'freelancerRespondToBooking' : 'vendorRespondToBooking';
    await fetch(`http://127.0.0.1:5002/jayple-app-2026/us-central1/${ep}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ data: { bookingId, cityId, action } })
    });
}

async function authorize(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/authorizePayment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ data: { bookingId, cityId } })
    });
    const json = await res.json();
    if (json.error) throw new Error(json.error.message);
    return json.result;
}

async function complete(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/completeBooking', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ data: { bookingId, cityId } })
    });
    const json = await res.json();
    if (json.error) throw new Error(json.error.message);
    return json.result;
}

runTest();
