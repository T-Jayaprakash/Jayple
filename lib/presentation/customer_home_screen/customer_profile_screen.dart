import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({Key? key}) : super(key: key);

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  File? _pickedImage;

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
      // TODO: Upload image to your backend/storage and update profileUrl
      // Example: await AuthService.instance.updateProfile(avatarUrl: uploadedUrl);
    }
  }

  User? _user;
  bool _loading = true;
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final user = await AuthService.instance.getUserProfile();
    setState(() {
      _user = user;
      _nameController.text = user?.fullName ?? '';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('No profile found')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () async {
              if (_isEditing) {
                await AuthService.instance
                    .updateProfile(fullName: _nameController.text);
                setState(() {
                  _user = _user?.copyWith(fullName: _nameController.text);
                  _isEditing = false;
                });
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : (_user?.profileUrl != null &&
                                _user!.profileUrl!.isNotEmpty
                            ? NetworkImage(_user!.profileUrl!) as ImageProvider
                            : null),
                    child: (_pickedImage == null &&
                            (_user?.profileUrl == null ||
                                _user!.profileUrl!.isEmpty))
                        ? Icon(Icons.person,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name:',
                          style: Theme.of(context).textTheme.labelLarge),
                      _isEditing
                          ? TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                hintText: 'Enter your name',
                                border: OutlineInputBorder(),
                              ),
                            )
                          : Text(_user!.fullName ?? '-',
                              style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Phone:',
                          style: Theme.of(context).textTheme.labelLarge),
                      Text(_user!.phone ?? '-',
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  await AuthService.instance.signOut();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login-screen', (route) => false);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
