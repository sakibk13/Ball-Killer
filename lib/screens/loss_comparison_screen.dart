import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/ball_provider.dart';
import '../providers/unintentional_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/fund_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/auth_provider.dart';
import '../models/ball_record.dart';
import '../models/unintentional_record.dart';
import '../utils/date_utils.dart';
import '../utils/string_utils.dart';
import '../utils/excel_export_service.dart';
import '../utils/status_dialog.dart';
import 'unintentional_loss_screen.dart';
import 'player_ball_loss_screen.dart';

class LossComparisonScreen extends StatefulWidget {
  const LossComparisonScreen({super.key});

  @override
  State<LossComparisonScreen> createState() => _LossComparisonScreenState();
}

class _LossComparisonScreenState extends State<LossComparisonScreen> with SingleTickerProviderStateMixin {
  String _selectedMonthYear = 'Overall';
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).fetchAllRecords();
      Provider.of<UnintentionalProvider>(context, listen: false).fetchRecords();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportExcel() async {
    try {
      final ballProv = Provider.of<BallProvider>(context, listen: false);
      final unintProv = Provider.of<UnintentionalProvider>(context, listen: false);
      final fineProv = Provider.of<FineProvider>(context, listen: false);
      final contProv = Provider.of<ContributionProvider>(context, listen: false);
      final fundProv = Provider.of<FundProvider>(context, listen: false);
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      final authProv = Provider.of<AuthProvider>(context, listen: false);

      await ExcelExportService.exportComprehensiveExcel(
        scopeTitle: _selectedMonthYear,
        playerRecords: ballProv.allRecords,
        unintentionalRecords: unintProv.records,
        players: ballProv.players,
        finePayments: fineProv.payments,
        contributions: contProv.contributions,
        funds: fundProv.funds,
        inventoryList: invProv.inventoryList,
        exportedBy: authProv.currentUser?.name ?? 'Admin',
      );

      if (mounted) {
        StatusDialog.show(
          context,
          title: "EXCEL EXPORT READY",
          message: "Excel workbook ($_selectedMonthYear) generated successfully!",
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        StatusDialog.show(
          context,
          title: "EXPORT ERROR",
          message: "Failed to generate Excel: $e",
          isSuccess: false,
        );
      }
    }
  }

  List<String> _buildCombinedMonthList(List<BallRecord> playerRecords, List<UnintentionalRecord> unintRecords) {
    final Set<String> months = {'Overall'};
    for (var r in playerRecords) {
      if (r.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
      }
    }
    for (var r in unintRecords) {
      if (r.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
      }
    }

    final now = DateTime.now();
    months.add(DateFormat('MMMM yyyy').format(now));
    months.add(DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1, 1)));

    final list = months.toList();
    list.sort((a, b) {
      if (a == 'Overall') return -1;
      if (b == 'Overall') return 1;
      try {
        final da = DateFormat('MMMM yyyy').parse(a);
        final db = DateFormat('MMMM yyyy').parse(b);
        return db.compareTo(da);
      } catch (_) {
        return b.compareTo(a);
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ballProvider = Provider.of<BallProvider>(context);
    final unintProvider = Provider.of<UnintentionalProvider>(context);

    final allPlayerRecords = ballProvider.allRecords.where((r) => r.lostCount > 0).toList();
    final allUnintRecords = unintProvider.records.where((r) => r.lostCount > 0).toList();
    final monthList = _buildCombinedMonthList(allPlayerRecords, allUnintRecords);

    // Filter by selected month
    final filteredPlayerRecords = _selectedMonthYear == 'Overall'
        ? allPlayerRecords
        : allPlayerRecords.where((r) => r.lostCount > 0 && DateUtilsHelper.normalizeMonthYear(r.monthYear) == _selectedMonthYear).toList();

    final filteredUnintRecords = _selectedMonthYear == 'Overall'
        ? allUnintRecords
        : allUnintRecords.where((r) => r.lostCount > 0 && DateUtilsHelper.normalizeMonthYear(r.monthYear) == _selectedMonthYear).toList();

    // Calculate totals for selected period
    final totalPlayerLost = filteredPlayerRecords.fold(0, (sum, r) => sum + r.lostCount);
    final totalUnintentionalLost = filteredUnintRecords.fold(0, (sum, r) => sum + r.lostCount);
    final grandTotalLost = totalPlayerLost + totalUnintentionalLost;

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text(
          'LOSS ANALYTICS',
          style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2, fontSize: 22),
        ),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: Color(0xFF00E676)),
            tooltip: 'Export Excel Workbook',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.purpleAccent),
            tooltip: 'Add Unintentional Loss',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnintentionalLossScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sports_cricket_rounded, color: Colors.orange),
            tooltip: 'Record Player Loss',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlayerBallLossScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
          tabs: const [
            Tab(text: 'DAILY BREAKDOWN'),
            Tab(text: 'MONTHLY OVERVIEW'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: RefreshIndicator(
            onRefresh: () async {
              await ballProvider.fetchAllRecords();
              await unintProvider.fetchRecords();
            },
            color: Colors.tealAccent,
            child: Column(
              children: [
                _buildMonthSelector(monthList),
                _buildKpiSummaryCards(totalPlayerLost, totalUnintentionalLost, grandTotalLost),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDailyBreakdownTab(filteredPlayerRecords, filteredUnintRecords, ballProvider),
                      _buildMonthlyOverviewTab(allPlayerRecords, allUnintRecords, monthList),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MONTH SELECTOR STRIP
  Widget _buildMonthSelector(List<String> months) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF020C3B),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: months.length,
        itemBuilder: (context, index) {
          final m = months[index];
          final isSelected = _selectedMonthYear == m;
          final display = m == 'Overall' ? 'OVERALL' : m.toUpperCase();

          return GestureDetector(
            onTap: () => setState(() => _selectedMonthYear = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Colors.teal, Colors.tealAccent])
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(
                display,
                style: GoogleFonts.bebasNeue(
                  color: isSelected ? const Color(0xFF020C3B) : Colors.white38,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // SUMMARY KPI CARDS (Player Lost, Unintentional Lost, Combined Total)
  Widget _buildKpiSummaryCards(int playerLost, int unintLost, int grandTotal) {
    final double playerRatio = grandTotal > 0 ? (playerLost / grandTotal) : 0.5;
    final double unintRatio = grandTotal > 0 ? (unintLost / grandTotal) : 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Player Lost Card
              Expanded(
                child: _buildKpiItem(
                  title: 'PLAYER LOST',
                  sub: _selectedMonthYear,
                  count: '$playerLost',
                  icon: Icons.person_rounded,
                  accentColor: Colors.orange,
                  bgColor: Colors.orange.withOpacity(0.12),
                ),
              ),
              const SizedBox(width: 8),

              // Unintentional Lost Card
              Expanded(
                child: _buildKpiItem(
                  title: 'UNINTENTIONAL',
                  sub: _selectedMonthYear,
                  count: '$unintLost',
                  icon: Icons.help_outline_rounded,
                  accentColor: Colors.purpleAccent,
                  bgColor: Colors.purpleAccent.withOpacity(0.12),
                ),
              ),
              const SizedBox(width: 8),

              // Combined Total Card
              Expanded(
                child: _buildKpiItem(
                  title: 'COMBINED TOTAL',
                  sub: 'GRAND LOSS',
                  count: '$grandTotal',
                  icon: Icons.analytics_rounded,
                  accentColor: Colors.tealAccent,
                  bgColor: Colors.tealAccent.withOpacity(0.12),
                ),
              ),
            ],
          ),

          if (grandTotal > 0) ...[
            const SizedBox(height: 12),
            // Ratio visualization bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: (playerRatio * 100).toInt(),
                    child: Container(
                      height: 6,
                      color: Colors.orange,
                    ),
                  ),
                  Expanded(
                    flex: (unintRatio * 100).toInt(),
                    child: Container(
                      height: 6,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(
                      'Player: ${(playerRatio * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.bebasNeue(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(
                      'Unintentional: ${(unintRatio * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.bebasNeue(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiItem({
    required String title,
    required String sub,
    required String count,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 11, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: GoogleFonts.bebasNeue(color: accentColor, fontSize: 26, height: 1),
          ),
          Text(
            sub.toUpperCase(),
            style: const TextStyle(color: Colors.white30, fontSize: 8),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // TAB 1: DAILY BREAKDOWN (EACH DATE)
  Widget _buildDailyBreakdownTab(
    List<BallRecord> playerRecords,
    List<UnintentionalRecord> unintRecords,
    BallProvider ballProvider,
  ) {
    // Collect all dates from both player and unintentional records
    final Map<String, List<BallRecord>> playerByDate = {};
    for (var r in playerRecords) {
      if (r.lostCount <= 0) continue;
      final dateKey = DateFormat('yyyy-MM-dd').format(r.date);
      playerByDate.putIfAbsent(dateKey, () => []);
      playerByDate[dateKey]!.add(r);
    }

    final Map<String, List<UnintentionalRecord>> unintByDate = {};
    for (var r in unintRecords) {
      if (r.lostCount <= 0) continue;
      final dateKey = DateFormat('yyyy-MM-dd').format(r.date);
      unintByDate.putIfAbsent(dateKey, () => []);
      unintByDate[dateKey]!.add(r);
    }

    final Set<String> allDateKeys = {...playerByDate.keys, ...unintByDate.keys};
    final sortedDates = allDateKeys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded, size: 64, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'NO BALL LOSS RECORDED IN THIS PERIOD',
              style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 18, letterSpacing: 1.2),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateStr = sortedDates[index];
        final date = DateTime.parse(dateStr);

        final pList = (playerByDate[dateStr] ?? []).where((r) => r.lostCount > 0).toList();
        final uList = (unintByDate[dateStr] ?? []).where((r) => r.lostCount > 0).toList();

        final int dailyPlayerSubtotal = pList.fold(0, (sum, r) => sum + r.lostCount);
        final int dailyUnintSubtotal = uList.fold(0, (sum, r) => sum + r.lostCount);
        final int dailyCombinedTotal = dailyPlayerSubtotal + dailyUnintSubtotal;

        if (dailyCombinedTotal <= 0) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DATE HEADER + ALL 3 SUBTOTAL BADGES
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_note_rounded, color: Colors.tealAccent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(date).toUpperCase(),
                              style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 15, letterSpacing: 1),
                            ),
                          ],
                        ),
                        // COMBINED TOTAL BADGE
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Text('TOTAL: ', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 11)),
                              Text('$dailyCombinedTotal', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // SUBTOTAL PILLS: Player Subtotal & Unintentional Subtotal
                    Row(
                      children: [
                        // Player Lost Subtotal
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person, color: Colors.orange, size: 12),
                                    const SizedBox(width: 4),
                                    Text('PLAYER SUB', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 11, letterSpacing: 0.5)),
                                  ],
                                ),
                                Text('$dailyPlayerSubtotal', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Unintentional Subtotal
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purpleAccent.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.help_outline, color: Colors.purpleAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Text('UNINTENTIONAL SUB', style: GoogleFonts.bebasNeue(color: Colors.purpleAccent, fontSize: 11, letterSpacing: 0.5)),
                                  ],
                                ),
                                Text('$dailyUnintSubtotal', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // PLAYER LOSS ENTRIES (If any)
              if (pList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 10, bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 3, height: 12, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text('PLAYER LOSSES (${pList.length})', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 11, letterSpacing: 0.8)),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pList.length,
                  itemBuilder: (context, i) {
                    final r = pList[i];
                    Uint8List? pBytes;
                    try {
                      final player = ballProvider.players.firstWhere(
                        (pl) => (pl.id != null && pl.id == r.playerId) || pl.name.toLowerCase() == r.playerName.toLowerCase(),
                      );
                      if (player.photoUrl.isNotEmpty) {
                        pBytes = base64Decode(player.photoUrl);
                      }
                    } catch (_) {}

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.orange.withOpacity(0.2),
                        backgroundImage: pBytes != null ? MemoryImage(pBytes) : null,
                        child: pBytes == null
                            ? Text(r.playerName[0].toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 11))
                            : null,
                      ),
                      title: Text(
                        StringUtils.capitalize(r.playerName),
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      subtitle: r.note.isNotEmpty
                          ? Text(r.note, style: const TextStyle(color: Colors.white38, fontSize: 9, fontStyle: FontStyle.italic))
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${r.lostCount > 0 ? "+" : ""}${r.lostCount}',
                          style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
              ],

              // UNINTENTIONAL LOSS ENTRIES (If any)
              if (uList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 10, bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 3, height: 12, color: Colors.purpleAccent),
                      const SizedBox(width: 6),
                      Text('UNINTENTIONAL LOSSES (${uList.length})', style: GoogleFonts.bebasNeue(color: Colors.purpleAccent, fontSize: 11, letterSpacing: 0.8)),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: uList.length,
                  itemBuilder: (context, i) {
                    final r = uList[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                        child: const Icon(Icons.help_outline, color: Colors.purpleAccent, size: 13),
                      ),
                      title: Text(
                        r.note.isNotEmpty ? r.note : 'Ground / Accidental Loss',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                      subtitle: Text(
                        'Logged by: ${r.recordedBy}',
                        style: const TextStyle(color: Colors.white30, fontSize: 9),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${r.lostCount > 0 ? "+" : ""}${r.lostCount}',
                          style: GoogleFonts.bebasNeue(color: Colors.purpleAccent, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // TAB 2: MONTHLY OVERVIEW TABLE / CARDS
  Widget _buildMonthlyOverviewTab(
    List<BallRecord> allPlayerRecords,
    List<UnintentionalRecord> allUnintRecords,
    List<String> months,
  ) {
    final List<String> actualMonths = months.where((m) => m != 'Overall').toList();

    if (actualMonths.isEmpty) {
      return Center(
        child: Text('NO MONTHLY RECORDS FOUND', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 18)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: actualMonths.length,
      itemBuilder: (context, index) {
        final monthStr = actualMonths[index];
        final normalizedMonth = DateUtilsHelper.normalizeMonthYear(monthStr);

        final pList = allPlayerRecords.where((r) => r.lostCount > 0 && DateUtilsHelper.normalizeMonthYear(r.monthYear) == normalizedMonth).toList();
        final uList = allUnintRecords.where((r) => r.lostCount > 0 && DateUtilsHelper.normalizeMonthYear(r.monthYear) == normalizedMonth).toList();

        final int playerSubtotal = pList.fold(0, (sum, r) => sum + r.lostCount);
        final int unintSubtotal = uList.fold(0, (sum, r) => sum + r.lostCount);
        final int monthCombined = playerSubtotal + unintSubtotal;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 16, color: Colors.tealAccent),
                      const SizedBox(width: 8),
                      Text(
                        monthStr.toUpperCase(),
                        style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      'TOTAL: $monthCombined',
                      style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.orange, size: 12),
                              const SizedBox(width: 4),
                              Text('PLAYER LOST', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('$playerSubtotal', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 22, height: 1)),
                          Text('${pList.length} records', style: const TextStyle(color: Colors.white30, fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.help_outline, color: Colors.purpleAccent, size: 12),
                              const SizedBox(width: 4),
                              Text('UNINTENTIONAL', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('$unintSubtotal', style: GoogleFonts.bebasNeue(color: Colors.purpleAccent, fontSize: 22, height: 1)),
                          Text('${uList.length} records', style: const TextStyle(color: Colors.white30, fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
