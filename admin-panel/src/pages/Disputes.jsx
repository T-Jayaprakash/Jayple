import { useEffect, useState } from 'react';
import {
    Paper, Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
    Button, Typography, CircularProgress, Alert, Chip,
    Dialog, DialogTitle, DialogContent, DialogContentText, DialogActions
} from '@mui/material';
import { api } from '../services/api';

const Disputes = () => {
    const [disputes, setDisputes] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [selectedDispute, setSelectedDispute] = useState(null);
    const [resolveOpen, setResolveOpen] = useState(false);

    useEffect(() => {
        loadDisputes();
    }, []);

    const loadDisputes = async () => {
        try {
            const data = await api.getDisputes();
            setDisputes(data || []);
        } catch (err) {
            setError('Failed to load disputes.');
        } finally {
            setLoading(false);
        }
    };

    const handleResolveClick = (d) => {
        setSelectedDispute(d);
        setResolveOpen(true);
    };

    const handleConfirmResolve = async (decision) => {
        try {
            await api.resolveDispute(selectedDispute.disputeId, decision);
            loadDisputes();
            setResolveOpen(false);
        } catch (err) {
            alert('Resolution failed: ' + err.message);
        }
    };

    if (loading) return <CircularProgress />;
    if (error) return <Alert severity="error">{error}</Alert>;

    return (
        <>
            <Typography variant="h4" gutterBottom>Disputes</Typography>
            <TableContainer component={Paper}>
                <Table>
                    <TableHead>
                        <TableRow>
                            <TableCell>Dispute ID</TableCell>
                            <TableCell>Booking ID</TableCell>
                            <TableCell>Raised By</TableCell>
                            <TableCell>Reason</TableCell>
                            <TableCell>Status</TableCell>
                            <TableCell>Actions</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {disputes.map((row) => (
                            <TableRow key={row.disputeId}>
                                <TableCell>{row.disputeId.substring(0, 8)}...</TableCell>
                                <TableCell>{row.bookingId}</TableCell>
                                <TableCell>{row.raisedBy} ({row.raiserRole})</TableCell>
                                <TableCell>{row.reason}</TableCell>
                                <TableCell>
                                    <Chip label={row.status} color={row.status === 'OPEN' ? 'error' : 'default'} size="small" />
                                </TableCell>
                                <TableCell>
                                    {row.status === 'OPEN' && (
                                        <Button
                                            variant="outlined"
                                            size="small"
                                            onClick={() => handleResolveClick(row)}
                                        >
                                            Resolve
                                        </Button>
                                    )}
                                </TableCell>
                            </TableRow>
                        ))}
                    </TableBody>
                </Table>
            </TableContainer>

            <Dialog open={resolveOpen} onClose={() => setResolveOpen(false)}>
                <DialogTitle>Resolve Dispute</DialogTitle>
                <DialogContent>
                    <DialogContentText>
                        Choose the outcome for booking {selectedDispute?.bookingId}.
                        This will adjust the ledger accordingly.
                    </DialogContentText>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setResolveOpen(false)}>Cancel</Button>
                    <Button onClick={() => handleConfirmResolve('customer')} color="primary">
                        Refund Customer
                    </Button>
                    <Button onClick={() => handleConfirmResolve('provider')} color="secondary">
                        Pay Provider
                    </Button>
                </DialogActions>
            </Dialog>
        </>
    );
};

export default Disputes;
