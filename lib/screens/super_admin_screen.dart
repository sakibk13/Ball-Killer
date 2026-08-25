import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../providers/ball_provider.dart';
import '../services/database_service.dart';
import '../models/user.dart';
import '../utils/status_dialog.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<User> _allUsers = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUsers();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final users = await DatabaseService().getAllUsers();
      setState(() {
        _allUsers = users;
        _isLoadingUsers = false;
      });
    } catch (_) {
      setState(() => _isLoadingUsers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final roomProv = Provider.of<RoomProvider>(context);

    if (!authProv.isSuperAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF051970),
        body: Center(
          child: Text('ACCESS DENIED. SUPER ADMIN ONLY.', style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 24)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent),
            const SizedBox(width: 10),
            Text('SUPER ADMIN CONTROL CENTER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 22, letterSpacing: 1.2)),
          ],
        ),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.tealAccent),
            onPressed: () {
              _fetchUsers();
              roomProv.fetchAllRooms();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1),
          tabs: const [
            Tab(text: 'ALL USERS & PASSWORDS'),
            Tab(text: 'ALL CLUBS & ROOMS'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUsersTab(),
              _buildRoomsTab(roomProv),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    final search = _searchController.text.toLowerCase();
    final filtered = _allUsers.where((u) {
      return u.name.toLowerCase().contains(search) || u.phone.contains(search);
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF020C3B),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users by Name or Phone...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.amberAccent),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : filtered.isEmpty
                  ? Center(child: Text('No users found', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 20)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final u = filtered[i];
                        bool isSuper = u.phone == '01832465446';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF020C3B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSuper ? Colors.amberAccent : Colors.white10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isSuper ? Colors.amberAccent.withOpacity(0.2) : Colors.tealAccent.withOpacity(0.1),
                                child: Icon(isSuper ? Icons.star_rounded : Icons.person_rounded, color: isSuper ? Colors.amberAccent : Colors.tealAccent),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(u.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                        if (isSuper) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(6)),
                                            child: Text('SUPER ADMIN', style: GoogleFonts.bebasNeue(color: Colors.black, fontSize: 10)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Phone: ${u.phone}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text('Password: ${u.password}', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14, letterSpacing: 1)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRoomsTab(RoomProvider roomProv) {
    final rooms = roomProv.allRooms;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      itemBuilder: (ctx, i) {
        final r = rooms[i];
        bool isActive = r.code == roomProv.currentRoomCode;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isActive ? Colors.tealAccent : Colors.white10, width: isActive ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.tealAccent.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.meeting_room_rounded, color: isActive ? Colors.tealAccent : Colors.white38, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                          child: Text(r.code, style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 12, letterSpacing: 1.2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Admin Phone: ${r.adminPhone}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await roomProv.switchRoom(r.code);
                  if (mounted) {
                    Provider.of<BallProvider>(context, listen: false).init(force: true);
                    StatusDialog.show(context, title: "ROOM SWITCHED", message: "Switched to Room: ${r.code}", isSuccess: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.teal : Colors.white10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isActive ? 'ACTIVE' : 'ENTER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 14)),
              ),
            ],
          ),
        );
      },
    );
  }
}
