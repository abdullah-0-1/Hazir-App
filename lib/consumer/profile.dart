import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('userConsumer')
          .doc(widget.userId)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _userData = doc.data()!;
          _nameController.text = _userData!['name'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userData = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserData() async {
    try {
      await FirebaseFirestore.instance
          .collection('userConsumer')
          .doc(widget.userId)
          .update({'name': _nameController.text});
      setState(() {
        _userData!['name'] = _nameController.text;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(2, 62, 138, 1),
          foregroundColor: Colors.white,
          title: const Text('Profile'),
        ),
        body: const Center(
          child: Text('No user data found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(2, 62, 138, 1),
        foregroundColor: Colors.white,
        title: const Text('Profile'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _updateUserData,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color.fromRGBO(2, 62, 138, 1),
              child: Text(
                (_userData!['name'] != null && _userData!['name'].isNotEmpty)
                    ? _userData!['name'][0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            _buildEditableField(
              label: 'Name',
              controller: _nameController,
              isEditable: true,
            ),
            const SizedBox(height: 24),
            _buildInfoCard(
              label: 'Contact Number',
              value: _userData!['contactNumber'] ?? 'N/A',
              icon: Icons.phone,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              label: 'Email',
              value: _userData!['mail'] ?? 'N/A',
              icon: Icons.email,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              label: 'Verified',
              value: _userData!['isVerified'] == true ? 'Yes' : 'No',
              icon: _userData!['isVerified'] == true
                  ? Icons.verified
                  : Icons.cancel,
              iconColor: _userData!['isVerified'] == true
                  ? Colors.green
                  : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: () {
                setState(() {
                  if (_isEditing) {
                    _nameController.text = _userData!['name'] ?? '';
                    _isEditing = false;
                  } else {
                    _isEditing = true;
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: _isEditing,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            filled: true,
            fillColor: _isEditing ? Colors.white : Colors.grey[200],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    Color iconColor = Colors.blue,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(value),
      ),
    );
  }
}