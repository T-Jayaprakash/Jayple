import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { Box, Typography, Button } from "@mui/material";

const AdminGuard = ({ children }) => {
    const { user, isAdmin, loading } = useAuth();

    if (loading) return <div>Loading...</div>;

    if (!user) {
        return <Navigate to="/login" replace />;
    }

    if (!isAdmin) {
        return (
            <Box display="flex" flexDirection="column" alignItems="center" justifyContent="center" height="100vh">
                <Typography variant="h4" color="error" gutterBottom>
                    Access Denied
                </Typography>
                <Typography variant="body1">
                    You do not have administrative privileges.
                </Typography>
                {/* NO LOGOUT BUTTON as per rules, though usually helpful. Spec says: "NO LOGOUT BUTTON" */}
            </Box>
        );
    }

    return children;
};

export default AdminGuard;
