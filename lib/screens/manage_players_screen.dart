import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../models/player.dart';
import '../utils/status_dialog.dart';

class ManagePlayersScreen extends StatefulWidget {
  const ManagePlayersScreen({super.key});

  @override
  State<ManagePlayersScreen> createState() => _ManagePlayersScreenState();
}

class _ManagePlayersScreenState extends State<ManagePlayersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).init();
    });
  }

  void _showAddPlayerSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String base64Image = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          decoration: const BoxDecoration(color: Color(0xFF020C3B), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Text('ADD NEW PLAYER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1.2)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                    if (image != null) {
                      final bytes = await File(image.path).readAsBytes();
                      setModalState(() { base64Image = base64Encode(bytes); });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        backgroundImage: base64Image.isNotEmpty ? MemoryImage(base64Decode(base64Image)) : null,
                        child: base64Image.isEmpty ? const Icon(Icons.add_a_photo, color: Colors.white24, size: 30) : null,
                      ),
                      if (base64Image.isNotEmpty) Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.white, size: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                _buildPopInput(nameCtrl, 'Full Name', Icons.person_outline),
                const SizedBox(height: 12),
                _buildPopInput(phoneCtrl, 'Phone Number', Icons.phone_outlined, keyboard: TextInputType.phone),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                      final player = Player(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        photoUrl: base64Image,
                        totalLost: 0,
                      );
                      await Provider.of<BallProvider>(context, listen: false).addPlayerDirect(player);
                      if (mounted) {
                        Navigator.pop(context);
                        StatusDialog.show(
                          context, 
                          message: "A new player has been added to the club.", 
                          isSuccess: true, 
                          title: "PLAYER ADDED",
                          gifAsset: 'assets/added.gif',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: Text('SAVE PLAYER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSheet(Player player) {
    final nameCtrl = TextEditingController(text: player.name);
    final phoneCtrl = TextEditingController(text: player.phone);
    final passCtrl = TextEditingController(text: player.password);
    String base64Image = player.photoUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          decoration: const BoxDecoration(color: Color(0xFF020C3B), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Text('EDIT PLAYER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                    if (image != null) {
                      final bytes = await File(image.path).readAsBytes();
                      setModalState(() { base64Image = base64Encode(bytes); });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        backgroundImage: base64Image.isNotEmpty ? MemoryImage(base64Decode(base64Image)) : null,
                        child: base64Image.isEmpty ? const Icon(Icons.person, color: Colors.white24, size: 40) : null,
                      ),
                      Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                _buildPopInput(nameCtrl, 'Name (Optional)', Icons.person_outline),
                const SizedBox(height: 12),
                _buildPopInput(phoneCtrl, 'Phone (Optional)', Icons.phone_outlined, keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                _buildPopInput(passCtrl, 'Password (Optional)', Icons.lock_outline, keyboard: TextInputType.number),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final updated = Player(
                        id: player.id,
                        name: nameCtrl.text.trim().isEmpty ? player.name : nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim().isEmpty ? player.phone : phoneCtrl.text.trim(),
                        password: passCtrl.text.trim().isEmpty ? player.password : passCtrl.text.trim(),
                        photoUrl: base64Image,
                        totalLost: player.totalLost,
                      );
                      await Provider.of<BallProvider>(context, listen: false).updatePlayer(updated);
                      
                      if (auth.currentUser?.phone == player.phone) {
                        await auth.refreshUser();
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        StatusDialog.show(
                          context, 
                          message: "Player details updated successfully.", 
                          isSuccess: true, 
                          title: "PROFILE UPDATED",
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
                    child: Text('UPDATE PLAYER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(Player player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE PLAYER?', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1)),
        content: Text('Are you sure you want to remove ${player.name} from the system? This will also delete their login account.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<BallProvider>(context, listen: false).deletePlayer(player.id!, player.phone);
              if (mounted) {
                StatusDialog.show(context, message: "Player removed successfully.", isSuccess: true, title: "PLAYER DELETED");
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildPopInput(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.orange, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BallProvider>(context);
    final players = provider.players;
    final filtered = players.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('MANAGE PLAYERS', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search player...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.search, color: Colors.orange),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.refresh(),
                  color: Colors.orange,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final player = filtered[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                        child: Row(
                          children: [
                            Text('${i + 1}.', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 16)),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              backgroundImage: player.photoUrl.isNotEmpty ? MemoryImage(base64Decode(player.photoUrl)) : null,
                              child: player.photoUrl.isEmpty ? Text(player.name[0], style: const TextStyle(color: Colors.orange)) : null,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(player.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(player.phone, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20), onPressed: () => _showEditSheet(player)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _showDeleteConfirm(player)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddPlayerSheet, backgroundColor: Colors.orange, child: const Icon(Icons.person_add, color: Colors.white)),
    );
  }
}
