import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/fund_provider.dart';
import '../models/fund.dart';
import '../models/fine_payment.dart';
import '../models/contribution.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';
import '../utils/string_utils.dart';
import '../utils/date_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'payment_notice_screen.dart';
import '../providers/room_provider.dart';

class FineScreen extends StatefulWidget {
  const FineScreen({super.key});

  @override
  State<FineScreen> createState() => _FineScreenState();
}

class _FineScreenState extends State<FineScreen> {
  String _selectedMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
  late List<String> _monthList;
  String _rankingSearch = '';

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).init();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
    });
  }

  void _generateMonthList() {
    _monthList = ['Overall'];
    final fineProvider = Provider.of<FineProvider>(context, listen: false);
    final ballProvider = Provider.of<BallProvider>(context, listen: false);

    Set<String> months = {};
    for (var p in fineProvider.payments) {
      if (p.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(p.monthYear));
      }
    }
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
    _generateMonthList();
    final ballProvider = Provider.of<BallProvider>(context);
    final fineProvider = Provider.of<FineProvider>(context);
    final contributionProvider = Provider.of<ContributionProvider>(context);

    final playersWithTotals = ballProvider.getPlayersWithTotals(monthYear: _selectedMonthYear);

    final enrichedPlayers = playersWithTotals.map((p) {
      final String playerId = p['id'];
      final int lifetimeBalls = p['totalOverall'] ?? (p['total'] ?? 0);
      final double totalFineOverall = lifetimeBalls * 50.0;

      final double totalPaidDirectLifetime = fineProvider.payments
          .where((pay) => pay.playerId == playerId)
          .fold(0.0, (sum, pay) => sum + pay.amountPaid);

      final double totalFineSpecificContribLifetime = contributionProvider.contributions
          .where((c) => c.playerId == playerId && !c.isOther)
          .fold(0.0, (sum, c) => sum + c.taka);

      final double totalDeductiblePaidLifetime = totalPaidDirectLifetime + totalFineSpecificContribLifetime;

      final int monthlyBalls = p['total'] as int;
      final double monthlyFine = monthlyBalls * 50.0;

      String searchM = DateUtilsHelper.normalizeMonthYear(_selectedMonthYear);

      final double monthlyPaidDirect = fineProvider.payments
          .where((pay) => pay.playerId == playerId && DateUtilsHelper.normalizeMonthYear(pay.monthYear) == searchM)
          .fold(0.0, (sum, pay) => sum + pay.amountPaid);

      final double monthlyFineSpecificContrib = contributionProvider.contributions
          .where((c) => c.playerId == playerId && !c.isOther && DateUtilsHelper.normalizeMonthYear(c.monthYear) == searchM)
          .fold(0.0, (sum, c) => sum + c.taka);

      final double totalPaidMonthly = monthlyPaidDirect + monthlyFineSpecificContrib;

      double lifetimeDue = 0;
      double lifetimeCredit = 0;
      if (totalDeductiblePaidLifetime >= totalFineOverall) {
        lifetimeCredit = totalDeductiblePaidLifetime - totalFineOverall;
      } else {
        lifetimeDue = totalFineOverall - totalDeductiblePaidLifetime;
      }

      double monthlyDue = 0;
      if (totalPaidMonthly < monthlyFine) {
        monthlyDue = monthlyFine - totalPaidMonthly;
      }

      return {
        ...p,
        'totalFine': totalFineOverall,
        'paid': totalDeductiblePaidLifetime,
        'due': lifetimeDue,
        'surplus': lifetimeCredit,
        'monthlyBalls': monthlyBalls,
        'monthlyDue': monthlyDue,
        'monthlyPaid': totalPaidMonthly,
        'lifetimeBalls': lifetimeBalls,
      };
    }).toList();

    final sortedPlayers = List<Map<String, dynamic>>.from(enrichedPlayers)
      ..sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));

    final topPlayer = sortedPlayers.isNotEmpty ? sortedPlayers.first : null;
    final int topLost = topPlayer != null ? (topPlayer['monthlyBalls'] as int) : 0;
    final double topFine = topPlayer != null ? (topLost * 50.0) : 0.0;
    final double topDue = topPlayer != null ? topPlayer['due'] : 0.0;
    final double topCredit = topPlayer != null ? topPlayer['surplus'] : 0.0;

    // Filtered ranking for search
    final filteredPlayers = sortedPlayers.where((p) {
      if (_rankingSearch.isEmpty) return true;
      return (p['name'] as String).toLowerCase().contains(_rankingSearch.toLowerCase());
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF051970),
        appBar: AppBar(
          title: Text(
            'PLAYER FINES',
            style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.4, fontSize: 20),
          ),
          backgroundColor: const Color(0xFF020C3B),
          elevation: 0,
          actions: [
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
                  final room = Provider.of<RoomProvider>(context, listen: false).currentRoom;
                  await ExportService.exportFineReport(
                    monthYear: _selectedMonthYear,
                    sortedPlayers: sortedPlayers,
                    room: room,
                  );
                  if (mounted) {
                    StatusDialog.show(context, title: "SUCCESS", message: "Fine Report Generated!", isSuccess: true);
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
          bottom: TabBar(
            indicatorColor: Colors.tealAccent,
            indicatorWeight: 3,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.bebasNeue(letterSpacing: 1.2, fontSize: 14),
            tabs: const [
              Tab(text: 'NOTICES & RANKINGS', icon: Icon(Icons.warning_amber_rounded, size: 20)),
              Tab(text: 'GIVEN HISTORY', icon: Icon(Icons.history_edu_outlined, size: 20)),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                _buildMonthPicker(),
                _buildMonthlyKpiStrip(sortedPlayers),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (topPlayer != null && (topLost > 0 || topCredit > 0)) ...[
                              _buildFineCard(topPlayer, topLost, topFine, topDue, topCredit),
                              const SizedBox(height: 24),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader(
                                  _selectedMonthYear == 'Overall' ? 'OVERALL FINE STANDINGS' : 'MONTHLY STANDINGS',
                                ),
                                Text(
                                  '${sortedPlayers.length} PLAYERS',
                                  style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 12, letterSpacing: 1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Search bar in Ranking
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => _rankingSearch = val),
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Search player in rankings...',
                                  hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (filteredPlayers.isNotEmpty)
                              _buildRankingList(filteredPlayers)
                            else ...[
                              const SizedBox(height: 60),
                              Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.verified_user_outlined, color: Color(0xFF00E676), size: 64),
                                    const SizedBox(height: 14),
                                    Text('EVERYTHING IS CLEAR', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 20)),
                                    Text('No outstanding fines for this query', style: GoogleFonts.poppins(color: Colors.white30, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildGivenHistoryTab(fineProvider, contributionProvider, ballProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: Provider.of<AuthProvider>(context, listen: false).isAdmin
            ? FloatingActionButton.extended(
                onPressed: () => _showAddFineGivenDialog(context, enrichedPlayers),
                backgroundColor: Colors.tealAccent,
                icon: const Icon(Icons.add_rounded, color: Color(0xFF020C3B)),
                label: Text(
                  'RECORD GIVEN',
                  style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B), fontSize: 14, letterSpacing: 0.8),
                ),
              )
            : null,
      ),
    );
  }

  // --- MONTHLY KPI STRIP ---
  Widget _buildMonthlyKpiStrip(List<Map<String, dynamic>> players) {
    final int monthBalls = players.fold<int>(0, (sum, p) => sum + (p['monthlyBalls'] as int));
    final double monthFine = monthBalls * 50.0;
    final double monthPaid = players.fold<double>(0.0, (sum, p) => sum + (p['monthlyPaid'] as double));
    final double totalDue = players.fold<double>(0.0, (sum, p) => sum + (p['due'] as double));
    final double totalCredit = players.fold<double>(0.0, (sum, p) => sum + (p['surplus'] as double));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF030E40),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStripCard('BALLS LOST', '$monthBalls (${monthFine.toInt()}৳)', Icons.sports_cricket_rounded, Colors.tealAccent),
            const SizedBox(width: 8),
            _buildStripCard('GIVEN / PAID', '${monthPaid.toInt()}৳', Icons.payments_rounded, const Color(0xFF00E676)),
            const SizedBox(width: 8),
            _buildStripCard('CLUB NET DUE', '${totalDue.toInt()}৳', Icons.warning_amber_rounded, Colors.redAccent),
            const SizedBox(width: 8),
            _buildStripCard('SURPLUS CREDIT', '${totalCredit.toInt()}৳', Icons.account_balance_wallet_rounded, Colors.lightBlueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildStripCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 9, letterSpacing: 0.6)),
              Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 13, letterSpacing: 0.4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _monthList.length,
        itemBuilder: (context, index) {
          final m = _monthList[index];
          final isSelected = _selectedMonthYear == m;
          String display = m == 'Overall' ? 'OVERALL' : m.toUpperCase();
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthYear = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Colors.tealAccent, Color(0xFF00B0FF)])
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.tealAccent.withOpacity(0.6) : Colors.white10,
                  width: isSelected ? 1.2 : 0.8,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.tealAccent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                display,
                style: GoogleFonts.bebasNeue(
                  color: isSelected ? const Color(0xFF020C3B) : Colors.white54,
                  fontSize: 14,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFineCard(Map<String, dynamic> player, int lost, double fine, double due, double credit) {
    final int lifetimeBalls = player['lifetimeBalls'] ?? 0;
    final double totalGiven = player['paid'] ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B4B), Color(0xFF040A26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5)),
          BoxShadow(color: Colors.amber.withOpacity(0.08), blurRadius: 20, spreadRadius: -2),
        ],
        border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.amber, Colors.orangeAccent]),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF020C3B),
                  backgroundImage: player['photoUrl'] != null && player['photoUrl'].isNotEmpty
                      ? MemoryImage(base64Decode(player['photoUrl']))
                      : null,
                  child: player['photoUrl'] == null || player['photoUrl'].isEmpty
                      ? Text(player['name'][0].toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24))
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF051970), size: 12),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.8),
                  ),
                  child: Text(
                    'TOP FINED / CONTRIBUTOR',
                    style: GoogleFonts.bebasNeue(color: Colors.amberAccent, fontSize: 10, letterSpacing: 1.1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  StringUtils.capitalize(player['name']),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('BALLS: $lifetimeBalls', style: GoogleFonts.bebasNeue(color: Colors.white60, fontSize: 12, letterSpacing: 0.8)),
                    const SizedBox(width: 10),
                    Text('GIVEN: ${totalGiven.toInt()}৳', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 12, letterSpacing: 0.8)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: due > 0 ? Colors.redAccent.withOpacity(0.15) : const Color(0xFF00E676).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: due > 0 ? Colors.redAccent.withOpacity(0.4) : const Color(0xFF00E676).withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  due > 0 ? 'NET DUE' : (credit > 0 ? 'SURPLUS' : 'STATUS'),
                  style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 10, letterSpacing: 0.8),
                ),
                Text(
                  due > 0 ? '${due.toInt()}৳' : (credit > 0 ? '+${credit.toInt()}৳' : 'CLEAR'),
                  style: GoogleFonts.bebasNeue(
                    color: due > 0 ? Colors.redAccent : const Color(0xFF00E676),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 3.5, height: 16, decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16, letterSpacing: 1.3)),
      ],
    );
  }

  Widget _buildRankingList(List<Map<String, dynamic>> players) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final monthlyTotal = p['monthlyBalls'] as int;
        final totalGiven = p['paid'] as double;
        final monthlyDue = p['monthlyDue'] as double;
        final lifetimeDue = p['due'] as double;
        final credit = p['surplus'] as double;
        final rank = i + 1;
        final isTop = rank <= 3;

        Color rankColor = rank == 1
            ? const Color(0xFFFFD700)
            : (rank == 2 ? const Color(0xFFC0C0C0) : (rank == 3 ? const Color(0xFFCD7F32) : Colors.white24));

        Uint8List? pBytes;
        if (p['photoUrl'] != null && p['photoUrl'] != '') {
          try {
            pBytes = base64Decode(p['photoUrl']);
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isTop ? rankColor.withOpacity(0.35) : Colors.white.withOpacity(0.06),
              width: isTop ? 1.2 : 0.8,
            ),
            boxShadow: [
              if (isTop) BoxShadow(color: rankColor.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isTop ? rankColor.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                    shape: BoxShape.circle,
                    border: Border.all(color: isTop ? rankColor.withOpacity(0.5) : Colors.transparent),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: GoogleFonts.bebasNeue(
                      color: isTop ? rankColor : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white12,
                  backgroundImage: pBytes != null ? MemoryImage(pBytes) : null,
                  child: pBytes == null
                      ? Text(p['name'][0].toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold))
                      : null,
                ),
              ],
            ),
            title: Text(
              StringUtils.capitalize(p['name']),
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMiniTag('BALLS: $monthlyTotal', Colors.white60),
                _buildMiniTag('FINE: ${((p['totalFine'] ?? (monthlyTotal * 50.0)) as num).toInt()}৳', Colors.amberAccent),
                if (lifetimeDue > 0)
                  _buildMiniTag('DUE: ${lifetimeDue.toInt()}৳', Colors.redAccent)
                else if (credit > 0)
                  _buildMiniTag('+${credit.toInt()}৳ CR', Colors.lightBlueAccent)
                else
                  _buildMiniTag('CLEARED', const Color(0xFF00E676)),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.send_to_mobile_rounded, color: const Color(0xFF00E676).withOpacity(0.9), size: 19),
              tooltip: 'Send WhatsApp Reminder',
              onPressed: () => _sendWhatsAppReminder(p),
            ),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem('LIFETIME FINE', '${p['totalFine'].toInt()}৳', Colors.white70),
                        _buildDetailItem('TOTAL PAID', '${totalGiven.toInt()}৳', Colors.tealAccent),
                        _buildDetailItem('MONTHLY DUE', '${monthlyDue.toInt()}৳', monthlyDue > 0 ? Colors.orangeAccent : Colors.white24),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET OUTSTANDING BALANCE', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 13)),
                          Text(
                            lifetimeDue > 0
                                ? '${lifetimeDue.toInt()}৳ DUE'
                                : (credit > 0 ? '+${credit.toInt()}৳ CREDIT' : 'CLEAR'),
                            style: GoogleFonts.bebasNeue(
                              color: lifetimeDue > 0
                                  ? Colors.redAccent
                                  : (credit > 0 ? Colors.lightBlueAccent : const Color(0xFF00E676)),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  Widget _buildMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.25), width: 0.6),
      ),
      child: Text(
        label,
        style: GoogleFonts.bebasNeue(color: color, fontSize: 9.5, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildDetailItem(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 10)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 16)),
      ],
    );
  }

  Widget _buildGivenHistoryTab(FineProvider fineProvider, ContributionProvider contributionProvider, BallProvider ballProvider) {
    final players = ballProvider.players;
    final directPayments = fineProvider.getPaymentsForMonth(_selectedMonthYear);
    final contribFines = contributionProvider.contributions
        .where((c) => (_selectedMonthYear == 'Overall' || c.monthYear == _selectedMonthYear) && c.isFinePayment)
        .toList();

    final List<dynamic> combinedHistory = [...directPayments, ...contribFines];
    combinedHistory.sort((a, b) => b.date.compareTo(a.date));

    if (combinedHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03)),
              child: const Icon(Icons.history_rounded, color: Colors.white12, size: 64),
            ),
            const SizedBox(height: 16),
            Text('NO PAYMENT HISTORY', style: GoogleFonts.bebasNeue(color: Colors.white30, fontSize: 22, letterSpacing: 1.2)),
            Text('No fines recorded for this period', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12)),
          ],
        ),
      );
    }

    Map<String, List<dynamic>> grouped = {};
    for (var p in combinedHistory) {
      String dateStr = DateFormat('yyyy-MM-dd').format(p.date);
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(p);
    }
    var dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        String dateKey = dates[index];
        DateTime date = DateTime.parse(dateKey);
        List<dynamic> items = grouped[dateKey]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Date Tile
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 0.8),
                  boxShadow: [BoxShadow(color: Colors.tealAccent.withOpacity(0.08), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 12, letterSpacing: 0.8),
                    ),
                    Text(
                      DateFormat('dd').format(date),
                      style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 26, height: 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: items.map((p) {
                    bool isDirect = p is FinePayment;
                    String name = isDirect ? p.playerName : p.name;
                    String pId = isDirect ? p.playerId : p.playerId;
                    String note = isDirect ? (p.note ?? "Fine Payment") : "(Via Contrib) ${p.ballTape}";
                    double amount = isDirect ? p.amountPaid : p.taka;

                    Uint8List? pBytes;
                    try {
                      final player = players.firstWhere(
                        (pl) => (pl.id != null && pl.id == pId) || pl.name.toLowerCase() == name.toLowerCase(),
                      );
                      if (player.photoUrl.isNotEmpty) {
                        pBytes = base64Decode(player.photoUrl);
                      }
                    } catch (_) {}

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.035),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white12,
                            backgroundImage: pBytes != null ? MemoryImage(pBytes) : null,
                            child: pBytes == null
                                ? Text(name[0].toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  StringUtils.capitalize(name),
                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(note, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3), width: 0.8),
                            ),
                            child: Text('${amount.toInt()}৳', style: GoogleFonts.bebasNeue(color: const Color(0xFF00E676), fontSize: 16)),
                          ),
                          if (Provider.of<AuthProvider>(context, listen: false).isAdmin) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (isDirect) {
                                  _confirmDeleteGivenFine(context, fineProvider, p);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete this via Financials tab')));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), shape: BoxShape.circle),
                                child: Icon(Icons.delete_outline_rounded, color: isDirect ? Colors.redAccent : Colors.white24, size: 16),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendWhatsAppReminder(Map<String, dynamic> player) {
    final String name = player['name'];
    final double due = player['due'];
    final double credit = player['surplus'];
    String phone = player['phone'] ?? '';
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 11 && phone.startsWith('0')) {
      phone = '88$phone';
    } else if (phone.length == 10 && !phone.startsWith('0')) {
      phone = '880$phone';
    }
    String message = '';
    if (due > 0) {
      message = "Hey ${StringUtils.capitalize(name)}, you have an outstanding club fine/due of ${due.toInt()} BDT. Please clear it at your earliest convenience. - Ball Terminator by Sudden Plan Cricket Team";
    } else if (credit > 0) {
      message = "Hey ${StringUtils.capitalize(name)}, you have ${credit.toInt()} BDT credit in the club account. Thank you for your support! - Ball Terminator by Sudden Plan Cricket Team";
    } else {
      message = "Hey ${StringUtils.capitalize(name)}, your club account is completely clear! Keep it up. - Ball Terminator by Sudden Plan Cricket Team";
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.3))),
        title: Row(
          children: [
            const Icon(Icons.send_to_mobile_rounded, color: Color(0xFF00E676)),
            const SizedBox(width: 10),
            Text('WHATSAPP REMINDER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.bebasNeue(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () {
              Navigator.pop(ctx);
              final url = "https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}";
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: Text('SEND NOW', style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B))),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGivenFine(BuildContext context, FineProvider provider, FinePayment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.redAccent, width: 1.2)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text('DELETE PAYMENT RECORD?', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove this fine payment record of ${payment.amountPaid.toInt()}৳ for ${payment.playerName}?',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.bebasNeue(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await provider.deletePayment(payment.id!);
                if (context.mounted) {
                  StatusDialog.show(context, message: "Payment record deleted successfully.", isSuccess: true, title: "RECORD DELETED");
                }
              } catch (e) {
                if (context.mounted) {
                  StatusDialog.show(context, message: "Failed to delete record: $e", isSuccess: false, title: "DELETE FAILED");
                }
              }
            },
            child: Text('DELETE', style: GoogleFonts.bebasNeue(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddFineGivenDialog(BuildContext context, List<Map<String, dynamic>> players) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can add collection records')));
      return;
    }
    final formKey = GlobalKey<FormState>();
    String? selectedPlayerId;
    String? selectedPlayerName;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF020C3B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('RECORD FINE PAYMENT', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') return const Iterable<Map<String, dynamic>>.empty();
                      return players.where((p) => p['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (p) => p['name'].toString().toUpperCase(),
                    onSelected: (p) {
                      selectedPlayerId = p['id'];
                      selectedPlayerName = p['name'];
                    },
                    fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(
                      controller: ctrl,
                      focusNode: focus,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('SEARCH PLAYER'),
                      validator: (v) => selectedPlayerId == null ? 'Select a player' : null,
                    ),
                    optionsViewBuilder: (ctx, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: const Color(0xFF020C3B),
                        elevation: 4.0,
                        child: Container(
                          width: 250,
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (ctx, i) {
                              final p = options.elementAt(i);
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: p['photoUrl'] != null && p['photoUrl'] != '' ? MemoryImage(base64Decode(p['photoUrl'])) : null,
                                  child: p['photoUrl'] == null || p['photoUrl'] == '' ? Text(p['name'][0], style: const TextStyle(fontSize: 10)) : null,
                                ),
                                title: Text(p['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                subtitle: Text('Lost: ${p['total']} balls • Due: ${(p['due'] as double).toInt()}৳', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                onTap: () => onSelected(p),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amountController,
                    decoration: _inputDecoration('GIVEN AMOUNT (BDT)'),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Enter amount' : null,
                  ),
                  const SizedBox(height: 10),
                  // Quick amount buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [50, 100, 150, 200, 500].map((amt) {
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            amountController.text = '$amt';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text('+$amt', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 11)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('DATE: ${DateFormat('MMM dd, yyyy').format(selectedDate)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const Icon(Icons.calendar_today_rounded, color: Colors.tealAccent, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: noteController,
                    decoration: _inputDecoration('OPTIONAL NOTE'),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: GoogleFonts.bebasNeue(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedPlayerId != null) {
                  final amount = double.parse(amountController.text);
                  final adminName = authProvider.currentUser?.name ?? 'Admin';

                  // 1. Add to Contribution (for Financial Summary)
                  final contrib = Contribution(
                    playerId: selectedPlayerId,
                    name: selectedPlayerName!,
                    taka: amount,
                    date: selectedDate,
                    monthYear: DateFormat('MMMM yyyy').format(selectedDate),
                    ballTape: "Fine Collection${noteController.text.isNotEmpty ? ": ${noteController.text}" : ""}",
                    isFinePayment: true,
                    isOther: false,
                  );
                  await Provider.of<ContributionProvider>(context, listen: false).addContribution(contrib);

                  // 2. Add to Fund (for Financial/Fund page) - AUTOMATIC
                  final fund = Fund(
                    playerId: selectedPlayerId,
                    name: selectedPlayerName!,
                    amount: amount,
                    date: selectedDate,
                    note: "Fine Collection${noteController.text.isNotEmpty ? ": ${noteController.text}" : ""}",
                    type: 'INCOME',
                  );
                  await Provider.of<FundProvider>(context, listen: false).addFund(fund, adminName);

                  if (mounted) {
                    Navigator.pop(context);
                    StatusDialog.show(context, title: "SUCCESS", message: "Record added to fines & treasury fund!", isSuccess: true);
                  }
                }
              },
              child: Text('SAVE RECORD', style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B))),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.tealAccent)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }
}
