const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

// Set Emulator Env
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'jayple-app-2026';

admin.initializeApp({ projectId: 'jayple-app-2026' });
const db = admin.firestore();

async function seed() {
    console.log("Starting seed...");

    // 1. Services
    const services = [
        { serviceId: 'haircut', name: 'Haircut', category: 'hair', basePrice: 150, isActive: true },
        { serviceId: 'beard_trim', name: 'Beard Trim', category: 'beard', basePrice: 80, isActive: true },
        { serviceId: 'facial', name: 'Facial', category: 'skin', basePrice: 300, isActive: true },
        { serviceId: 'hair_spa', name: 'Hair Spa', category: 'hair', basePrice: 400, isActive: true }
    ];

    const batch = db.batch();
    const cityId = 'trichy';

    // 2. City
    const cityRef = db.doc(`cities/${cityId}`);
    try {
        await cityRef.set({ name: 'Trichy', isActive: true }, { merge: true });
    } catch (e) {
        console.log("Could not connect to Firestore Emulator (Error: " + e.code + "). Assuming Cloud Function deployment will handle it.");
        return; // Exit gracefully
    }

    // Services
    for (const s of services) {
        const sRef = db.doc(`cities/${cityId}/services/${s.serviceId}`);
        batch.set(sRef, s, { merge: true });
    }

    // 3. Vendor (Jayple Test Salon)
    const vendorId = "vendor_test_001";
    const vendorRef = db.doc(`cities/${cityId}/vendors/${vendorId}`);
    batch.set(vendorRef, {
        vendorId,
        shopName: "Jayple Test Salon",
        cityId,
        servicesOffered: ["haircut", "facial", "hair_spa"],
        bookingMode: "IN_SHOP",
        status: "active",
        createdAt: FieldValue.serverTimestamp()
    }, { merge: true });

    // 4. Freelancer (Test Barber)
    const freelancerId = "freelancer_test_001";
    const freelancerRef = db.doc(`cities/${cityId}/freelancers/${freelancerId}`);
    batch.set(freelancerRef, {
        freelancerId,
        name: "Test Barber",
        cityId,
        serviceCategories: ["hair", "beard"],
        isOnline: true,
        priorityTier: "GOLD",
        status: "active",
        createdAt: FieldValue.serverTimestamp()
    }, { merge: true });

    await batch.commit();
    console.log("Seed data created successfully");
}

seed();
