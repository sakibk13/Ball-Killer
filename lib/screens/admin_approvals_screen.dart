import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../utils/status_dialog.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  List<User> _pendingUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingUsers();
  }

  Future<void> _fetchPendingUsers() async {
    setState(() => _isLoading = true);
    final users = await DatabaseService().getPendingUsers();
    setState(() {
      _pendingUsers = users;
      _isLoading = false;
    });
  }

  void _handleApproval(User user, String status) async {
    final success = await DatabaseService().updateUserStatus(user.id!, status);
    if (success) {
      StatusDialog.show(context, title: "SUCCESS", message: "User $status successfully!", isSuccess: true);
      _fetchPendingUsers();
    } else {
      StatusDialog.show(context, title: "ERROR", message: "Failed to update user status", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('PENDING APPROVALS', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : RefreshIndicator(
                onRefresh: _fetchPendingUsers,
                color: Colors.orange,
                child: _pendingUsers.isEmpty
                  ? Center(child: Text('No pending approvals', style: GoogleFonts.poppins(color: Colors.white24)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _pendingUsers.length,
                      itemBuilder: (context, i) {
                        final user = _pendingUsers[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.white10,
                                backgroundImage: user.photoUrl.isNotEmpty ? MemoryImage(base64Decode(user.photoUrl)) : null,
                                child: user.photoUrl.isEmpty ? Text(user.name[0], style: const TextStyle(color: Colors.orange)) : null,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(user.phone, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                                    onPressed: () => _handleApproval(user, 'approved'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                                    onPressed: () => _handleApproval(user, 'rejected'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
        ),
      ),
    );
  }
}
