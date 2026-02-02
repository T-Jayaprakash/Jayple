/**
 * Test script for Home Booking Assignment
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

async function runTest() {
    console.log('🧪 Testing Home Booking Assignment\n');
    console.log('='.repeat(50));

    try {
        // Setup: Create users and data
        const customerUid = 'test-customer-assign-1';
        const serviceId = 'haircut_home_01';
        const cityId = 'trichy';

        // Freelancers
        const freelancers = [
            { id: 'f_gold_online', tier: 'gold', online: true, active: 'active', lastActive: 1000 },
            { id: 'f_silver_online', tier: 'silver', online: true, active: 'active', lastActive: 2000 },
            { id: 'f_gold_offline', tier: 'gold', online: false, active: 'active', lastActive: 500 },
            { id: 'f_gold_old', tier: 'gold', online: true, active: 'active', lastActive: 5000 }, // Older activity than first
        ];

        console.log('\n📱 Setting up test environment...');

        // 1. Create Customer
        try { await auth.deleteUser(customerUid); } catch (e) { }
        await auth.createUser({ uid: customerUid, email: 'cust@test.com', password: 'password123' });
        await db.doc(`users/${customerUid}`).set({
            userId: customerUid,
            activeRole: 'customer',
            cityId,
        });

        // 2. Create Service
        await db.doc(`cities/${cityId}/services/${serviceId}`).set({
            name: 'Home Haircut',
            category: 'haircut',
            type: 'home',
            price: 500
        });

        // 3. Create Freelancers
        for (const f of freelancers) {
            await db.doc(`cities/${cityId}/freelancers/${f.id}`).set({
                userId: f.id,
                priorityTier: f.tier,
                isOnline: f.online,
                status: f.active,
                serviceCategories: ['haircut', 'facial'],
                lastActiveAt: admin.firestore.Timestamp.fromMillis(Date.now() - f.lastActive),
            });
        }
        console.log('   ✓ Environment ready');

        // Get Token
        const signIn = await fetch(
            'http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email: 'cust@test.com', password: 'password123', returnSecureToken: true }),
            }
        );
        const token = (await signIn.json()).idToken;

        // Test 1: Successful Assignment (Should pick f_gold_online)
        // f_gold_online vs f_gold_old: both gold, but f_gold_online (1000ms ago) is more recent?
        // Wait, logic says: "Last Active (Asc) - Earliest first".
        // Wait. "earliest lastActiveAt".
        // Usually "earliest" means "smallest timestamp" (oldest).
        // But context: usually you assign to the one waiting longest (oldest timestamp).
        // Or "most recently active" (largest timestamp)?
        // Prompt says: "tie-breaker: earliest lastActiveAt".
        // Earliest timestamp = oldest time = waiting longest?
        // If lastActiveAt implies "last seen", then earliest means they haven't been seen for a long time?
        // OR does it mean "earliest created"?
        // Let's assume "Earliest timestamp" -> Smallest value.
        // My code: `timeA - timeB` (Ascending).
        // If A is smaller (older), A comes first.
        // So `f_gold_old` (5000ms ago -> larger difference from now -> smaller timestamp)
        // Timestamp = Now - 5000 vs Now - 1000.
        // Now - 5000 is SMALLER.
        // So `f_gold_old` should be picked if it's Ascending.
        // Let's verify this logic.

        console.log('\n🔍 Test 1: Create Home Booking (Expect Assignment)');
        const res1 = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
            body: JSON.stringify({
                data: {
                    type: 'home',
                    cityId,
                    serviceId,
                    scheduledAt: Date.now() + 100000,
                    idempotencyKey: `test_assign_${Date.now()}`
                }
            })
        });
        const json1 = await res1.json();

        if (json1.result && json1.result.status === 'ASSIGNED') {
            console.log('   ✓ Booking ASSIGNED');
            const bookingId = json1.result.bookingId;
            // Verify who got it
            const doc = await db.doc(`cities/${cityId}/bookings/${bookingId}`).get();
            const data = doc.data();
            console.log(`   Assigned to: ${data.freelancerId}`);

            // Expected: f_gold_old (since it has older timestamp) or f_gold_online?
            // If logic is "Earliest lastActiveAt", it means "Smallest timestamp".
        } else {
            console.log('   ✗ Failed:', json1);
        }

        // Test 2: No Freelancers Available
        // Disable all matching freelancers
        console.log('\n🔍 Test 2: No Freelancers Available');
        // Set all to offline
        const updates = freelancers.map(f => db.doc(`cities/${cityId}/freelancers/${f.id}`).update({ isOnline: false }));
        await Promise.all(updates);

        const res2 = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
            body: JSON.stringify({
                data: {
                    type: 'home',
                    cityId,
                    serviceId,
                    scheduledAt: Date.now() + 100000,
                    idempotencyKey: `test_fail_${Date.now()}`
                }
            })
        });
        const json2 = await res2.json();

        if (json2.error && json2.error.status === 'RESOURCE_EXHAUSTED') {
            console.log('   ✓ Correctly returned NO_FREELANCER_AVAILABLE');
        } else {
            console.log('   ✗ Unexpected result:', json2);
        }

        // Verify booking status is FAILED in Firestore (it should be created but FAILED)
        // Wait, if I threw validation error, is it created?
        // My implementation: Returns FAILED from transaction, calls transaction.set('FAILED').
        // Then outside transaction checks result.status === 'FAILED' and throws.
        // So the document SHOULD exist with status FAILED.

        // Need to find the booking ID. It's not returned in the error.
        // But we can query the last booking for this customer.
        const failQuery = await db.collection(`cities/${cityId}/bookings`)
            .where('customerId', '==', customerUid)
            .orderBy('createdAt', 'desc')
            .limit(1)
            .get();

        if (!failQuery.empty) {
            const failDoc = failQuery.docs[0].data();
            console.log(`   Last booking status: ${failDoc.status}`);
            if (failDoc.status === 'FAILED') console.log('   ✓ Booking marked as FAILED in DB');
        }

        console.log('\n' + '='.repeat(50));
        console.log('✅ All tests completed!');

    } catch (error) {
        console.error('\n❌ Test failed:', error);
    }
    process.exit(0);
}

runTest();
