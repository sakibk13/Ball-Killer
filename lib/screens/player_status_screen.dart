import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/auth_provider.dart';
import '../models/fine_payment.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';
import '../utils/string_utils.dart';
import 'payment_notice_screen.dart';
import '../providers/room_provider.dart';

class PlayerStatusScreen extends StatefulWidget {
  const PlayerStatusScreen({super.key});

  @override
  State<PlayerStatusScreen> createState() => _PlayerStatusScreenState();
}

class _PlayerStatusScreenState extends State<PlayerStatusScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'ALL'; // 'ALL', 'DUE', 'CLEARED', 'CREDIT'
  String _sortBy = 'BALLS'; // 'BALLS', 'DUE', 'NAME'
  bool _isTableView = false; // Default: Card view (no horizontal sliding, up-down scrolling)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).refresh();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ballProv = Provider.of<BallProvider>(context);
    final fineProv = Provider.of<FineProvider>(context);
    final contProv = Provider.of<ContributionProvider>(context);
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;

    if (ballProv.isLoading || fineProv.isLoading || contProv.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF051970),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    final players = ballProv.players;
    final List<Map<String, dynamic>> enriched = players.map((p) {
      final String playerId = p.id ?? '';

      // 1. Calculate Lifetime Balls
      final int recordSum = ballProv.allRecords
          .where((r) => (r.playerId.isNotEmpty && r.playerId == playerId) || r.playerName.toLowerCase() == p.name.toLowerCase())
          .fold(0, (sum, r) => sum + r.lostCount);

      final int lifetimeBalls = (recordSum > p.totalLost) ? recordSum : p.totalLost;
      final double totalFineOverall = lifetimeBalls * 50.0;

      // 2. Calculate Lifetime Payments (Deductible cash only)
      final double totalPaidDirectLifetime = fineProv.payments
          .where((pay) => (pay.playerId.isNotEmpty && pay.playerId == playerId) || pay.playerName.toLowerCase() == p.name.toLowerCase())
          .fold(0.0, (sum, pay) => sum + pay.amountPaid);

      final double totalFineSpecificContribLifetime = contProv.contributions
          .where((c) => (((c.playerId != null && c.playerId!.isNotEmpty) && c.playerId == playerId) || c.name.toLowerCase() == p.name.toLowerCase()) && !c.isOther)
          .fold(0.0, (sum, c) => sum + c.taka);

      final double totalPaidDeductible = totalPaidDirectLifetime + totalFineSpecificContribLifetime;

      // 3. Final Status
      double due = 0;
      double credit = 0;
      if (totalPaidDeductible >= totalFineOverall) {
        credit = totalPaidDeductible - totalFineOverall;
      } else {
        due = totalFineOverall - totalPaidDeductible;
      }

      return {
        'id': playerId,
        'name': StringUtils.capitalize(p.name),
        'photoUrl': p.photoUrl,
        'total': lifetimeBalls,
        'totalFine': totalFineOverall,
        'paid': totalPaidDeductible,
        'due': due,
        'surplus': credit,
      };
    }).toList();

    // Aggregates for header cards
    final int totalBalls = enriched.fold<int>(0, (sum, p) => sum + (p['total'] as int));
    final double totalFine = enriched.fold<double>(0.0, (sum, p) => sum + (p['totalFine'] as double));
    final double totalPaid = enriched.fold<double>(0.0, (sum, p) => sum + (p['paid'] as double));
    final double totalDue = enriched.fold<double>(0.0, (sum, p) => sum + (p['due'] as double));
    final double totalCredit = enriched.fold<double>(0.0, (sum, p) => sum + (p['surplus'] as double));

    final int dueCount = enriched.where((p) => (p['due'] as double) > 0).length;
    final int clearedCount = enriched.where((p) => (p['due'] as double) == 0 && (p['surplus'] as double) == 0).length;
    final int creditCount = enriched.where((p) => (p['surplus'] as double) > 0).length;

    // Filter & Sort
    List<Map<String, dynamic>> filtered = enriched.where((p) {
      final nameMatches = (p['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      if (!nameMatches) return false;

      final double due = p['due'] as double;
      final double surplus = p['surplus'] as double;

      if (_filterStatus == 'DUE') return due > 0;
      if (_filterStatus == 'CLEARED') return due == 0 && surplus == 0;
      if (_filterStatus == 'CREDIT') return surplus > 0;
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'DUE') {
        int cmp = (b['due'] as double).compareTo(a['due'] as double);
        if (cmp != 0) return cmp;
        return (b['total'] as int).compareTo(a['total'] as int);
      } else if (_sortBy == 'NAME') {
        return (a['name'] as String).compareTo(b['name'] as String);
      }
      return (b['total'] as int).compareTo(a['total'] as int);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text(
          'MASTER PLAYER STATUS',
          style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.4, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _isTableView ? 'Vertical Cards (No Sliding)' : 'Horizontal Table View',
            icon: Icon(_isTableView ? Icons.view_agenda_rounded : Icons.table_rows_rounded, color: Colors.tealAccent),
            onPressed: () => setState(() => _isTableView = !_isTableView),
          ),
          IconButton(
            tooltip: 'bKash & Bank Notice',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentNoticeScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Export Official PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.tealAccent),
            onPressed: () async {
              try {
                // Keep default enriched sorted by total balls for official export
                final exportList = List<Map<String, dynamic>>.from(enriched)
                  ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
                final room = Provider.of<RoomProvider>(context, listen: false).currentRoom;
                await ExportService.exportPlayerStatusReport(players: exportList, room: room);
                if (mounted) {
                  StatusDialog.show(context, title: "SUCCESS", message: "Master Status PDF Generated!", isSuccess: true);
                }
              } catch (e) {
                if (mounted) {
                  StatusDialog.show(context, title: "ERROR", message: "Failed: $e", isSuccess: false);
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. KPI Top Summary Strip
          _buildKpiSummary(
            totalPlayers: enriched.length,
            totalBalls: totalBalls,
            totalFine: totalFine,
            totalPaid: totalPaid,
            totalDue: totalDue,
            totalCredit: totalCredit,
          ),

          // 2. Search & Filter Bar
          _buildSearchAndFilterBar(dueCount, clearedCount, creditCount, enriched.length),

          // 3. Responsive Player Status List (Default: Vertical Cards, NO SLIDING, Up-Down Scrolling)
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, color: Colors.white.withOpacity(0.3), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'NO PLAYERS MATCH FILTER',
                          style: GoogleFonts.bebasNeue(color: Colors.white54, fontSize: 16, letterSpacing: 1),
                        ),
                      ],
                    ),
                  )
                : _isTableView
                    ? SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 620),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTableHeader(),
                                ...filtered.asMap().entries.map((entry) {
                                  return _buildPlayerRow(entry.value, entry.key, isAdmin);
                                }),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildPlayerCard(filtered[index], index, isAdmin);
                        },
                      ),
          ),

          // 4. Sticky Bottom Grand Totals Strip
          _buildStickyFooter(totalBalls, totalPaid, totalDue, totalCredit),
        ],
      ),
    );
  }

  // --- KPI SUMMARY GRID (ZERO HORIZONTAL SLIDING) ---
  Widget _buildKpiSummary({
    required int totalPlayers,
    required int totalBalls,
    required double totalFine,
    required double totalPaid,
    required double totalDue,
    required double totalCredit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF030E40),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildKpiCard('PLAYERS', '$totalPlayers', Icons.people_alt_rounded, Colors.white)),
              const SizedBox(width: 6),
              Expanded(child: _buildKpiCard('BALLS LOST', '$totalBalls', Icons.sports_cricket_rounded, Colors.tealAccent)),
              const SizedBox(width: 6),
              Expanded(child: _buildKpiCard('FINES', '${totalFine.toInt()}৳', Icons.gavel_rounded, Colors.amberAccent)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildKpiCard('COLLECTED', '${totalPaid.toInt()}৳', Icons.payments_rounded, const Color(0xFF00E676))),
              const SizedBox(width: 6),
              Expanded(child: _buildKpiCard('OUTSTANDING', '${totalDue.toInt()}৳', Icons.warning_amber_rounded, Colors.redAccent)),
              const SizedBox(width: 6),
              Expanded(child: _buildKpiCard('SURPLUS', '${totalCredit.toInt()}৳', Icons.account_balance_wallet_rounded, Colors.lightBlueAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 12),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 9.5, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.bebasNeue(color: color, fontSize: 15, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH AND FILTER CONTROLS ---
  Widget _buildSearchAndFilterBar(int dueCount, int clearedCount, int creditCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search player name...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sort Popup
              PopupMenuButton<String>(
                icon: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort_rounded, color: Colors.tealAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _sortBy == 'BALLS' ? 'BALLS' : (_sortBy == 'DUE' ? 'DUE' : 'NAME'),
                        style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 12, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
                color: const Color(0xFF020C3B),
                onSelected: (val) => setState(() => _sortBy = val),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'BALLS', child: Text('Sort by Lost Balls', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12))),
                  PopupMenuItem(value: 'DUE', child: Text('Sort by Highest Due', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12))),
                  PopupMenuItem(value: 'NAME', child: Text('Sort Alphabetically', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Filter Chips (All 4 fit across screen, zero horizontal sliding)
          Row(
            children: [
              Expanded(child: _buildFilterChip('ALL', 'ALL ($totalCount)')),
              const SizedBox(width: 6),
              Expanded(child: _buildFilterChip('DUE', 'DUE ($dueCount)', color: Colors.redAccent)),
              const SizedBox(width: 6),
              Expanded(child: _buildFilterChip('CLEARED', 'CLEAR ($clearedCount)', color: const Color(0xFF00E676))),
              const SizedBox(width: 6),
              Expanded(child: _buildFilterChip('CREDIT', 'CREDIT ($creditCount)', color: Colors.lightBlueAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {Color? color}) {
    final isSelected = _filterStatus == filterKey;
    final chipColor = color ?? Colors.tealAccent;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.18) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? chipColor : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.bebasNeue(
              color: isSelected ? chipColor : Colors.white54,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  // --- VERTICAL PLAYER CARD (ALL DETAILS VISIBLE WITHOUT HORIZONTAL SLIDING) ---
  Widget _buildPlayerCard(Map<String, dynamic> p, int index, bool isAdmin) {
    final int rank = index + 1;
    final double due = p['due'] as double;
    final double credit = p['surplus'] as double;
    final double fine = p['totalFine'] as double;
    final double paid = p['paid'] as double;
    final int balls = p['total'] as int;
    final isTop3 = rank <= 3 && _sortBy == 'BALLS';

    Color rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : (rank == 2 ? const Color(0xFFC0C0C0) : (rank == 3 ? const Color(0xFFCD7F32) : Colors.white30));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF030D36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: due > 0
              ? Colors.redAccent.withOpacity(0.35)
              : (credit > 0 ? Colors.lightBlueAccent.withOpacity(0.3) : Colors.white.withOpacity(0.08)),
          width: due > 0 ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPlayerDetails(p),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Rank + Avatar + Name + Net Status Badge
                Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: rankColor.withOpacity(isTop3 ? 0.2 : 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: rankColor.withOpacity(isTop3 ? 0.8 : 0.3), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: GoogleFonts.bebasNeue(
                          color: isTop3 ? rankColor : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Avatar
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.white12,
                      backgroundImage: p['photoUrl'] != null && p['photoUrl'] != ''
                          ? MemoryImage(base64Decode(p['photoUrl']))
                          : null,
                      child: p['photoUrl'] == null || p['photoUrl'] == ''
                          ? Text(
                              p['name'][0].toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),

                    // Player Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'],
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Click to view audit log',
                            style: GoogleFonts.poppins(color: Colors.white30, fontSize: 9.5),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge (DUE / CLEARED / CREDIT)
                    if (due > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'DUE: ${due.toInt()}৳',
                              style: GoogleFonts.bebasNeue(
                                color: Colors.redAccent,
                                fontSize: 13,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (credit > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.lightBlueAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.5), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_circle_outline_rounded, color: Colors.lightBlueAccent, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'CREDIT: +${credit.toInt()}৳',
                              style: GoogleFonts.bebasNeue(
                                color: Colors.lightBlueAccent,
                                fontSize: 13,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'CLEARED',
                              style: GoogleFonts.bebasNeue(
                                color: const Color(0xFF00E676),
                                fontSize: 13,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Metric Strip: All details visible without horizontal sliding
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(
                    children: [
                      // Stat 1: Lost Balls
                      Expanded(
                        child: _buildCardStatItem(
                          label: 'LOST BALLS',
                          value: '$balls',
                          valueColor: Colors.white,
                          trailing: isAdmin
                              ? GestureDetector(
                                  onTap: () => _showEditLostDialog(p),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 3),
                                    child: Icon(Icons.edit_outlined, color: Colors.tealAccent, size: 12),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      _buildStatDivider(),

                      // Stat 2: Total Fine
                      Expanded(
                        child: _buildCardStatItem(
                          label: 'TOTAL FINE',
                          value: '${fine.toInt()}৳',
                          valueColor: Colors.amberAccent,
                        ),
                      ),
                      _buildStatDivider(),

                      // Stat 3: Total Paid
                      Expanded(
                        child: _buildCardStatItem(
                          label: 'PAID / GIVEN',
                          value: '${paid.toInt()}৳',
                          valueColor: const Color(0xFF00E676),
                        ),
                      ),
                      _buildStatDivider(),

                      // Stat 4: Net Balance
                      Expanded(
                        child: _buildCardStatItem(
                          label: due > 0 ? 'NET DUE' : (credit > 0 ? 'CREDIT' : 'BALANCE'),
                          value: due > 0
                              ? '${due.toInt()}৳'
                              : (credit > 0 ? '+${credit.toInt()}৳' : '0৳'),
                          valueColor: due > 0
                              ? Colors.redAccent
                              : (credit > 0 ? Colors.lightBlueAccent : const Color(0xFF00E676)),
                        ),
                      ),
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

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withOpacity(0.08),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildCardStatItem({
    required String label,
    required String value,
    required Color valueColor,
    Widget? trailing,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 9.5, letterSpacing: 0.5),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.bebasNeue(
                  color: valueColor,
                  fontSize: 16,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ],
    );
  }

  // --- TABLE HEADER ---
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF030D36),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          _tableColHeader('RK', 36, align: TextAlign.center),
          _tableColHeader('PIC', 42, align: TextAlign.center),
          _tableColHeader('PLAYER NAME', 145),
          _tableColHeader('LOST', 52, align: TextAlign.center),
          _tableColHeader('FINE', 65, align: TextAlign.right),
          _tableColHeader('GIVEN', 65, align: TextAlign.right),
          _tableColHeader('NET DUE', 75, align: TextAlign.right),
          _tableColHeader('CREDIT', 65, align: TextAlign.right),
          _tableColHeader('VIEW', 40, align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _tableColHeader(String text, double width, {TextAlign align = TextAlign.left}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.bebasNeue(
          color: Colors.tealAccent,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // --- PLAYER TABLE ROW ---
  Widget _buildPlayerRow(Map<String, dynamic> p, int index, bool isAdmin) {
    final int rank = index + 1;
    final double due = p['due'] as double;
    final double credit = p['surplus'] as double;
    final isTop3 = rank <= 3 && _sortBy == 'BALLS';

    Color rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : (rank == 2 ? const Color(0xFFC0C0C0) : (rank == 3 ? const Color(0xFFCD7F32) : Colors.white24));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white.withOpacity(0.015) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          // 1. Rank
          SizedBox(
            width: 36,
            child: Center(
              child: isTop3
                  ? Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: rankColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: rankColor.withOpacity(0.6), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: GoogleFonts.bebasNeue(color: rankColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    )
                  : Text(
                      '$rank',
                      style: GoogleFonts.bebasNeue(color: Colors.white30, fontSize: 13),
                    ),
            ),
          ),

          // 2. Avatar
          SizedBox(
            width: 42,
            child: Center(
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white12,
                backgroundImage: p['photoUrl'] != null && p['photoUrl'] != ''
                    ? MemoryImage(base64Decode(p['photoUrl']))
                    : null,
                child: p['photoUrl'] == null || p['photoUrl'] == ''
                    ? Text(
                        p['name'][0].toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                      )
                    : null,
              ),
            ),
          ),

          // 3. Player Name (Full comfortable width, tappable)
          SizedBox(
            width: 145,
            child: InkWell(
              onTap: () => _showPlayerDetails(p),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  p['name'],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // 4. Lost Balls (with Admin edit)
          SizedBox(
            width: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${p['total']}',
                  style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 15),
                ),
                if (isAdmin)
                  GestureDetector(
                    onTap: () => _showEditLostDialog(p),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.edit_outlined, color: Colors.tealAccent, size: 12),
                    ),
                  ),
              ],
            ),
          ),

          // 5. Total Fine
          SizedBox(
            width: 65,
            child: Text(
              '${(p['totalFine'] as double).toInt()}৳',
              textAlign: TextAlign.right,
              style: GoogleFonts.bebasNeue(color: Colors.amberAccent, fontSize: 14),
            ),
          ),

          // 6. Given / Paid
          SizedBox(
            width: 65,
            child: Text(
              '${(p['paid'] as double).toInt()}৳',
              textAlign: TextAlign.right,
              style: GoogleFonts.bebasNeue(color: const Color(0xFF00E676), fontSize: 14),
            ),
          ),

          // 7. Net Due Badge
          SizedBox(
            width: 75,
            child: Align(
              alignment: Alignment.centerRight,
              child: due > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 0.8),
                      ),
                      child: Text(
                        '${due.toInt()}৳',
                        style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 12, letterSpacing: 0.5),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CLEAR',
                        style: GoogleFonts.bebasNeue(color: const Color(0xFF00E676), fontSize: 10, letterSpacing: 0.5),
                      ),
                    ),
            ),
          ),

          // 8. Credit Badge
          SizedBox(
            width: 65,
            child: Align(
              alignment: Alignment.centerRight,
              child: credit > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.lightBlueAccent.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.4), width: 0.8),
                      ),
                      child: Text(
                        '+${credit.toInt()}৳',
                        style: GoogleFonts.bebasNeue(color: Colors.lightBlueAccent, fontSize: 12, letterSpacing: 0.5),
                      ),
                    )
                  : Text('-', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 12)),
            ),
          ),

          // 9. View Details Icon
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white38, size: 16),
              onPressed: () => _showPlayerDetails(p),
              tooltip: 'Transaction Log',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  // --- STICKY FOOTER TOTALS ---
  Widget _buildStickyFooter(int totalBalls, double totalPaid, double totalDue, double totalCredit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.summarize_rounded, color: Colors.tealAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  'TOTALS',
                  style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 12, letterSpacing: 0.8),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildFooterPill('BALLS', '$totalBalls', Colors.white)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFooterPill('COLLECTED', '${totalPaid.toInt()}৳', const Color(0xFF00E676))),
                  const SizedBox(width: 6),
                  Expanded(child: _buildFooterPill('DUE', '${totalDue.toInt()}৳', Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.bebasNeue(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: GoogleFonts.bebasNeue(color: color.withOpacity(0.7), fontSize: 8.5)),
          ),
        ],
      ),
    );
  }

  // --- TRANSACTION HISTORY MODAL ---
  void _showPlayerDetails(Map<String, dynamic> player) {
    final fineProv = Provider.of<FineProvider>(context, listen: false);
    final contProv = Provider.of<ContributionProvider>(context, listen: false);

    final payments = fineProv.payments.where((p) => p.playerId == player['id']).toList();
    final contributions = contProv.contributions.where((c) => c.playerId == player['id']).toList();

    final List<dynamic> history = [...payments, ...contributions];
    history.sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFF020C3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white12,
                  backgroundImage: player['photoUrl'] != null && player['photoUrl'] != ''
                      ? MemoryImage(base64Decode(player['photoUrl']))
                      : null,
                  child: player['photoUrl'] == null || player['photoUrl'] == ''
                      ? Text(player['name'][0].toUpperCase(), style: const TextStyle(fontSize: 22, color: Colors.tealAccent))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player['name'],
                        style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1.1),
                      ),
                      Text('Detailed Account & Payment Log', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Stat row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallStat('TOTAL BALLS', '${player['total']}', Colors.white),
                _buildSmallStat('TOTAL FINE', '${(player['totalFine'] as double).toInt()}৳', Colors.amberAccent),
                _buildSmallStat('TOTAL PAID', '${(player['paid'] as double).toInt()}৳', const Color(0xFF00E676)),
                _buildSmallStat('NET DUE', '${(player['due'] as double).toInt()}৳', Colors.redAccent),
                _buildSmallStat('CREDIT', '${(player['surplus'] as double).toInt()}৳', Colors.lightBlueAccent),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('TRANSACTION AUDIT TIMELINE', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14, letterSpacing: 1.2)),
              ],
            ),
            const Divider(color: Colors.white10, height: 18),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, color: Colors.white24, size: 40),
                          const SizedBox(height: 8),
                          Text('No transactions recorded yet', style: GoogleFonts.poppins(color: Colors.white30, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, i) {
                        final item = history[i];
                        final isFine = item is FinePayment;
                        final amount = (isFine ? item.amountPaid : item.taka).toInt();
                        final note = isFine ? (item.note ?? "Fine Payment") : (item.ballTape.isNotEmpty ? item.ballTape : "Contribution");

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isFine ? Colors.tealAccent : Colors.purpleAccent).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isFine ? Icons.receipt_rounded : Icons.volunteer_activism_rounded,
                                      color: isFine ? Colors.tealAccent : Colors.purpleAccent,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isFine ? 'FINE PAYMENT' : 'CONTRIBUTION',
                                        style: GoogleFonts.bebasNeue(
                                          color: isFine ? Colors.tealAccent : Colors.purpleAccent,
                                          fontSize: 13,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        note,
                                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$amount ৳',
                                    style: GoogleFonts.bebasNeue(color: const Color(0xFF00E676), fontSize: 18),
                                  ),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(item.date),
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 17, letterSpacing: 0.5)),
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
      ],
    );
  }

  // --- EDIT LOST DIALOG ---
  void _showEditLostDialog(Map<String, dynamic> player) {
    final controller = TextEditingController(text: player['total'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('EDIT BALL LOSS', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player: ${player['name']}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Total Lifetime Balls Lost',
                labelStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.bebasNeue(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newValue = int.tryParse(controller.text);
              if (newValue != null) {
                final adminName = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';
                final success = await Provider.of<BallProvider>(context, listen: false)
                    .overridePlayerTotalLost(player['id'], newValue, adminName);
                if (success && mounted) {
                  Navigator.pop(context);
                  StatusDialog.show(context, title: "UPDATED", message: "Player balls updated!", isSuccess: true);
                }
              }
            },
            child: Text('UPDATE', style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B))),
          ),
        ],
      ),
    );
  }
}
