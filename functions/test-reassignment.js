/**
 * Test script for Freelancer Reassignment (Phase A7.2.2)
 */

const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8081';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9098';

admin.initializeApp({ projectId: 'jayple-app-2026' });

const db = admin.firestore();
const auth = admin.auth();

async function runTest() {
    console.log('🧪 Testing Reassignment Logic\n');

    const cityId = 'trichy';
    const serviceId = 'haircut_reassign';
    const custUid = 'test-cust-ra';

    // Create Users
    try {
        await auth.createUser({ uid: custUid, email: 'cra@test.com', password: 'password123' });
    } catch (e) { }
    await db.doc(`users/${custUid}`).set({ activeRole: 'customer', cityId });

    // Create Service
    await db.doc(`cities/${cityId}/services/${serviceId}`).set({
        name: 'Reassign Cut', category: 'haircut', type: 'home', price: 500
    });

    // Create 3 Freelancers
    const flIds = ['f_gold', 'f_silver', 'f_bronze'];
    const tiers = ['gold', 'silver', 'bronze'];

    for (let i = 0; i < 3; i++) {
        const uid = flIds[i];
        try { await auth.createUser({ uid, email: `${uid}@test.com`, password: 'password123' }); } catch (e) { }
        await db.doc(`users/${uid}`).set({ activeRole: 'freelancer', cityId, userId: uid });
        await db.doc(`cities/${cityId}/freelancers/${uid}`).set({
            userId: uid,
            priorityTier: tiers[i],
            isOnline: true,
            status: 'active',
            serviceCategories: ['haircut'],
            lastActiveAt: admin.firestore.Timestamp.now()
        });
    }

    console.log('   ✓ Setup Complete (3 Freelancers)');

    // Tokens
    const custToken = await fetchAuthToken('cra@test.com');
    const fTokens = {};
    for (const id of flIds) fTokens[id] = await fetchAuthToken(`${id}@test.com`);

    // 1. Create Booking
    console.log('\n🔍 Step 1: Create Booking');
    const b1 = await createBooking(custToken, cityId, serviceId);
    console.log(`   Booking: ${b1.bookingId}, Status: ${b1.status}`);

    // Verify assigned to f_gold
    const doc1 = await db.doc(`cities/${cityId}/bookings/${b1.bookingId}`).get();
    const d1 = doc1.data();
    if (d1.freelancerId !== 'f_gold') throw new Error(`Expected f_gold, got ${d1.freelancerId}`);
    console.log('   ✓ Assigned to f_gold');

    // 2. Gold Rejects
    console.log('\n🔍 Step 2: f_gold Rejects');
    const res2 = await respond(fTokens['f_gold'], b1.bookingId, cityId, 'REJECT');
    console.log(`   Result: Status ${res2.status}`);

    // Check Reassignment
    const doc2 = await db.doc(`cities/${cityId}/bookings/${b1.bookingId}`).get();
    const d2 = doc2.data();
    console.log(`   New Freelancer: ${d2.freelancerId}`);
    console.log(`   Attempts: ${JSON.stringify(d2.assignmentAttempts)}`);

    if (d2.freelancerId !== 'f_silver') throw new Error(`Expected f_silver, got ${d2.freelancerId}`);
    if (d2.status !== 'ASSIGNED') throw new Error('Status should remain ASSIGNED');
    console.log('   ✓ Reassigned to f_silver');

    // 3. Silver Rejects
    console.log('\n🔍 Step 3: f_silver Rejects');
    const res3 = await respond(fTokens['f_silver'], b1.bookingId, cityId, 'REJECT');

    const doc3 = await db.doc(`cities/${cityId}/bookings/${b1.bookingId}`).get();
    const d3 = doc3.data();
    console.log(`   New Freelancer: ${d3.freelancerId}`);
    if (d3.freelancerId !== 'f_bronze') throw new Error(`Expected f_bronze, got ${d3.freelancerId}`);
    console.log('   ✓ Reassigned to f_bronze');

    // 4. Bronze Rejects (Should Fail - No replacement / Max Attempts logic)
    // We have 3 freelancers. We used f_gold, f_silver. Currently f_bronze.
    // If f_bronze rejects, excluded = [f_gold, f_silver, f_bronze].
    // No one left. Should Fail.
    console.log('\n🔍 Step 4: f_bronze Rejects (Expect Fail)');
    const res4 = await respond(fTokens['f_bronze'], b1.bookingId, cityId, 'REJECT');
    console.log(`   Result: ${JSON.stringify(res4)}`);

    const doc4 = await db.doc(`cities/${cityId}/bookings/${b1.bookingId}`).get();
    const d4 = doc4.data();
    console.log(`   Final Status: ${d4.status}`);
    console.log(`   Failure Reason: ${d4.failureReason}`);

    if (d4.status !== 'FAILED') throw new Error('Status should be FAILED');
    console.log('   ✓ Booking Failed correctly');

    console.log('\n✅ Reassignment Test Passed!');
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

async function createBooking(token, cityId, serviceId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({
            data: {
                type: 'home', cityId, serviceId, scheduledAt: Date.now() + 100000
            }
        })
    });
    return (await res.json()).result;
}

async function respond(token, bookingId, cityId, action) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/freelancerRespondToBooking', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ data: { bookingId, cityId, action } })
    });
    const json = await res.json();
    if (!json.result) {
        console.log('Error Response:', JSON.stringify(json, null, 2));
    }
    return json.result;
}

runTest();
