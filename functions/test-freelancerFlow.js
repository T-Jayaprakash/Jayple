/**
 * Test script for Freelancer Response & Timeout (Phase A7.2.1)
 */

const admin = require('firebase-admin');

// Initialize with emulator settings
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8081';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9098';

admin.initializeApp({
    projectId: 'jayple-app-2026',
});

const db = admin.firestore();
const auth = admin.auth();

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function runTest() {
    console.log('🧪 Testing Freelancer Response & Timeout\n');
    console.log('='.repeat(50));

    try {
        // Setup
        const customerUid = 'test-cust-flow';
        const freelancerUid = 'f_flow_test';
        const cityId = 'trichy';
        const serviceId = 'haircut_home_flow';

        console.log('\n📱 Setting up test environment...');

        // Create Users & Service
        try { await auth.deleteUser(customerUid); } catch (e) { }
        try { await auth.deleteUser(freelancerUid); } catch (e) { }

        await auth.createUser({ uid: customerUid, email: 'cflow@test.com', password: 'password123' });
        await auth.createUser({ uid: freelancerUid, email: 'fflow@test.com', password: 'password123' });

        await db.doc(`users/${customerUid}`).set({ activeRole: 'customer', cityId });
        await db.doc(`users/${freelancerUid}`).set({
            userId: freelancerUid, activeRole: 'freelancer', cityId,
            salonId: null, vendorId: null
        });

        await db.doc(`cities/${cityId}/services/${serviceId}`).set({
            name: 'Home Flow Cut', category: 'haircut', type: 'home', price: 600
        });

        // Setup Freelancer
        await db.doc(`cities/${cityId}/freelancers/${freelancerUid}`).set({
            userId: freelancerUid,
            priorityTier: 'gold',
            isOnline: true,
            status: 'active',
            serviceCategories: ['haircut'],
            lastActiveAt: admin.firestore.Timestamp.now(), // Very recent
        });

        console.log('   ✓ Users & Service created');

        // Get Tokens
        const custSignIn = await fetchAuthToken('cflow@test.com');
        const freeSignIn = await fetchAuthToken('fflow@test.com');

        // ---------------------------------------------------------
        // Test 1: Freelancer ACCEPT
        // ---------------------------------------------------------
        console.log('\n🔍 Test 1: Freelancer ACCEPT Flow');
        const b1 = await createBooking(custSignIn, cityId, serviceId, 'test_flow_1');

        if (b1.status !== 'ASSIGNED') throw new Error(`Booking 1 failed: ${b1.status}`);
        console.log(`   Booking created: ${b1.bookingId} (ASSIGNED to ${freelancerUid})`);

        // Respond ACCEPT
        const res1 = await callFunction('freelancerRespondToBooking', freeSignIn, {
            bookingId: b1.bookingId,
            cityId,
            action: 'ACCEPT'
        });

        if (res1.result && res1.result.status === 'CONFIRMED') {
            console.log('   ✓ Freelancer ACCEPTED -> CONFIRMED');
        } else {
            console.log('   ✗ Failed to ACCEPT:', res1);
        }

        // ---------------------------------------------------------
        // Test 2: Freelancer REJECT
        // ---------------------------------------------------------
        console.log('\n🔍 Test 2: Freelancer REJECT Flow');
        const b2 = await createBooking(custSignIn, cityId, serviceId, 'test_flow_2');
        console.log(`   Booking created: ${b2.bookingId}`);

        // Respond REJECT
        const res2 = await callFunction('freelancerRespondToBooking', freeSignIn, {
            bookingId: b2.bookingId,
            cityId,
            action: 'REJECT'
        });

        if (res2.result && res2.result.status === 'REJECTED') {
            console.log('   ✓ Freelancer REJECTED -> REJECTED');
        } else {
            console.log('   ✗ Failed to REJECT:', res2);
        }

        // ---------------------------------------------------------
        // Test 3: Timeout (Wait 35s)
        // ---------------------------------------------------------
        console.log('\n🔍 Test 3: Timeout Flow (Waiting 35s...)');
        const b3 = await createBooking(custSignIn, cityId, serviceId, 'test_flow_3');
        console.log(`   Booking created: ${b3.bookingId} (Waiting...)`);

        await sleep(35000); // Wait for timeout

        // Check verification (TIMEOUT event)
        const eventsSnap = await db.collection(`cities/${cityId}/bookings/${b3.bookingId}/status_events`)
            .orderBy('timestamp', 'desc')
            .get();

        const events = eventsSnap.docs.map(d => d.data());
        const timeoutEvent = events.find(e => e.to === 'TIMEOUT');

        if (timeoutEvent) {
            console.log('   ✓ Found TIMEOUT event:', timeoutEvent);
        } else {
            console.log('   ✗ TIMEOUT event NOT found. Events:', events);
        }

        // Verify Status is still ASSIGNED (per requirements)
        const doc3 = await db.doc(`cities/${cityId}/bookings/${b3.bookingId}`).get();
        console.log(`   Final Booking Status: ${doc3.data().status}`);
        if (doc3.data().status === 'ASSIGNED') {
            console.log('   ✓ Status remained ASSIGNED (Correct per requirements)');
        }

        console.log('\n' + '='.repeat(50));
        console.log('✅ All tests completed!');

    } catch (error) {
        console.error('\n❌ Test failed:', error);
    }
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

async function createBooking(token, cityId, serviceId, key) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({
            data: {
                type: 'home',
                cityId,
                serviceId,
                scheduledAt: Date.now() + 100000,
                idempotencyKey: key
            }
        })
    });
    const json = await res.json();
    return json.result;
}

async function callFunction(name, token, data) {
    const res = await fetch(`http://127.0.0.1:5002/jayple-app-2026/us-central1/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ data })
    });
    return await res.json();
}

runTest();
