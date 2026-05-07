import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../models/player.dart';

class RecordLossScreen extends StatefulWidget {
  const RecordLossScreen({super.key});

  @override
  State<RecordLossScreen> createState() => _RecordLossScreenState();
}

class _RecordLossScreenState extends State<RecordLossScreen> {
  Player? _selectedPlayer;
  final _countController = TextEditingController(text: '1');
  final _searchController = TextEditingController();
  final bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Provider.of<BallProvider>(context, listen: false).fetchPlayers();
  }

  @override
  void dispose() {
    _countController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _recordLoss() async {
    if (_selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a player'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ballProvider = Provider.of<BallProvider>(context, listen: false);

    try {
      await ballProvider.addBallRecord(
        playerName: _selectedPlayer!.name,
        lostCount: int.parse(_countController.text),
        recordedBy: authProvider.currentUser?.name ?? 'Unknown',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loss recorded successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context);
    
    final filteredPlayers = ballProvider.players.where((player) {
      return player.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             player.phone.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('RECORD LOSS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
      ),
      body: ballProvider.isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. SELECT PLAYER',
                  style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 18),
                ),
                const SizedBox(height: 12),
                
                // Search Box
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search player...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Player Selection List
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListView.builder(
                      itemCount: filteredPlayers.length,
                      itemBuilder: (context, index) {
                        final player = filteredPlayers[index];
                        final isSelected = _selectedPlayer?.id == player.id;
                        return ListTile(
                          onTap: () => setState(() => _selectedPlayer = player),
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? Colors.orange : Colors.white10,
                            child: Text(
                              player.name[0], 
                              style: TextStyle(color: isSelected ? Colors.white : Colors.white70)
                            ),
                          ),
                          title: Text(
                            player.name, 
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.orange : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            )
                          ),
                          subtitle: Text(player.phone, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.orange) : null,
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                Text(
                  '2. HOW MANY BALLS?',
                  style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 18),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    _CountBtn(
                      icon: Icons.remove, 
                      onTap: () {
                        int val = int.tryParse(_countController.text) ?? 1;
                        if (val > 1) _countController.text = (val - 1).toString();
                      }
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _countController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 32),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _CountBtn(
                      icon: Icons.add, 
                      onTap: () {
                        int val = int.tryParse(_countController.text) ?? 0;
                        _countController.text = (val + 1).toString();
                      }
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: ballProvider.isLoading ? null : _recordLoss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: Colors.orange.withOpacity(0.5),
                    ),
                    child: ballProvider.isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('CONFIRM LOSS', style: GoogleFonts.bebasNeue(fontSize: 22, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CountBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Icon(icon, color: Colors.orange, size: 30),
      ),
    );
  }
}
