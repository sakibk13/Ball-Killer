import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../utils/status_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 400);
    
    if (image != null) {
      setState(() => _isProcessing = true);
      try {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final success = await Provider.of<AuthProvider>(context, listen: false).updateProfile(photoUrl: base64String);
        
        if (mounted) {
          StatusDialog.show(
            context, 
            isSuccess: success, 
            title: success ? "SUCCESS" : "ERROR", 
            message: success ? "Profile photo updated!" : "Failed to update photo.",
          );
        }
      } catch (e) {
        if (mounted) StatusDialog.show(context, isSuccess: false, title: "ERROR", message: e.toString());
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _updateInfo() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      StatusDialog.show(context, isSuccess: false, title: "INVALID", message: "Name and Phone are required.");
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final success = await Provider.of<AuthProvider>(context, listen: false).updateProfile(
        name: _nameController.text,
        newPhone: _phoneController.text,
      );
      if (mounted) {
        StatusDialog.show(
          context, 
          isSuccess: success, 
          title: success ? "SUCCESS" : "ERROR", 
          message: success ? "Profile updated successfully!" : "Failed to update profile.",
        );
      }
    } catch (e) {
      if (mounted) StatusDialog.show(context, isSuccess: false, title: "ERROR", message: e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_passwordController.text.length < 4) {
      StatusDialog.show(context, isSuccess: false, title: "INVALID", message: "Password must be at least 4 characters.");
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final success = await Provider.of<AuthProvider>(context, listen: false).updatePassword(_passwordController.text);
      if (mounted) {
        StatusDialog.show(
          context, 
          isSuccess: success, 
          title: success ? "SUCCESS" : "ERROR", 
          message: success ? "Password changed successfully!" : "Failed to update password.",
        );
        if (success) _passwordController.clear();
      }
    } catch (e) {
      if (mounted) StatusDialog.show(context, isSuccess: false, title: "ERROR", message: e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    Uint8List? photoBytes;
    if (user?.photoUrl != null && user!.photoUrl.isNotEmpty) {
      try { photoBytes = base64Decode(user.photoUrl); } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('MY PROFILE', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Avatar Section
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, 
                              gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.tealAccent]),
                              boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20)],
                            ),
                            child: CircleAvatar(
                              radius: 65,
                              backgroundColor: const Color(0xFF020C3B),
                              backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                              child: photoBytes == null ? Text(user?.name[0].toUpperCase() ?? '?', style: GoogleFonts.bebasNeue(fontSize: 45, color: Colors.tealAccent)) : null,
                            ),
                          ),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF020C3B), size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Info Section
                    _buildSectionHeader('PERSONAL INFORMATION'),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('Full Name', Icons.person_outline),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: _inputDeco('Phone Number', Icons.phone_android_outlined),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _updateInfo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        child: Text('SAVE CHANGES', style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B), fontSize: 18, letterSpacing: 1)),
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Settings Section
                    _buildSectionHeader('SECURITY SETTINGS'),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('New Password', Icons.lock_outline),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _updatePassword,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text('CHANGE PASSWORD', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 50),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      label: Text('LOGOUT ACCOUNT', style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 16, letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54, 
              child: const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: Colors.orange),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 16, letterSpacing: 1.2)),
      ],
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: Icon(icon, color: Colors.orange, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.orange)),
    );
  }
}
