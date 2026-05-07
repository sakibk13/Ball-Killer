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
  final _passwordController = TextEditingController();
  bool _isProcessing = false;

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
          SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Avatar Section
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orange, width: 2)),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white10,
                          backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                          child: photoBytes == null ? Text(user?.name[0].toUpperCase() ?? '?', style: GoogleFonts.bebasNeue(fontSize: 40, color: Colors.orange)) : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(user?.name.toUpperCase() ?? '', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, letterSpacing: 1.5)),
                Text(user?.phone ?? '', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14)),
                
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
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _updatePassword,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: Text('UPDATE PASSWORD', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 40),
                TextButton.icon(
                  onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: Text('LOGOUT ACCOUNT', style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 16)),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.orange))),
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
