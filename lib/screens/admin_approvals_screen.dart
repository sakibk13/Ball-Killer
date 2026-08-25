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
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0C1640), Color(0xFF040A26)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.2), width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.4), width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: user.photoUrl.isNotEmpty ? MemoryImage(base64Decode(user.photoUrl)) : null,
                                  child: user.photoUrl.isEmpty ? Text(user.name[0].toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.orangeAccent, fontSize: 20)) : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(user.phone, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _handleApproval(user, 'approved'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 0.8),
                                      ),
                                      child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  InkWell(
                                    onTap: () => _handleApproval(user, 'rejected'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 0.8),
                                      ),
                                      child: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
                                    ),
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
