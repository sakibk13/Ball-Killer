import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';
import '../utils/string_utils.dart';
import '../utils/date_utils.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late List<String> _monthList;
  String _selectedMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       Provider.of<BallProvider>(context, listen: false).fetchAllRecords();
    });
  }

  void _generateMonthList() {
    _monthList = ['Overall'];
    final ballProvider = Provider.of<BallProvider>(context, listen: false);
    
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
    
    _monthList.addAll(sortedMonths);
  }

  @override
  Widget build(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context);
    final displayData = ballProvider.getMonthlyLeaderboard(_selectedMonthYear);

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('TOP PLAYERS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.tealAccent),
            onPressed: () async {
              try {
                final ballProvider = Provider.of<BallProvider>(context, listen: false);
                final displayData = ballProvider.getMonthlyLeaderboard(_selectedMonthYear);
                if (displayData.isNotEmpty) {
                  await ExportService.exportLeaderboard(
                    monthYear: _selectedMonthYear,
                    players: displayData,
                  );
                  if (mounted) {
                    StatusDialog.show(context, title: "SUCCESS", message: "Leaderboard PDF Generated!", isSuccess: true);
                  }
                } else {
                  if (mounted) {
                    StatusDialog.show(context, title: "INFO", message: "No data to export for this month", isSuccess: false);
                  }
                }
              } catch (e) {
                if (mounted) {
                  StatusDialog.show(context, title: "ERROR", message: "Failed: $e", isSuccess: false);
                }
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF020C3B),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _monthList.length,
                  itemBuilder: (context, index) {
                    final m = _monthList[index];
                    final isSelected = _selectedMonthYear == m;
                    String display = m == 'Overall' ? 'OVERALL' : m.toUpperCase();
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMonthYear = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.only(right: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        decoration: BoxDecoration(
                          gradient: isSelected ? const LinearGradient(colors: [Colors.tealAccent, Colors.blueAccent]) : null,
                          color: isSelected ? null : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: isSelected ? Colors.tealAccent.withOpacity(0.5) : Colors.white10),
                          boxShadow: isSelected ? [BoxShadow(color: Colors.tealAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))] : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(display, style: GoogleFonts.bebasNeue(color: isSelected ? const Color(0xFF051970) : Colors.white38, fontSize: 18, letterSpacing: 1.2)),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ballProvider.refresh(),
                  color: Colors.tealAccent,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (displayData.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildTopHighlight(displayData[0]),
                        ),
                      if (ballProvider.isLoading && displayData.isEmpty)
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
                        )
                      else if (displayData.isEmpty)
                        SliverFillRemaining(
                          child: Center(child: Text('No data found for this period', style: GoogleFonts.poppins(color: Colors.white24))),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = displayData[index];
                                final isTop = index < 3;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isTop ? Colors.cyanAccent.withOpacity(0.05) : const Color(0xFF020C3B),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isTop ? Colors.cyanAccent.withOpacity(0.3) : Colors.white10,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 25,
                                          child: Text('${index + 1}', style: GoogleFonts.bebasNeue(color: isTop ? Colors.cyanAccent : Colors.white24, fontSize: 16)),
                                        ),
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.white10,
                                          backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                                              ? MemoryImage(base64Decode(item['photoUrl']))
                                              : null,
                                          child: (item['photoUrl'] == null || item['photoUrl'].isEmpty)
                                              ? Text(item['name'][0].toUpperCase(), style: const TextStyle(color: Colors.cyanAccent, fontSize: 12))
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            StringUtils.capitalize(item['name']),
                                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: isTop ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isTop ? Colors.cyanAccent.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: isTop ? Colors.cyanAccent.withOpacity(0.3) : Colors.white10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('${item['total']}', style: GoogleFonts.bebasNeue(color: isTop ? Colors.cyanAccent : Colors.white70, fontSize: 18)),
                                              const SizedBox(width: 4),
                                              Icon(Icons.auto_delete, color: isTop ? Colors.cyanAccent : Colors.white24, size: 12),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: displayData.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHighlight(Map<String, dynamic> topPlayer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 25),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(50)),
        gradient: const LinearGradient(
          colors: [Color(0xFF001F3F), Color(0xFF051970)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Colors.cyanAccent, Colors.blueAccent]),
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 10)],
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF020C3B),
                  backgroundImage: topPlayer['photoUrl'] != null && topPlayer['photoUrl'].isNotEmpty
                      ? MemoryImage(base64Decode(topPlayer['photoUrl']))
                      : null,
                  child: (topPlayer['photoUrl'] == null || topPlayer['photoUrl'].isEmpty)
                      ? Text(topPlayer['name'][0].toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 36))
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF001F3F), 
                  shape: BoxShape.circle, 
                  border: Border.fromBorderSide(BorderSide(color: Colors.cyanAccent, width: 1.5)),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.cyanAccent, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            StringUtils.capitalize(topPlayer['name']), 
            textAlign: TextAlign.center,
            style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, letterSpacing: 1.2)
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 12),
                const SizedBox(width: 6),
                Text('CHAMPION OF THE MONTH', style: GoogleFonts.bebasNeue(color: Colors.cyanAccent, fontSize: 12, letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
