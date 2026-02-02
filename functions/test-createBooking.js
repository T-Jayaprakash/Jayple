/**
 * Test script for createBooking function
 * 
 * This script:
 * 1. Creates a test user in Auth emulator
 * 2. Creates a user document in Firestore with activeRole: "customer"
 * 3. Signs in to get ID token
 * 4. Calls createBooking with proper authentication
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
    console.log('🧪 Starting createBooking Test\n');
    console.log('='.repeat(50));

    try {
        // Step 1: Create test user in Auth
        console.log('\n📱 Step 1: Creating test user in Auth emulator...');

        let testUser;
        const testEmail = 'testcustomer2@jayple.test';
        const testPassword = 'testpassword123';
        const testUid = 'test-customer-uid-001';

        try {
            // Try to delete existing user first
            await auth.deleteUser(testUid);
        } catch (e) {
            // User doesn't exist, that's fine
        }

        // Create user with specific UID
        testUser = await auth.createUser({
            uid: testUid,
            email: testEmail,
            password: testPassword,
            displayName: 'Test Customer',
        });
        console.log(`   ✓ Created user: ${testUser.uid}`);

        // Step 2: Create user document in Firestore FIRST
        console.log('\n📄 Step 2: Creating user document in Firestore...');

        await db.doc(`users/${testUser.uid}`).set({
            userId: testUser.uid,
            phone: '+919876543210',
            name: 'Test Customer',
            roles: ['customer'],
            activeRole: 'customer',
            status: 'active',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`   ✓ User document created with activeRole: "customer"`);

        // Verify document was created
        const userDoc = await db.doc(`users/${testUser.uid}`).get();
        console.log(`   ✓ Verified user doc exists: ${userDoc.exists}`);
        console.log(`   ✓ activeRole: ${userDoc.data().activeRole}`);

        // Step 3: Sign in via Auth emulator REST API to get ID token
        console.log('\n🔑 Step 3: Signing in to get ID token...');

        const signInResponse = await fetch(
            `http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
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

        if (!signInData.idToken) {
            console.error('Sign in failed:', signInData);
            throw new Error('Failed to get ID token');
        }

        const idToken = signInData.idToken;
        console.log(`   ✓ Got ID token (${idToken.substring(0, 20)}...)`);

        // Step 4: Call createBooking via HTTP with ID token
        console.log('\n🚀 Step 4: Calling createBooking function...');

        const scheduledAt = Date.now() + (24 * 60 * 60 * 1000); // Tomorrow

        const requestBody = {
            data: {
                type: 'inShop',
                cityId: 'trichy',
                serviceId: 'haircut_001',
                scheduledAt: scheduledAt,
                idempotencyKey: `test_booking_${Date.now()}`,
            }
        };

        const response = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${idToken}`,
            },
            body: JSON.stringify(requestBody),
        });

        const result = await response.json();

        console.log('\n📋 Response:');
        console.log(JSON.stringify(result, null, 2));

        // Step 5: Verify booking was created in Firestore
        console.log('\n🔍 Step 5: Verifying booking in Firestore...');

        if (result.result && result.result.bookingId) {
            const bookingDoc = await db.doc(`cities/trichy/bookings/${result.result.bookingId}`).get();

            if (bookingDoc.exists) {
                console.log('   ✓ Booking document found in Firestore!');
                console.log('\n📦 Booking Data:');
                const bookingData = bookingDoc.data();
                console.log(JSON.stringify({
                    ...bookingData,
                    createdAt: bookingData.createdAt?.toDate?.() || bookingData.createdAt,
                    updatedAt: bookingData.updatedAt?.toDate?.() || bookingData.updatedAt,
                    scheduledAt: bookingData.scheduledAt?.toDate?.() || bookingData.scheduledAt,
                }, null, 2));

                // Check status events
                const statusEvents = await bookingDoc.ref.collection('status_events').get();
                console.log(`\n📊 Status Events: ${statusEvents.size} event(s)`);
                statusEvents.forEach(doc => {
                    const data = doc.data();
                    console.log(JSON.stringify({
                        ...data,
                        timestamp: data.timestamp?.toDate?.() || data.timestamp,
                    }, null, 2));
                });
            } else {
                console.log('   ✗ Booking document NOT found');
            }
        } else if (result.error) {
            console.log('   ✗ Error in response:', result.error.message);
        } else {
            console.log('   ℹ Unexpected response format');
        }

        // Step 6: Test idempotency
        console.log('\n🔄 Step 6: Testing idempotency...');

        const idempotencyKey = `idempotent_test_${Date.now()}`;

        // First call
        const firstCall = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${idToken}`,
            },
            body: JSON.stringify({
                data: {
                    type: 'home',
                    cityId: 'trichy',
                    serviceId: 'facial_001',
                    scheduledAt: scheduledAt,
                    idempotencyKey: idempotencyKey,
                }
            }),
        });
        const firstResult = await firstCall.json();
        console.log(`   First call - bookingId: ${firstResult.result?.bookingId}`);

        // Second call with same key
        const secondCall = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/createBooking', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${idToken}`,
            },
            body: JSON.stringify({
                data: {
                    type: 'home',
                    cityId: 'trichy',
                    serviceId: 'facial_001',
                    scheduledAt: scheduledAt,
                    idempotencyKey: idempotencyKey,
                }
            }),
        });
        const secondResult = await secondCall.json();
        console.log(`   Second call - bookingId: ${secondResult.result?.bookingId}, alreadyExists: ${secondResult.result?.alreadyExists}`);

        if (firstResult.result?.bookingId === secondResult.result?.bookingId && secondResult.result?.alreadyExists) {
            console.log('   ✓ Idempotency working correctly!');
        } else {
            console.log('   ✗ Idempotency check failed');
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
