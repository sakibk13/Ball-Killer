import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../models/player.dart';
import '../models/ball_record.dart';
import '../utils/status_dialog.dart';

class PlayerBallLossScreen extends StatefulWidget {
  final Player? initialPlayer;
  const PlayerBallLossScreen({super.key, this.initialPlayer});

  @override
  State<PlayerBallLossScreen> createState() => _PlayerBallLossScreenState();
}

class _PlayerBallLossScreenState extends State<PlayerBallLossScreen> with SingleTickerProviderStateMixin {
  Player? _selectedPlayer;
  DateTime _selectedDate = DateTime.now();
  int _amount = 0;
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;
  
  String _selectedMonthYear = 'Overall';
  late List<String> _monthList;

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    _tabController = TabController(length: 3, vsync: this);
    _selectedPlayer = widget.initialPlayer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).init();
    });
  }

  void _generateMonthList() {
    _monthList = ['Overall'];
    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      DateTime date = DateTime(now.year, now.month - i, 1);
      _monthList.add(DateFormat('MMMM yyyy').format(date));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _saveRecord() async {
    if (_selectedPlayer == null) {
      StatusDialog.show(context, message: "Please select a player first.", isSuccess: false, title: "MISSING INFO");
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ballProvider = Provider.of<BallProvider>(context, listen: false);

    await ballProvider.addBallRecordWithDate(
      playerId: _selectedPlayer!.id!,
      playerName: _selectedPlayer!.name,
      lostCount: _amount,
      date: _selectedDate,
      recordedBy: auth.currentUser?.name ?? 'Admin',
      note: _noteController.text,
    );

    if (mounted) {
      StatusDialog.show(
        context, 
        message: "${_amount.abs()} ball(s) ${_amount >= 0 ? 'added' : 'removed'} for ${_selectedPlayer!.name}.", 
        isSuccess: true, 
        title: "RECORD SAVED",
      );
      setState(() {
        _amount = 0;
        _noteController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;
    final players = ballProvider.players;
    final filteredPlayers = players.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('RECORD LOSS', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
          tabs: [
            if (isAdmin) const Tab(text: 'RECORD'),
            const Tab(text: 'HISTORY'),
            if (isAdmin) const Tab(text: 'MANAGE'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: () async {
              await ballProvider.refresh();
            },
            color: Colors.orange,
            child: TabBarView(
              controller: _tabController,
              children: [
                if (isAdmin) _buildRecordTab(filteredPlayers, ballProvider),
                _buildHistoryTab(ballProvider.allRecords),
                if (isAdmin) _buildManageTab(ballProvider.allRecords, ballProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordTab(List<Player> filteredPlayers, BallProvider ballProvider) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('1. SELECT PLAYER'),
          const SizedBox(height: 12),
          _buildPlayerSelector(filteredPlayers),
          const SizedBox(height: 25),
          _buildSectionHeader('2. LOG DETAILS'),
          const SizedBox(height: 12),
          _buildLogInputs(),
          const SizedBox(height: 30),
          _buildSaveButton(ballProvider.isLoading),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(List<BallRecord> allRecords) {
    final filteredRecords = _selectedMonthYear == 'Overall' 
        ? allRecords 
        : allRecords.where((r) => r.monthYear == _selectedMonthYear).toList();

    final totalLost = filteredRecords.fold(0, (sum, r) => sum + r.lostCount);

    // Group records by month, then by date
    Map<String, Map<String, List<BallRecord>>> grouped = {};
    final sortedRecords = List<BallRecord>.from(filteredRecords)..sort((a, b) => b.date.compareTo(a.date));

    for (var r in sortedRecords) {
      String monthKey = DateFormat('MMMM yyyy').format(r.date).toUpperCase();
      String dateKey = DateFormat('yyyy-MM-dd').format(r.date);
      grouped.putIfAbsent(monthKey, () => {});
      grouped[monthKey]!.putIfAbsent(dateKey, () => []);
      grouped[monthKey]![dateKey]!.add(r);
    }

    final monthKeys = grouped.keys.toList();

    return Column(
      children: [
        _buildMonthPicker(),
        _buildStatsHeader(totalLost),
        Expanded(
          child: monthKeys.isEmpty 
            ? Center(child: Text('No history found', style: GoogleFonts.poppins(color: Colors.white24)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: monthKeys.length,
                itemBuilder: (context, mIndex) {
                  final monthStr = monthKeys[mIndex];
                  final dailyData = grouped[monthStr]!;
                  final dateKeys = dailyData.keys.toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 16, bottom: 12),
                        child: Row(
                          children: [
                            Container(width: 4, height: 18, color: Colors.orange),
                            const SizedBox(width: 10),
                            Text(monthStr, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      ...dateKeys.map((dateStr) {
                        final dayRecords = dailyData[dateStr]!;
                        final date = DateTime.parse(dateStr);
                        final dailyTotal = dayRecords.fold(0, (sum, r) => sum + r.lostCount);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF020C3B),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(DateFormat('EEEE, dd MMMM').format(date).toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 14, letterSpacing: 1)),
                                    Text('TOTAL: $dailyTotal', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 14)),
                                  ],
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: dayRecords.length,
                                itemBuilder: (context, i) {
                                  final r = dayRecords[i];
                                  return ListTile(
                                    dense: true,
                                    title: Row(
                                      children: [
                                        Text(r.playerName.toUpperCase(), style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        const Spacer(),
                                        Text('${r.lostCount > 0 ? "+" : ""}${r.lostCount}', style: GoogleFonts.bebasNeue(color: r.lostCount >= 0 ? Colors.redAccent : Colors.greenAccent, fontSize: 16)),
                                      ],
                                    ),
                                    subtitle: r.note.isNotEmpty ? Text(r.note, style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)) : null,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildManageTab(List<BallRecord> records, BallProvider provider) {
    if (records.isEmpty) {
      return Center(child: Text('No records found', style: GoogleFonts.poppins(color: Colors.white24)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, i) => _buildRecordCard(records[i], provider, true),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF020C3B),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _monthList.length,
        itemBuilder: (context, index) {
          final m = _monthList[index];
          final isSelected = _selectedMonthYear == m;
          String display = m == 'Overall' ? 'OVERALL' : m.toUpperCase();
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthYear = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: isSelected ? const LinearGradient(colors: [Colors.orange, Colors.deepOrange]) : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? Colors.orange : Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(display, style: GoogleFonts.bebasNeue(color: isSelected ? Colors.white : Colors.white38, fontSize: 14)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsHeader(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
      decoration: const BoxDecoration(color: Color(0xFF020C3B)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('TOTAL BALLS LOST', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 14, letterSpacing: 1.2)),
          Text('$total', style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 24)),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BallRecord r, BallProvider provider, bool showActions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 45, height: 45,
            decoration: BoxDecoration(color: (r.lostCount >= 0 ? Colors.redAccent : Colors.greenAccent).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text('${r.lostCount > 0 ? "+" : ""}${r.lostCount}', style: GoogleFonts.bebasNeue(color: r.lostCount >= 0 ? Colors.redAccent : Colors.greenAccent, fontSize: 18)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.playerName.toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16, letterSpacing: 0.5)),
                Text(DateFormat('dd MMM yyyy, hh:mm a').format(r.date), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                if (r.note.isNotEmpty) Text(r.note, style: const TextStyle(color: Colors.orange, fontSize: 10, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20), onPressed: () => _showEditDialog(r, provider)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20), onPressed: () => _showDeleteConfirm(r, provider)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: Colors.orange),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildPlayerSelector(List<Player> players) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search player...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search, color: Colors.orange, size: 18),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: players.length,
              itemBuilder: (context, i) {
                final p = players[i];
                final isSelected = _selectedPlayer?.id == p.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPlayer = p),
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: isSelected ? Colors.orange : Colors.white10,
                          backgroundImage: p.photoUrl.isNotEmpty ? MemoryImage(base64Decode(p.photoUrl)) : null,
                          child: p.photoUrl.isEmpty ? Text(p.name[0], style: TextStyle(color: isSelected ? Colors.white : Colors.orange)) : null,
                        ),
                        const SizedBox(height: 5),
                        Text(p.name.split(' ')[0], style: TextStyle(color: isSelected ? Colors.orange : Colors.white70, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogInputs() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loss Date', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      Text(DateFormat('dd MMMM, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Icon(Icons.calendar_today, color: Colors.orange, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COUNT (INC/DEC)', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 16, letterSpacing: 1)),
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => setState(() => _amount--)),
                    Container(
                      constraints: const BoxConstraints(minWidth: 40),
                      alignment: Alignment.center,
                      child: Text('$_amount', style: GoogleFonts.bebasNeue(color: _amount >= 0 ? Colors.orange : Colors.redAccent, fontSize: 24)),
                    ),
                    IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent), onPressed: () => setState(() => _amount++)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Optional Note',
              labelStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.orange, size: 18),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : _saveRecord,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 8),
        child: isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text('SAVE RECORD', style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 1.2, color: Colors.white)),
      ),
    );
  }

  void _showEditDialog(BallRecord record, BallProvider provider) {
    int newCount = record.lostCount;
    DateTime newDate = record.date;
    final editNoteController = TextEditingController(text: record.note);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF020C3B),
          title: Text('EDIT RECORD', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('dd MMM yyyy').format(newDate), style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.calendar_today, color: Colors.orange),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: newDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) setDialogState(() => newDate = picked);
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('COUNT', style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => setDialogState(() => newCount--)),
                      Text('$newCount', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 24)),
                      IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent), onPressed: () => setDialogState(() => newCount++)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editNoteController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Note',
                  labelStyle: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            TextButton(
              onPressed: () async {
                final updated = BallRecord(
                  id: record.id,
                  playerId: record.playerId,
                  playerName: record.playerName,
                  lostCount: newCount,
                  date: newDate,
                  recordedBy: record.recordedBy,
                  monthYear: DateFormat('MMMM yyyy').format(newDate),
                  note: editNoteController.text,
                );
                await provider.updateRecord(updated, record.lostCount);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('UPDATE', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BallRecord record, BallProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE RECORD?', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1)),
        content: const Text('Are you sure you want to delete this ball record?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final adminName = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';
              await provider.deleteRecord(record.id!, record.playerId, record.lostCount, adminName);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
