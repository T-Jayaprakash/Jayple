import { useEffect, useState } from 'react';
import { Grid, Card, CardContent, Typography, CircularProgress, Alert } from '@mui/material';
import { api } from '../services/api';

const StatCard = ({ title, value }) => (
    <Card>
        <CardContent>
            <Typography color="textSecondary" gutterBottom>
                {title}
            </Typography>
            <Typography variant="h4" component="div">
                {value}
            </Typography>
        </CardContent>
    </Card>
);

const Dashboard = () => {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        const fetchStats = async () => {
            try {
                const data = await api.getDashboardStats();
                setStats(data);
            } catch (err) {
                console.error(err);
                // Use mock data if backend function missing (Prototype behavior)
                // Remove for prod
                setStats({
                    users: 0,
                    vendors: 0,
                    freelancers: 0,
                    todayBookings: 0,
                    failedBookings: 0,
                    pendingSettlements: 0
                });
                // setError('Failed to load dashboard stats.');
            } finally {
                setLoading(false);
            }
        };
        fetchStats();
    }, []);

    if (loading) return <CircularProgress />;
    // if (error) return <Alert severity="error">{error}</Alert>; 
    // Allowing mock/empty render for now

    return (
        <Grid container spacing={3}>
            <Grid item xs={12}>
                <Typography variant="h4" gutterBottom>Dashboard</Typography>
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
                <StatCard title="Total Users" value={stats?.users || 0} />
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
                <StatCard title="Active Vendors" value={stats?.vendors || 0} />
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
                <StatCard title="Active Freelancers" value={stats?.freelancers || 0} />
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
                <StatCard title="Today's Bookings" value={stats?.todayBookings || 0} />
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
                <StatCard title="Failed Bookings" value={stats?.failedBookings || 0} />
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
                <StatCard title="Pending Settlements" value={stats?.pendingSettlements || 0} />
            </Grid>
        </Grid>
    );
};

export default Dashboard;
