import { useEffect, useState } from 'react';
import {
    Paper, Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
    Button, Typography, CircularProgress, Alert, Chip, Dialog, DialogTitle,
    DialogContent, DialogContentText, DialogActions
} from '@mui/material';
import { api } from '../services/api';

const Users = () => {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [selectedUser, setSelectedUser] = useState(null); // For block dialog
    const [confirmOpen, setConfirmOpen] = useState(false);

    useEffect(() => {
        loadUsers();
    }, []);

    const loadUsers = async () => {
        try {
            const data = await api.getUsers();
            setUsers(data || []);
        } catch (err) {
            setError('Failed to load users.');
        } finally {
            setLoading(false);
        }
    };

    const handleBlockClick = (user) => {
        setSelectedUser(user);
        setConfirmOpen(true);
    };

    const handleConfirmBlock = async () => {
        try {
            if (selectedUser.status === 'blocked') {
                await api.unblockUser(selectedUser.uid);
            } else {
                await api.blockUser(selectedUser.uid);
            }
            loadUsers(); // Refresh
            setConfirmOpen(false);
        } catch (err) {
            alert('Action failed: ' + err.message);
        }
    };

    if (loading) return <CircularProgress />;
    if (error) return <Alert severity="error">{error}</Alert>;

    return (
        <>
            <Typography variant="h4" gutterBottom>Users Management</Typography>
            <TableContainer component={Paper}>
                <Table>
                    <TableHead>
                        <TableRow>
                            <TableCell>User ID</TableCell>
                            <TableCell>Phone</TableCell>
                            <TableCell>Active Role</TableCell>
                            <TableCell>Status</TableCell>
                            <TableCell>Created At</TableCell>
                            <TableCell>Actions</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {users.map((user) => (
                            <TableRow key={user.uid}>
                                <TableCell>{user.uid.substring(0, 8)}...</TableCell>
                                <TableCell>{user.phoneNumber}</TableCell>
                                <TableCell>{user.activeRole}</TableCell>
                                <TableCell>
                                    <Chip
                                        label={user.status}
                                        color={user.status === 'blocked' ? 'error' : 'success'}
                                        size="small"
                                    />
                                </TableCell>
                                <TableCell>{user.createdAt ? new Date(user.createdAt).toLocaleDateString() : '-'}</TableCell>
                                <TableCell>
                                    <Button
                                        variant="outlined"
                                        color={user.status === 'blocked' ? 'success' : 'error'}
                                        size="small"
                                        onClick={() => handleBlockClick(user)}
                                    >
                                        {user.status === 'blocked' ? 'Unblock' : 'Block'}
                                    </Button>
                                </TableCell>
                            </TableRow>
                        ))}
                    </TableBody>
                </Table>
            </TableContainer>

            <Dialog open={confirmOpen} onClose={() => setConfirmOpen(false)}>
                <DialogTitle>Confirm Action</DialogTitle>
                <DialogContent>
                    <DialogContentText>
                        Are you sure you want to {selectedUser?.status === 'blocked' ? 'unblock' : 'block'} user {selectedUser?.phoneNumber}?
                    </DialogContentText>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setConfirmOpen(false)}>Cancel</Button>
                    <Button onClick={handleConfirmBlock} color="secondary" autoFocus>
                        Confirm
                    </Button>
                </DialogActions>
            </Dialog>
        </>
    );
};

export default Users;
