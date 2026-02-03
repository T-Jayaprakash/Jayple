import { httpsCallable } from "firebase/functions";
import { functions } from "../firebase";

const call = async (name, data = {}) => {
    try {
        const fn = httpsCallable(functions, name);
        const result = await fn(data);
        return result.data;
    } catch (error) {
        console.error(`Error calling ${name}:`, error);
        throw error;
    }
};

export const api = {
    // Dashboard
    getDashboardStats: () => call('getAdminDashboardStats'),

    // Users
    getUsers: () => call('getAdminUsers'),
    blockUser: (uid) => call('blockUser', { uid }),
    unblockUser: (uid) => call('unblockUser', { uid }),
    getUserDetails: (uid) => call('getAdminUserDetails', { uid }),

    // Bookings
    getBookings: (filters) => call('getAllBookings', filters),
    cancelBooking: (bookingId) => call('adminCancelBooking', { bookingId }),

    // Settlements
    getSettlements: () => call('getAllSettlements'),
    markSettlementPaid: (settlementId) => call('markSettlementPaid', { settlementId }),

    // Disputes
    getDisputes: () => call('getDisputes'),
    resolveDispute: (disputeId, decision) => call('resolveDispute', { disputeId, decision }),

    // Settings
    getSettings: () => call('getAdminSettings')
};
