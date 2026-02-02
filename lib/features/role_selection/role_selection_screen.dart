import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/auth/user_model.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onRoleSelected;

  const RoleSelectionScreen({
    super.key,
    required this.user,
    required this.onRoleSelected,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _confirmSelection() async {
    if (_selectedRole == null) return;
    
    setState(() { 
      _isSubmitting = true; 
      _error = null; 
    });

    try {
      // Validation: Role must exist in user's assigned roles
      if (!widget.user.roles.contains(_selectedRole)) {
        throw Exception('Selected role is not assigned to this user.');
      }

      // Single Write: Update activeRole
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'activeRole': _selectedRole});
      
      // Notify parent to refresh
      widget.onRoleSelected();

    } catch (e) {
      if (mounted) {
        setState(() { 
          _error = 'Failed to activate role: $e'; 
          _isSubmitting = false; 
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fail fast if no roles to select
    if (widget.user.roles.isEmpty) {
        return const Scaffold(
            body: Center(child: Text("Fatal Error: No roles assigned to user account."))
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Profile'), 
        automaticallyImplyLeading: false, // No back navigation
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Please select your active profile to continue.', 
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            if (_error != null) ...[
                Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade50,
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
                const SizedBox(height: 16),
            ],

            Expanded(
              child: ListView(
                children: widget.user.roles.map((role) {
                  return RadioListTile<String>(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: _selectedRole == role ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                    title: Text(
                        role.toUpperCase(), 
                        style: const TextStyle(fontWeight: FontWeight.w600)
                    ),
                    value: role,
                    groupValue: _selectedRole,
                    onChanged: _isSubmitting ? null : (val) => setState(() => _selectedRole = val),
                  );
                }).toList(),
              ),
            ),
            
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: (_selectedRole == null || _isSubmitting) ? null : _confirmSelection,
                child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Confirm & Continue'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
