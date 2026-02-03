import { initializeApp } from "firebase/app";
import { getAuth, connectAuthEmulator } from "firebase/auth";
import { getFunctions, connectFunctionsEmulator } from "firebase/functions";

const firebaseConfig = {
    apiKey: "AIzaSyD3cBguvecbtfdD8KeSe_H69i2ABzpsLuI",
    authDomain: "jayple-app-2026.firebaseapp.com",
    projectId: "jayple-app-2026",
    storageBucket: "jayple-app-2026.firebasestorage.app",
    messagingSenderId: "152751512014",
    appId: "1:152751512014:web:admin" // Using placeholder web appId
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize services
export const auth = getAuth(app);
export const functions = getFunctions(app);

// Emulator support (Optional: Uncomment for local dev)
// if (location.hostname === "localhost") {
//   connectAuthEmulator(auth, "http://localhost:9099");
//   connectFunctionsEmulator(functions, "localhost", 5001);
// }
