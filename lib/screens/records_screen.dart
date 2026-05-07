import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/auth_provider.dart';
import '../models/ball_record.dart';
import '../utils/date_utils.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> with TickerProviderStateMixin {
  final String _selectedMonthYear = 'Overall';
  List<String> _monthList = ['Overall'];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() async {
    final ballProvider = Provider.of<BallProvider>(context, listen: false);
    await ballProvider.fetchAllRecords();
    _updateMonthList(ballProvider);
  }

  void _updateMonthList(BallProvider ballProvider) {
    Set<String> months = {};
    for (var r in ballProvider.allRecords) {
      if (r.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
      }
    }
    
    months.add(DateFormat('MMMM yyyy').format(DateTime.now()));
    DateTime prevMonth = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
    months.add(DateFormat('MMMM yyyy').format(prevMonth));

    List<String> sortedMonths = months.toList();
    sortedMonths.sort((a, b) {
      try {
        DateTime da = DateFormat('MMMM yyyy').parse(a);
        DateTime db = DateFormat('MMMM yyyy').parse(b);
        return db.compareTo(da);
      } catch (_) {
        return b.compareTo(a);
      }
    });
    
    final newList = ['Overall', ...sortedMonths];
    
    if (newList.length != _monthList.length) {
      setState(() {
        _monthList = newList;
        _tabController?.dispose();
        _tabController = TabController(length: _monthList.length, vsync: this);
        
        // Try to select current month if it's a new load
        String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
        int index = _monthList.indexOf(currentMonth);
        if (index != -1) {
          _tabController!.index = index;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context);
    
    // Check if we need to update month list if records changed
    if (ballProvider.allRecords.isNotEmpty && _monthList.length <= 3) {
       // This is a bit hacky, but avoids infinite setStates if handled carefully
       // Better to do this in Provider or with a listener
    }

    if (_tabController == null || _tabController!.length != _monthList.length) {
       _tabController = TabController(length: _monthList.length, vsync: this);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('TRACK OVERVIEW', style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
          tabs: _monthList.map((m) {
            String display = m == 'Overall' ? 'OVERALL' : m.toUpperCase();
            return Tab(text: display);
          }).toList(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: () => ballProvider.refresh().then((_) => _updateMonthList(ballProvider)),
            color: Colors.tealAccent,
            child: TabBarView(
              controller: _tabController,
              children: _monthList.map((m) => _buildMonthTable(m, ballProvider.allRecords)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthTable(String monthYear, List<BallRecord> allRecords) {
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;
    final normalizedSearchMonth = DateUtilsHelper.normalizeMonthYear(monthYear);
    
    final filteredRecords = normalizedSearchMonth == 'Overall' 
        ? allRecords 
        : allRecords.where((r) => DateUtilsHelper.normalizeMonthYear(r.monthYear) == normalizedSearchMonth).toList();

    if (filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded, size: 100, color: Colors.white10),
            const SizedBox(height: 16),
            Text('NO RECORDS FOUND', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 24, letterSpacing: 2)),
          ],
        ),
      );
    }

    // Sort by date descending
    final sorted = List<BallRecord>.from(filteredRecords)..sort((a, b) => b.date.compareTo(a.date));
    
    // Group by Date
    Map<String, List<BallRecord>> groupedByDate = {};
    for (var r in sorted) {
      String dateStr = DateFormat('yyyy-MM-dd').format(r.date);
      groupedByDate.putIfAbsent(dateStr, () => []);
      groupedByDate[dateStr]!.add(r);
    }

    // Sort dates descending
    var dates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        String dateKey = dates[index];
        DateTime date = DateTime.parse(dateKey);
        List<BallRecord> records = groupedByDate[dateKey]!;

        // NET CALCULATION: Group by player and sum lostCount
        Map<String, int> summarized = {};
        Map<String, List<BallRecord>> originalRecords = {}; 
        for (var r in records) {
          summarized[r.playerName] = (summarized[r.playerName] ?? 0) + r.lostCount;
          originalRecords.putIfAbsent(r.playerName, () => []);
          originalRecords[r.playerName]!.add(r);
        }

        // FILTER: Only show players who have a Net Loss > 0
        var playerNames = summarized.keys.where((name) => summarized[name]! > 0).toList()..sort();
        
        if (playerNames.isEmpty) return const SizedBox.shrink();

        // Calculate Daily Grand Total
        int dailyGrandTotal = playerNames.fold(0, (sum, name) => sum + summarized[name]!);

        return Container(
          margin: const EdgeInsets.only(bottom: 25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Date Card
              Container(
                width: 65,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF020C3B), Color(0xFF051970)]),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(DateFormat('MMM').format(date).toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14)),
                    Text(DateFormat('dd').format(date), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, height: 1)),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              // List of records
              Expanded(
                child: Column(
                  children: [
                    ...playerNames.map((name) {
                      final totalLost = summarized[name];
                      final originals = originalRecords[name]!;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name[0].toUpperCase() + name.substring(1).toLowerCase(), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (originals.length > 1 && !Provider.of<AuthProvider>(context, listen: false).isGuest)
                                    Text('${originals.length} entries summarized', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('$totalLost', style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 18)),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 10),
                              _buildActionIcon(Icons.edit_outlined, Colors.blueAccent, () => _showEditRecordDialog(context, originals.first)),
                              const SizedBox(width: 5),
                              _buildActionIcon(Icons.delete_outline, Colors.redAccent, () => _showDeleteRecordDialog(context, originals.first)),
                            ],
                          ],
                        ),
                      );
                    }),
                    // GRAND TOTAL ROW
                    if (!Provider.of<AuthProvider>(context, listen: false).isGuest)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('DAILY GRAND TOTAL', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14, letterSpacing: 1)),
                            Text('$dailyGrandTotal', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showEditRecordDialog(BuildContext context, BallRecord record) {
    final controller = TextEditingController(text: record.lostCount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('EDIT RECORD', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PLAYER: ${record.playerName}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'LOST BALLS',
                labelStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
            onPressed: () {
              int? newVal = int.tryParse(controller.text);
              if (newVal != null) {
                final updatedRecord = BallRecord(
                  id: record.id,
                  playerId: record.playerId,
                  playerName: record.playerName,
                  lostCount: newVal,
                  date: record.date,
                  recordedBy: record.recordedBy,
                  monthYear: record.monthYear,
                  note: record.note,
                );
                Provider.of<BallProvider>(context, listen: false).updateRecord(updatedRecord, record.lostCount);
                Navigator.pop(ctx);
              }
            },
            child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteRecordDialog(BuildContext context, BallRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE RECORD', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        content: Text('Are you sure you want to delete this record for ${record.playerName}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              final adminName = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';
              Provider.of<BallProvider>(context, listen: false).deleteRecord(record.id!, record.playerId, record.lostCount, adminName);
              Navigator.pop(ctx);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
