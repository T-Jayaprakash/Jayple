/**
 * Test script for getMyBookings and getBookingById functions
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
    console.log('🧪 Testing getMyBookings & getBookingById\n');
    console.log('='.repeat(50));

    try {
        // Setup: Create test user
        const testUid = 'test-customer-uid-001';
        const testEmail = 'testcustomer2@jayple.test';
        const testPassword = 'testpassword123';

        console.log('\n📱 Setting up test user...');

        try { await auth.deleteUser(testUid); } catch (e) { /* ignore */ }

        await auth.createUser({
            uid: testUid,
            email: testEmail,
            password: testPassword,
            displayName: 'Test Customer',
        });

        await db.doc(`users/${testUid}`).set({
            userId: testUid,
            name: 'Test Customer',
            activeRole: 'customer',
            cityId: 'trichy',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('   ✓ Test user created');

        // Sign in to get token
        const signInResponse = await fetch(
            'http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    email: testEmail,
                    password: testPassword,
                    returnSecureToken: true,
                }),
            }
        );
        const signInData = await signInResponse.json();
        const idToken = signInData.idToken;
        console.log('   ✓ Got ID token');

        // Create a test booking first
        console.log('\n📝 Creating test booking...');
        const createResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${idToken}`,
            },
            body: JSON.stringify({
                data: {
                    type: 'inShop',
                    cityId: 'trichy',
                    serviceId: 'haircut_001',
                    scheduledAt: Date.now() + 86400000,
                    idempotencyKey: `test_read_${Date.now()}`,
                }
            }),
        });
        const createResult = await createResponse.json();
        const bookingId = createResult.result.bookingId;
        console.log(`   ✓ Created booking: ${bookingId}`);

        // Test 1: getMyBookings
        console.log('\n🔍 Test 1: getMyBookings');
        const myBookingsResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/getMyBookings', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${idToken}`,
            },
            body: JSON.stringify({ data: {} }),
        });
        const myBookingsResult = await myBookingsResponse.json();

        if (myBookingsResult.result && myBookingsResult.result.bookings) {
            console.log(`   ✓ Returned ${myBookingsResult.result.bookings.length} booking(s)`);
            console.log('   Sample booking:', JSON.stringify(myBookingsResult.result.bookings[0], null, 2));
        } else {
            console.log('   ✗ Failed:', myBookingsResult.error);
        }

        // Test 2: getBookingById (valid access)
        console.log('\n🔍 Test 2: getBookingById (valid access)');
        const getByIdResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/getBookingById', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${idToken}`,
            },
            body: JSON.stringify({
                data: { bookingId, cityId: 'trichy' }
            }),
        });
        const getByIdResult = await getByIdResponse.json();

        if (getByIdResult.result && getByIdResult.result.booking) {
            console.log('   ✓ Returned booking successfully');
            console.log('   Booking:', JSON.stringify(getByIdResult.result.booking, null, 2));
        } else {
            console.log('   ✗ Failed:', getByIdResult.error);
        }

        // Test 3: getBookingById (invalid - no such booking)
        console.log('\n🔍 Test 3: getBookingById (not found)');
        const notFoundResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/getBookingById', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${idToken}`,
            },
            body: JSON.stringify({
                data: { bookingId: 'nonexistent123', cityId: 'trichy' }
            }),
        });
        const notFoundResult = await notFoundResponse.json();

        if (notFoundResult.error && notFoundResult.error.status === 'NOT_FOUND') {
            console.log('   ✓ Correctly returned NOT_FOUND error');
        } else {
            console.log('   Result:', JSON.stringify(notFoundResult, null, 2));
        }

        // Test 4: getMyBookings without auth
        console.log('\n🔍 Test 4: getMyBookings (no auth)');
        const noAuthResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/getMyBookings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ data: {} }),
        });
        const noAuthResult = await noAuthResponse.json();

        if (noAuthResult.error && noAuthResult.error.status === 'UNAUTHENTICATED') {
            console.log('   ✓ Correctly rejected unauthenticated request');
        } else {
            console.log('   Result:', JSON.stringify(noAuthResult, null, 2));
        }

        console.log('\n' + '='.repeat(50));
        console.log('✅ All tests completed!');

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error);
    }

    process.exit(0);
}

runTest();
