import { useEffect, useState } from 'react';
import {
    Paper, Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
    Button, Typography, CircularProgress, Alert, Chip,
    FormControl, InputLabel, Select, MenuItem, Box, Dialog, DialogTitle, DialogContent, DialogContentText, DialogActions
} from '@mui/material';
import { api } from '../services/api';

const Bookings = () => {
    const [bookings, setBookings] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [filter, setFilter] = useState('ALL');
    const [confirmOpen, setConfirmOpen] = useState(false);
    const [selectedBooking, setSelectedBooking] = useState(null);

    useEffect(() => {
        loadBookings();
    }, []);

    const loadBookings = async () => {
        try {
            const data = await api.getBookings({});
            setBookings(data || []);
        } catch (err) {
            setError('Failed to load bookings.');
        } finally {
            setLoading(false);
        }
    };

    const filteredBookings = bookings.filter(b => filter === 'ALL' || b.status === filter);

    const handleCancelClick = (booking) => {
        setSelectedBooking(booking);
        setConfirmOpen(true);
    };

    const handleConfirmCancel = async () => {
        try {
            await api.cancelBooking(selectedBooking.bookingId);
            loadBookings();
            setConfirmOpen(false);
        } catch (err) {
            alert('Cancel failed: ' + err.message);
        }
    };

    if (loading) return <CircularProgress />;
    if (error) return <Alert severity="error">{error}</Alert>;

    return (
        <>
            <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
                <Typography variant="h4">Bookings</Typography>
                <FormControl sx={{ minWidth: 120 }}>
                    <InputLabel>Status</InputLabel>
                    <Select value={filter} label="Status" onChange={(e) => setFilter(e.target.value)}>
                        <MenuItem value="ALL">All</MenuItem>
                        <MenuItem value="CREATED">Created</MenuItem>
                        <MenuItem value="ASSIGNED">Assigned</MenuItem>
                        <MenuItem value="CONFIRMED">Confirmed</MenuItem>
                        <MenuItem value="COMPLETED">Completed</MenuItem>
                        <MenuItem value="CANCELLED">Cancelled</MenuItem>
                        <MenuItem value="FAILED">Failed</MenuItem>
                    </Select>
                </FormControl>
            </Box>

            <TableContainer component={Paper}>
                <Table>
                    <TableHead>
                        <TableRow>
                            <TableCell>Booking ID</TableCell>
                            <TableCell>Type</TableCell>
                            <TableCell>Status</TableCell>
                            <TableCell>Customer</TableCell>
                            <TableCell>Provider</TableCell>
                            <TableCell>Payment</TableCell>
                            <TableCell>Actions</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {filteredBookings.map((row) => (
                            <TableRow key={row.bookingId}>
                                <TableCell>{row.bookingId.substring(0, 8)}...</TableCell>
                                <TableCell>{row.type}</TableCell>
                                <TableCell>
                                    <Chip label={row.status} size="small" />
                                </TableCell>
                                <TableCell>{row.customerId ? row.customerId.substring(0, 6) : '-'}</TableCell>
                                <TableCell>{row.freelancerId ? `Freelancer: ${row.freelancerId.substring(0, 6)}` : `Vendor: ${row.vendorId?.substring(0, 6)}`}</TableCell>
                                <TableCell>
                                    {row.payment ? `${row.payment.status} (${row.payment.mode})` : 'N/A'}
                                </TableCell>
                                <TableCell>
                                    {['CREATED', 'ASSIGNED', 'CONFIRMED'].includes(row.status) && (
                                        <Button
                                            variant="outlined"
                                            color="error"
                                            size="small"
                                            onClick={() => handleCancelClick(row)}
                                        >
                                            Force Cancel
                                        </Button>
                                    )}
                                </TableCell>
                            </TableRow>
                        ))}
                    </TableBody>
                </Table>
            </TableContainer>

            <Dialog open={confirmOpen} onClose={() => setConfirmOpen(false)}>
                <DialogTitle>Confirm Force Cancel</DialogTitle>
                <DialogContent>
                    <DialogContentText>
                        Are you sure you want to force cancel booking {selectedBooking?.bookingId}?
                        This action is destructive and logged.
                    </DialogContentText>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setConfirmOpen(false)}>Back</Button>
                    <Button onClick={handleConfirmCancel} color="error">Cancel Booking</Button>
                </DialogActions>
            </Dialog>
        </>
    );
};

export default Bookings;
