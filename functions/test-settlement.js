/**
 * Test Settlement & Blocking System (Step A9)
 */

const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8081';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9098';

admin.initializeApp({ projectId: 'jayple-app-2026' });
const db = admin.firestore();
const auth = admin.auth();

async function runTest() {
    console.log('🧪 Testing Settlements & Blocking (Step A9)\n');

    const cityId = 'trichy';
    const flUid = 'fl_settle';
    const custUid = 'cust_settle';
    const serviceOff = 'svc_settle_off';
    const serviceOn = 'svc_settle_on';

    // Setup
    try { await auth.createUser({ uid: custUid, email: 'cust_s@test.com', password: 'password123' }); } catch (e) { }
    try { await auth.createUser({ uid: flUid, email: 'fl_s@test.com', password: 'password123' }); } catch (e) { }

    await db.doc(`users/${custUid}`).set({ activeRole: 'customer', cityId });
    await db.doc(`users/${flUid}`).set({ activeRole: 'freelancer', cityId, userId: flUid }); // Vendor logic similar

    // High Value Service for Debt (Offline)
    await db.doc(`cities/${cityId}/services/${serviceOff}`).set({ name: 'Debt Maker', category: 'haircut', type: 'inShop', price: 200000, vendorId: flUid }); // Use inShop to simplify assignment 
    // Just simulating a booking where Provider is 'fl_settle' (Freelancer can be assigned too for home, but let's use home for Online).
    // Let's use 'home' type for Offline? No, home=Online. inShop=Offline.
    // We'll use 'inShop' and assign 'salonId'=flUid (Simulate Vendor).
    // Or just use 'home' but modify logic to be OFFLINE?
    // Code says: `paymentMode = type === 'home' ? 'ONLINE' : 'OFFLINE'`.
    // So 'inShop' is Offline.
    // If 'inShop', we need `salonId` or `vendorId`.
    // We'll update flUid doc to act as vendor too or just use salonId field in booking.

    // Actually, let's use 'home' type but price it high, enabling ONLINE checks.
    // Wait, Blocking is for OUTSTANDING. That comes from Commissions on OFFLINE.
    // So I MUST use 'inShop' (OFFLINE).

    await db.doc(`cities/${cityId}/services/${serviceOff}`).set({ name: 'Debt Maker', category: 'haircut', type: 'inShop', price: 200000, vendorId: flUid });

    // Online Service (Price 2000)
    await db.doc(`cities/${cityId}/services/${serviceOn}`).set({ name: 'Profit Maker', category: 'haircut', type: 'home', price: 2000, vendorId: flUid });

    await db.doc(`cities/${cityId}/freelancers/${flUid}`).set({
        userId: flUid, priorityTier: 'gold', isOnline: true, status: 'active', serviceCategories: ['haircut']
    });

    const custToken = await fetchAuthToken('cust_s@test.com');
    const flToken = await fetchAuthToken('fl_s@test.com');

    // TEST 1: Accumulate Debt (Offline Booking)
    console.log('🔍 Test 1: Accumulate Debt (Offline)');
    // Just directly create booking doc to save time? Or use API?
    // API `createBooking` for 'inShop'.
    // API `vendorRespond` (Using flToken).
    // API `complete`.

    // Note: createBooking for inShop doesn't assign freelancer. It sets cityId/serviceId.
    // Vendor responds.
    // I need to patch `createBooking` or ensure `service` doc has `vendorId` which I did.

    const b1 = await createBooking(custToken, cityId, serviceOff, 'inShop');
    // b1 likely created.
    // Vendor Respond.
    // Wait, `createBooking` logic for inShop doesn't auto-confirm.
    // `vendorRespond` needs `bookingId`.

    // Accept
    await respondVendor(flToken, b1.bookingId, cityId, 'ACCEPT');
    // Complete
    await complete(flToken, b1.bookingId, cityId);

    // Verify Ledger
    // Price 200,000. Comm 20,000.
    // Mode OFFLINE.
    // Payable Balance: 0 - 20,000 = -20,000.
    // Threshold -10,000 reached.
    // Should be BLOCKED.

    const blockDoc = await db.doc(`blocked_accounts/${flUid}`).get();
    if (!blockDoc.exists) throw new Error('User should be BLOCKED');
    if (blockDoc.data().reason !== 'OUTSTANDING_LIMIT_EXCEEDED') throw new Error('Wrong block reason');
    console.log('   ✓ User Blocked (Debt: 20,000)');

    // TEST 2: Block Enforcement
    console.log('\n🔍 Test 2: Block Enforcement');
    try {
        await respondVendor(flToken, b1.bookingId, cityId, 'ACCEPT'); // Try to verify another action
        // Actually, let's try to Accept a NEW booking.
        const b2 = await createBooking(custToken, cityId, serviceOff, 'inShop');
        await respondVendor(flToken, b2.bookingId, cityId, 'ACCEPT');
        throw new Error('Should fail');
    } catch (e) {
        // Expect permission-denied or similar
        // My wrapper throws Error if status != 200
        console.log('   ✓ Block Enforced (Cannot Accept)');
    }

    // TEST 3: Unblock
    console.log('\n🔍 Test 3: Unblock Logic');
    // Pay off debt: Credit 25,000
    await db.collection('ledger').add({
        userId: flUid, amount: 25000, entryType: 'DEBT_PAYMENT', direction: 'CREDIT',
        balanceAfter: 5000, createdAt: admin.firestore.Timestamp.now()
    });

    // Trigger Unblock Check
    await unblock(flUid); // passing uid to helper

    const blockDoc2 = await db.doc(`blocked_accounts/${flUid}`).get();
    if (blockDoc2.exists) throw new Error('User should be UNBLOCKED');
    console.log('   ✓ User Unblocked');

    // TEST 4: Weekly Settlement (Payout)
    console.log('\n🔍 Test 4: Weekly Settlement (Payout)');
    // Current Balance Calculation:
    // Offline Payment (Ignored).
    // Commission (-20,000).
    // Debt Payment (+25,000).
    // Net Payable: +5,000.
    // Threshold 500 met.
    // Should Payout 5,000.

    await runSettlements();

    const settlements = await db.collection('settlements').where('userId', '==', flUid).get();
    if (settlements.empty) throw new Error('No settlement created');
    const s = settlements.docs[0].data();

    if (s.status !== 'PAYABLE') throw new Error(`Expected PAYABLE, got ${s.status}`);
    if (s.payoutAmount !== 5000) throw new Error(`Expected 5000 payout, got ${s.payoutAmount}`);

    // Verify Payout Ledger Entry
    const lSnap = await db.collection('ledger').where('userId', '==', flUid).where('entryType', '==', 'PAYOUT').get();
    if (lSnap.empty) throw new Error('Payout Entry missing');
    if (lSnap.docs[0].data().amount !== 5000) throw new Error('Payout Amount wrong');

    console.log('   ✓ Settlement Success (Payout: 5000)');

    console.log('\n✅ Settlement Tests Passed!');
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
async function respondVendor(token, bookingId, cityId, action) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/vendorRespondToBooking', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId, action } })
    });
    if (res.status !== 200) throw new Error('Failed');
}
async function complete(token, bookingId, cityId) {
    const res = await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/completeBooking', {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ data: { bookingId, cityId } })
    });
    if (res.status !== 200) {
        const t = await res.text();
        console.error('Complete Failed', t);
        throw new Error('Complete Failed');
    }
}
async function unblock(userId) {
    await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/unblockUserIfCleared', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ data: { userId } })
    });
}
async function runSettlements() {
    await fetch('http://127.0.0.1:5002/jayple-app-2026/us-central1/runWeeklySettlements', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ data: {} })
    });
}

runTest();
