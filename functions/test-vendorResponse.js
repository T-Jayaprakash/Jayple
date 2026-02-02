/**
 * Test script for vendorRespondToBooking function
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
    console.log('🧪 Testing vendorRespondToBooking\n');
    console.log('='.repeat(50));

    try {
        // Setup: Create customer and vendor users
        const customerUid = 'test-customer-001';
        const vendorUid = 'test-vendor-001';
        const customerEmail = 'customer@jayple.test';
        const vendorEmail = 'vendor@jayple.test';
        const password = 'testpassword123';

        console.log('\n📱 Setting up test users...');

        // Clean up existing users
        try { await auth.deleteUser(customerUid); } catch (e) { /* ignore */ }
        try { await auth.deleteUser(vendorUid); } catch (e) { /* ignore */ }

        // Create customer
        await auth.createUser({
            uid: customerUid,
            email: customerEmail,
            password,
            displayName: 'Test Customer',
        });
        await db.doc(`users/${customerUid}`).set({
            userId: customerUid,
            name: 'Test Customer',
            activeRole: 'customer',
            cityId: 'trichy',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('   ✓ Customer created');

        // Create vendor
        await auth.createUser({
            uid: vendorUid,
            email: vendorEmail,
            password,
            displayName: 'Test Vendor',
        });
        await db.doc(`users/${vendorUid}`).set({
            userId: vendorUid,
            name: 'Test Vendor',
            activeRole: 'vendor',
            salonId: vendorUid,
            cityId: 'trichy',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('   ✓ Vendor created');

        // Get tokens
        const customerSignIn = await fetch(
            'http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email: customerEmail, password, returnSecureToken: true }),
            }
        );
        const customerToken = (await customerSignIn.json()).idToken;

        const vendorSignIn = await fetch(
            'http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email: vendorEmail, password, returnSecureToken: true }),
            }
        );
        const vendorToken = (await vendorSignIn.json()).idToken;
        console.log('   ✓ Got tokens');

        // Create a booking (as customer) with vendor's salonId
        console.log('\n📝 Creating test booking...');
        const bookingRef = db.collection('cities/trichy/bookings').doc();
        await bookingRef.set({
            bookingId: bookingRef.id,
            customerId: customerUid,
            salonId: vendorUid,
            vendorId: vendorUid,
            type: 'inShop',
            serviceId: 'haircut_001',
            cityId: 'trichy',
            status: 'CREATED',
            scheduledAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        const bookingId = bookingRef.id;
        console.log(`   ✓ Created booking: ${bookingId}`);

        // Test 1: Vendor accepts booking
        console.log('\n🔍 Test 1: Vendor ACCEPTS booking');
        const acceptResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/vendorRespondToBooking', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${vendorToken}`,
            },
            body: JSON.stringify({
                data: { bookingId, cityId: 'trichy', action: 'ACCEPT' }
            }),
        });
        const acceptResult = await acceptResponse.json();

        if (acceptResult.result && acceptResult.result.status === 'CONFIRMED') {
            console.log('   ✓ Booking accepted successfully');
            console.log('   Result:', JSON.stringify(acceptResult.result, null, 2));
        } else {
            console.log('   ✗ Failed:', acceptResult.error);
        }

        // Test 2: Try to accept again (should fail)
        console.log('\n🔍 Test 2: Try to ACCEPT again (should fail)');
        const doubleAcceptResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/vendorRespondToBooking', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${vendorToken}`,
            },
            body: JSON.stringify({
                data: { bookingId, cityId: 'trichy', action: 'ACCEPT' }
            }),
        });
        const doubleAcceptResult = await doubleAcceptResponse.json();

        if (doubleAcceptResult.error && doubleAcceptResult.error.status === 'FAILED_PRECONDITION') {
            console.log('   ✓ Correctly rejected double acceptance');
        } else {
            console.log('   Result:', JSON.stringify(doubleAcceptResult, null, 2));
        }

        // Test 3: Create another booking and REJECT it
        console.log('\n📝 Creating another booking for REJECT test...');
        const booking2Ref = db.collection('cities/trichy/bookings').doc();
        await booking2Ref.set({
            bookingId: booking2Ref.id,
            customerId: customerUid,
            salonId: vendorUid,
            vendorId: vendorUid,
            type: 'inShop',
            serviceId: 'haircut_002',
            cityId: 'trichy',
            status: 'CREATED',
            scheduledAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        const booking2Id = booking2Ref.id;
        console.log(`   ✓ Created booking: ${booking2Id}`);

        console.log('\n🔍 Test 3: Vendor REJECTS booking');
        const rejectResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/vendorRespondToBooking', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${vendorToken}`,
            },
            body: JSON.stringify({
                data: { bookingId: booking2Id, cityId: 'trichy', action: 'REJECT' }
            }),
        });
        const rejectResult = await rejectResponse.json();

        if (rejectResult.result && rejectResult.result.status === 'REJECTED') {
            console.log('   ✓ Booking rejected successfully');
            console.log('   Result:', JSON.stringify(rejectResult.result, null, 2));
        } else {
            console.log('   ✗ Failed:', rejectResult.error);
        }

        // Test 4: Customer tries to respond (should fail)
        console.log('\n🔍 Test 4: Customer tries to respond (should fail)');
        const booking3Ref = db.collection('cities/trichy/bookings').doc();
        await booking3Ref.set({
            bookingId: booking3Ref.id,
            customerId: customerUid,
            salonId: vendorUid,
            type: 'inShop',
            status: 'CREATED',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const customerTryResponse = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/vendorRespondToBooking', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${customerToken}`,
            },
            body: JSON.stringify({
                data: { bookingId: booking3Ref.id, cityId: 'trichy', action: 'ACCEPT' }
            }),
        });
        const customerTryResult = await customerTryResponse.json();

        if (customerTryResult.error && customerTryResult.error.status === 'PERMISSION_DENIED') {
            console.log('   ✓ Correctly rejected customer attempt');
        } else {
            console.log('   Result:', JSON.stringify(customerTryResult, null, 2));
        }

        // Verify status events
        console.log('\n📊 Verifying status events...');
        const events = await bookingRef.collection('status_events').get();
        console.log(`   Found ${events.size} status event(s) for first booking`);
        events.forEach(doc => {
            const data = doc.data();
            console.log(`   - ${data.from} → ${data.to} by ${data.actor}`);
        });

        console.log('\n' + '='.repeat(50));
        console.log('✅ All tests completed!');

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error);
    }

    process.exit(0);
}

runTest();
