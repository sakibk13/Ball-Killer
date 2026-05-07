import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/database_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isAutoLoginChecking = true;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  void _initAuth() async {
    await DatabaseService().connect();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.tryAutoLogin();
    if (mounted) {
      setState(() => _isAutoLoginChecking = false);
    }
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.bebasNeue(color: Colors.redAccent, letterSpacing: 1)),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 15),
              const Text("Troubleshooting:", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              const Text("1. Enable Firestore in Firebase Console.", style: TextStyle(color: Colors.white38, fontSize: 11)),
              const Text("2. Set Rules to 'allow read, write: if true;'.", style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('RETRY', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      bool success;
      if (_isLogin) {
        success = await authProvider.login(_phoneController.text, _passwordController.text);
      } else {
        success = await authProvider.register(_nameController.text, _phoneController.text, _passwordController.text);
      }

      if (success && mounted) {
        Provider.of<BallProvider>(context, listen: false).init(force: true);
        Provider.of<ContributionProvider>(context, listen: false).fetchContributions(force: true);
        Provider.of<InventoryProvider>(context, listen: false).fetchInventory(force: true);
      } else if (mounted) {
        _showError(
          'AUTH FAILED', 
          _isLogin ? 'Incorrect phone or password.' : 'Phone number already exists.'
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('FIREBASE ERROR', e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const String quote = "খেলাধুলায় বাড়ে বল, মাদক ছেড়ে খেলতে চল।";

    if (_isAutoLoginChecking) {
      return Scaffold(
        backgroundColor: const Color(0xFF020C3B),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020C3B), Color(0xFF051970)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo2.png', width: 180, height: 180, errorBuilder: (c, e, s) => const Icon(Icons.sports_cricket, size: 100, color: Colors.orange)),
              const SizedBox(height: 20),
              Text(
                quote,
                textAlign: TextAlign.center,
                style: GoogleFonts.hindSiliguri(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.orange),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020C3B),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF020C3B), Color(0xFF051970)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo2.png', width: 150, height: 150, errorBuilder: (c, e, s) => const Icon(Icons.sports_cricket, size: 80, color: Colors.orange)),
                    const SizedBox(height: 20),
                    Text(
                      quote,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hindSiliguri(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 30),
                    Text('BALL KILLER', style: GoogleFonts.bebasNeue(fontSize: 40, color: Colors.white, letterSpacing: 3)),
                    const SizedBox(height: 40),
                    if (!_isLogin) ...[
                      _buildInput(_nameController, 'Full Name', Icons.person),
                      const SizedBox(height: 15),
                    ],
                    _buildInput(_phoneController, 'Phone Number', Icons.phone, keyboard: TextInputType.phone),
                    const SizedBox(height: 15),
                    _buildInput(_passwordController, 'Password', Icons.lock, isPass: true, keyboard: TextInputType.number),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: Provider.of<AuthProvider>(context).isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Provider.of<AuthProvider>(context).isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_isLogin ? 'LOGIN' : 'REGISTER', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin ? "New here? Create Account" : "Already have account? Login", style: const TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _submitGuest,
                        icon: const Icon(Icons.visibility_outlined, color: Colors.orange, size: 20),
                        label: Text('GUEST EXPLORATION', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16, letterSpacing: 1.5)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitGuest() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loginAsGuest();
    
    if (mounted) {
      Provider.of<BallProvider>(context, listen: false).init(force: true);
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions(force: true);
      Provider.of<InventoryProvider>(context, listen: false).fetchInventory(force: true);
    }
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {bool isPass = false, TextInputType? keyboard}) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPass,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.orange),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }
}