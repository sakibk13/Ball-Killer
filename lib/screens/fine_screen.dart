import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/auth_provider.dart';
import '../models/fine_payment.dart';
import '../models/contribution.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';
import '../utils/string_utils.dart';
import '../utils/date_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class FineScreen extends StatefulWidget {
  const FineScreen({super.key});

  @override
  State<FineScreen> createState() => _FineScreenState();
}

class _FineScreenState extends State<FineScreen> {
  String _selectedMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
  late List<String> _monthList;

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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF051970),
        appBar: AppBar(
          title: Text('PLAYER FINES', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
          backgroundColor: const Color(0xFF020C3B),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.tealAccent),
              onPressed: () async {
                try {
                  await ExportService.exportFineReport(
                    monthYear: _selectedMonthYear,
                    sortedPlayers: sortedPlayers,
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
            const SizedBox(width: 10),
          ],
          bottom: TabBar(
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.bebasNeue(letterSpacing: 1.2),
            tabs: const [
              Tab(text: 'NOTICES', icon: Icon(Icons.warning_amber_rounded)),
              Tab(text: 'GIVEN HISTORY', icon: Icon(Icons.history_edu_outlined)),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildMonthPicker(),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            if (topPlayer != null && (topLost > 0 || topCredit > 0)) ...[
                              _buildFineCard(topPlayer, topLost, topFine, topDue, topCredit),
                              const SizedBox(height: 30),
                              _buildSectionHeader('RANKING ${_selectedMonthYear == 'Overall' ? 'OVERALL' : 'THIS MONTH'}'),
                              const SizedBox(height: 15),
                              _buildRankingList(sortedPlayers),
                            ] else ...[
                              const SizedBox(height: 100),
                              const Icon(Icons.verified_user_outlined, color: Color(0xFF00E676), size: 80),
                              const SizedBox(height: 20),
                              Text('EVERYTHING IS CLEAR', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 24)),
                            ],
                          ],
                        ),
                      ),
                      _buildGivenHistoryTab(fineProvider, contributionProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: Provider.of<AuthProvider>(context, listen: false).isAdmin 
          ? FloatingActionButton(
              onPressed: () => _showAddFineGivenDialog(context, enrichedPlayers),
              backgroundColor: Colors.tealAccent,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
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
    );
  }

  Widget _buildFineCard(Map<String, dynamic> player, int lost, double fine, double due, double credit) {
    final int lifetimeBalls = player['lifetimeBalls'] ?? 0;
    final double totalGiven = player['paid'] ?? 0.0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        gradient: const LinearGradient(
          colors: [Color(0xFF001F3F), Color(0xFF051970)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.tealAccent.withOpacity(0.05), blurRadius: 40, spreadRadius: -10),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(25),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Colors.cyanAccent, Colors.blueAccent]),
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFF020C3B),
                        backgroundImage: player['photoUrl'] != null && player['photoUrl'].isNotEmpty 
                            ? MemoryImage(base64Decode(player['photoUrl'])) 
                            : null,
                        child: player['photoUrl'] == null || player['photoUrl'].isEmpty 
                            ? Text(player['name'][0], style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 40)) 
                            : null,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOP CONTRIBUTOR', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 14, letterSpacing: 2)),
                      Text(
                        StringUtils.capitalize(player['name']), 
                        style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 32, letterSpacing: 1.5, height: 1.1)
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.phone_android_rounded, color: Colors.white24, size: 12),
                          const SizedBox(width: 5),
                          Text(player['phone'] ?? 'N/A', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('LIFETIME BALLS', '$lifetimeBalls', Colors.white70),
                    _buildSummaryItem('GIVEN (CASH)', '${totalGiven.toInt()} ৳', Colors.tealAccent),
                  ],
                ),
                const SizedBox(height: 25),
                const Divider(color: Colors.white10),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OUTSTANDING DUE', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 12, letterSpacing: 1)),
                        Text('${due.toInt()} ৳', style: GoogleFonts.bebasNeue(color: due > 0 ? Colors.redAccent : Colors.greenAccent, fontSize: 36)),
                      ],
                    ),
                    if (credit > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('SURPLUS CREDIT', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 12, letterSpacing: 1)),
                          Text('${credit.toInt()} ৳', style: GoogleFonts.bebasNeue(color: Colors.cyanAccent, fontSize: 24)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 5),
        Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 22)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1.5)),
        ],
      ),
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
        final isTop = i < 3;

        Uint8List? pBytes;
        if (p['photoUrl'] != null && p['photoUrl'] != '') {
          try { pBytes = base64Decode(p['photoUrl']); } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: isTop ? Colors.tealAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
            boxShadow: [
              if (isTop) BoxShadow(color: Colors.tealAccent.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isTop ? Colors.orange.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${i + 1}', style: GoogleFonts.bebasNeue(color: isTop ? Colors.orange : Colors.white24, fontSize: 16)),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white10,
                  backgroundImage: pBytes != null ? MemoryImage(pBytes) : null,
                  child: pBytes == null ? Text(p['name'][0], style: const TextStyle(color: Colors.tealAccent, fontSize: 12)) : null,
                ),
              ],
            ),
            title: Text(
              StringUtils.capitalize(p['name']), 
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)
            ),
            subtitle: Row(
              children: [
                Text('$monthlyTotal BALLS', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 11, letterSpacing: 0.5)),
                const SizedBox(width: 8),
                if (lifetimeDue > 0)
                  _buildMiniTag('DUE: ${lifetimeDue.toInt()}৳', Colors.redAccent)
                else if (credit > 0)
                  _buildMiniTag('CREDIT: ${credit.toInt()}৳', Colors.greenAccent)
                else
                  _buildMiniTag('CLEARED', Colors.greenAccent),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.send_to_mobile_rounded, color: Colors.greenAccent.withOpacity(0.7), size: 20),
              onPressed: () => _sendWhatsAppReminder(p),
            ),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem('LIFETIME FINE', '${p['totalFine'].toInt()} ৳', Colors.white70),
                        _buildDetailItem('TOTAL PAID', '${totalGiven.toInt()} ৳', Colors.tealAccent),
                        _buildDetailItem('MONTHLY DUE', '${monthlyDue.toInt()} ৳', monthlyDue > 0 ? Colors.orangeAccent : Colors.white24),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET BALANCE', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 14)),
                          Text(
                            lifetimeDue > 0 ? '- ${lifetimeDue.toInt()} ৳' : '+ ${credit.toInt()} ৳',
                            style: GoogleFonts.bebasNeue(
                              color: lifetimeDue > 0 ? Colors.redAccent : Colors.greenAccent, 
                              fontSize: 22
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: GoogleFonts.bebasNeue(color: color, fontSize: 9, letterSpacing: 0.5)),
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

  Widget _buildGivenHistoryTab(FineProvider fineProvider, ContributionProvider contributionProvider) {
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
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03)),
              child: const Icon(Icons.history_rounded, color: Colors.white10, size: 80),
            ),
            const SizedBox(height: 20),
            Text('NO PAYMENT HISTORY', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 28, letterSpacing: 1.5)),
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
      padding: const EdgeInsets.all(20),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        String dateKey = dates[index];
        DateTime date = DateTime.parse(dateKey);
        List<dynamic> items = grouped[dateKey]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.tealAccent.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Text(DateFormat('MMM').format(date).toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14, letterSpacing: 1)),
                    Text(DateFormat('dd').format(date), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 32, height: 1)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: items.map((p) {
                    bool isDirect = p is FinePayment;
                    String name = isDirect ? p.playerName : p.name;
                    String note = isDirect ? (p.note ?? "Fine Payment") : "(Via Contrib) ${p.ballTape}";
                    double amount = isDirect ? p.amountPaid : p.taka;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name[0].toUpperCase() + name.substring(1).toLowerCase(), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(note, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Color(0xFF00E676).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF00E676).withOpacity(0.2))),
                            child: Text('${amount.toInt()} ৳', style: GoogleFonts.bebasNeue(color: Color(0xFF00E676), fontSize: 18)),
                          ),
                          if (Provider.of<AuthProvider>(context, listen: false).isAdmin) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                if (isDirect) {
                                  _confirmDeleteGivenFine(context, fineProvider, p);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete this via Financials tab')));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(Icons.delete_outline_rounded, color: isDirect ? Colors.redAccent : Colors.white24, size: 18),
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
      message = "Hey ${StringUtils.capitalize(name)}, you have a club due of ${due.toInt()} BDT. Please clear it at your earliest convenience. - Ball Killer by Mini Cricket";
    } else if (credit > 0) {
      message = "Hey ${StringUtils.capitalize(name)}, you have ${credit.toInt()} BDT credit in the club fund. Thanks for your support! - Ball Killer by Mini Cricket";
    } else {
      message = "Hey ${StringUtils.capitalize(name)}, your club account is all clear! Keep it up. - Ball Killer by Mini Cricket";
    }
    showDialog(
     context: context,
     builder: (ctx) => AlertDialog(
       backgroundColor: const Color(0xFF020C3B),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Color(0xFF00E676).withOpacity(0.2))),
       title: Row(
         children: [
           const Icon(Icons.send_to_mobile, color: Color(0xFF00E676)),
           const SizedBox(width: 10),
           Text('MESSAGE PREVIEW', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20)),
         ],
       ),        content: Text(message, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.bebasNeue(color: Colors.white24)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(ctx);
              final url = "https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}";
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: Text('SEND NOW', style: GoogleFonts.bebasNeue(color: Colors.white)),
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
        title: Text('DELETE RECORD', style: GoogleFonts.bebasNeue(color: Colors.white)),
        content: Text('Remove this record of ${payment.amountPaid.toInt()}?', style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.poppins())),
          TextButton(
            onPressed: () {
              provider.deletePayment(payment.id!);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
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
    bool syncToFinancials = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF020C3B),
          title: Text('ADD FINE GIVEN', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
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
                                  radius: 15,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: p['photoUrl'] != null && p['photoUrl'] != '' ? MemoryImage(base64Decode(p['photoUrl'])) : null,
                                  child: p['photoUrl'] == null || p['photoUrl'] == '' ? Text(p['name'][0], style: const TextStyle(fontSize: 10)) : null,
                                ),
                                title: Text(p['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                subtitle: Text('Total Lost: ${p['total']} balls', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                onTap: () => onSelected(p),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: amountController,
                    decoration: _inputDecoration('GIVEN AMOUNT'),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Enter amount' : null,
                  ),
                  const SizedBox(height: 15),
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
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('DATE: ${DateFormat('MMM dd, yyyy').format(selectedDate)}', style: const TextStyle(color: Colors.white70)),
                          const Icon(Icons.calendar_today, color: Colors.tealAccent, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
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
            TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.poppins())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedPlayerId != null) {
                  final amount = double.parse(amountController.text);
                  bool success = false;
                  
                  // ALWAYS add to financials (Contribution)
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
                  success = await Provider.of<ContributionProvider>(context, listen: false).addContribution(contrib);
                  
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record added successfully')));
                  }
                }
              },
              child: Text('SAVE RECORD', style: GoogleFonts.bebasNeue(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.tealAccent)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }
}
