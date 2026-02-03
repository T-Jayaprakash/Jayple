import { useEffect, useState } from 'react';
import {
    Paper, Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
    Button, Typography, CircularProgress, Alert, Chip, Dialog, DialogTitle,
    DialogContent, DialogContentText, DialogActions
} from '@mui/material';
import { api } from '../services/api';

const Settlements = () => {
    const [settlements, setSettlements] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [confirmOpen, setConfirmOpen] = useState(false);
    const [selectedSettlement, setSelectedSettlement] = useState(null);

    useEffect(() => {
        loadSettlements();
    }, []);

    const loadSettlements = async () => {
        try {
            const data = await api.getSettlements();
            setSettlements(data || []);
        } catch (err) {
            setError('Failed to load settlements.');
        } finally {
            setLoading(false);
        }
    };

    const handleMarkPaidClick = (s) => {
        setSelectedSettlement(s);
        setConfirmOpen(true);
    };

    const handleConfirmPaid = async () => {
        try {
            await api.markSettlementPaid(selectedSettlement.settlementId);
            loadSettlements();
            setConfirmOpen(false);
        } catch (err) {
            alert('Action failed: ' + err.message);
        }
    };

    if (loading) return <CircularProgress />;
    if (error) return <Alert severity="error">{error}</Alert>;

    return (
        <>
            <Typography variant="h4" gutterBottom>Settlements</Typography>
            <TableContainer component={Paper}>
                <Table>
                    <TableHead>
                        <TableRow>
                            <TableCell>Settlement ID</TableCell>
                            <TableCell>Provider ID</TableCell>
                            <TableCell>Net Amount</TableCell>
                            <TableCell>Payout</TableCell>
                            <TableCell>Status</TableCell>
                            <TableCell>Period</TableCell>
                            <TableCell>Actions</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {settlements.map((row) => (
                            <TableRow key={row.settlementId}>
                                <TableCell>{row.settlementId.substring(0, 10)}...</TableCell>
                                <TableCell>{row.userId}</TableCell>
                                <TableCell>₹{row.netAmount}</TableCell>
                                <TableCell>₹{row.payoutAmount}</TableCell>
                                <TableCell>
                                    <Chip
                                        label={row.status}
                                        color={row.status === 'PAID' ? 'success' : 'warning'}
                                        size="small"
                                    />
                                </TableCell>
                                <TableCell>{new Date(row.periodStart._seconds * 1000).toLocaleDateString()}</TableCell>
                                <TableCell>
                                    {row.status === 'PAYABLE' && (
                                        <Button
                                            variant="contained"
                                            color="primary"
                                            size="small"
                                            onClick={() => handleMarkPaidClick(row)}
                                        >
                                            Mark Paid
                                        </Button>
                                    )}
                                </TableCell>
                            </TableRow>
                        ))}
                    </TableBody>
                </Table>
            </TableContainer>

            <Dialog open={confirmOpen} onClose={() => setConfirmOpen(false)}>
                <DialogTitle>Confirm Payment</DialogTitle>
                <DialogContent>
                    <DialogContentText>
                        Are you sure you want to mark settlement {selectedSettlement?.settlementId} as PAID?
                        Ensure manual transfer of ₹{selectedSettlement?.payoutAmount} is complete.
                    </DialogContentText>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setConfirmOpen(false)}>Cancel</Button>
                    <Button onClick={handleConfirmPaid} autoFocus variant="contained">
                        Confirm Paid
                    </Button>
                </DialogActions>
            </Dialog>
        </>
    );
};

export default Settlements;
