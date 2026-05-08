import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;

import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/fund_provider.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';
import '../utils/date_utils.dart';

class ReportCenterScreen extends StatefulWidget {
  const ReportCenterScreen({super.key});

  @override
  State<ReportCenterScreen> createState() => _ReportCenterScreenState();
}

class _ReportCenterScreenState extends State<ReportCenterScreen> {
  late List<String> _monthList;
  bool _isProcessing = false;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    _selectedMonth = _monthList.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FundProvider>(context, listen: false).fetchFunds();
    });
  }

  void _generateMonthList() {
    _monthList = ['Overall'];
    final ballProvider = Provider.of<BallProvider>(context, listen: false);
    final fineProvider = Provider.of<FineProvider>(context, listen: false);
    final contributionProvider = Provider.of<ContributionProvider>(context, listen: false);
    
    Set<String> months = {};
    for (var r in ballProvider.allRecords) {
      if (r.monthYear.isNotEmpty) months.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
    }
    for (var p in fineProvider.payments) {
      if (p.monthYear.isNotEmpty) months.add(DateUtilsHelper.normalizeMonthYear(p.monthYear));
    }
    for (var c in contributionProvider.contributions) {
      if (c.monthYear.isNotEmpty) months.add(DateUtilsHelper.normalizeMonthYear(c.monthYear));
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

  Future<void> _generateMonthlyBundle() async {
    if (_selectedMonth == null) return;

    setState(() => _isProcessing = true);

    try {
      final ballProv = Provider.of<BallProvider>(context, listen: false);
      final fineProv = Provider.of<FineProvider>(context, listen: false);
      final contProv = Provider.of<ContributionProvider>(context, listen: false);
      final fundProv = Provider.of<FundProvider>(context, listen: false);

      final String month = _selectedMonth!;
      final masterPdf = pw.Document();

      // PAGE 1: FINE REPORT
      final playersWithTotals = ballProv.getPlayersWithTotals(monthYear: month);
      final enriched = playersWithTotals.map((p) {
        final double directFinePayments = fineProv.getTotalPaidForPlayer(p['id'], month);
        final double allContribs = contProv.contributions
            .where((c) => c.playerId == p['id'] && (month == 'Overall' || c.monthYear == month) && !c.isOther)
            .fold(0.0, (sum, c) => sum + c.taka);

        final double totalFineOwed = (p['total'] as int) * 50.0;
        final double totalMoneyGiven = directFinePayments + allContribs;

        double due = 0; double credit = 0;
        if (totalMoneyGiven >= totalFineOwed) {
          due = 0; credit = totalMoneyGiven - totalFineOwed;
        } else {
          due = totalFineOwed - totalMoneyGiven; credit = 0;
        }

        return {
          ...p,
          'totalFine': totalFineOwed,
          'paid': totalMoneyGiven,
          'due': due,
          'surplus': credit,
        };
      }).toList();
      await ExportService.addFineReport(masterPdf, monthYear: month, sortedPlayers: enriched);

      // PAGE 2: CLUB FUND (INCOME/EXPENSE SPLIT WITH PHOTOS)
      await ExportService.addFundReport(masterPdf, funds: fundProv.funds, grandTotal: fundProv.grandTotal, players: ballProv.players);

      // PAGE 3: FINANCIAL SUMMARY (SORTED BY AMOUNT)
      final Map<String, Map<String, double>> summaryData = _getSummaryData(contProv, fineProv, month);
      await ExportService.addFinancialSummaryReport(
        masterPdf, 
        monthYear: month, 
        data: summaryData,
        players: ballProv.players,
      );

      // PAGE 4: PAYMENT NOTICE
      await ExportService.addPaymentInstructionPage(masterPdf);

      // PAGE 5: LEADERBOARD
      final leaderboardPlayers = ballProv.getPlayersWithTotals(monthYear: month);
      await ExportService.addLeaderboard(masterPdf, monthYear: month, players: leaderboardPlayers);

      final Uint8List mergedBytes = await masterPdf.save();
      final String filename = 'Club_Report_${month.replaceAll('-', '_')}.pdf';

      await ExportService.downloadMultiplePdfs([mergedBytes], [filename]);
      if (mounted) {
        StatusDialog.show(
          context, 
          title: "SUCCESS", 
          message: "Report Generated Successfully!", 
          isSuccess: true
        );
      }
    } catch (e) {
      if (mounted) {
        StatusDialog.show(context, title: "ERROR", message: "Failed: $e", isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Map<String, Map<String, double>> _getSummaryData(ContributionProvider p, FineProvider fp, String monthYear) {
    final contributions = p.getGroupedContributions();
    final payments = fp.payments;
    
    Map<String, Map<String, double>> unified = Map.from(contributions);

    for (var pay in payments) {
      unified.putIfAbsent(pay.monthYear, () => {});
      unified[pay.monthYear]![pay.playerName] = (unified[pay.monthYear]![pay.playerName] ?? 0) + pay.amountPaid;
    }

    if (monthYear != 'Overall') {
      return unified.containsKey(monthYear) ? { monthYear: unified[monthYear]! } : {};
    }
    return unified;
  }

  List<dynamic> _getDetailedData(ContributionProvider p, FineProvider fp, String monthYear) {
    final list = (monthYear == 'Overall' 
        ? p.contributions 
        : p.contributions.where((c) => c.monthYear == monthYear).toList())
        .where((c) => !c.isOther).toList();
    
    final payments = monthYear == 'Overall'
        ? fp.payments
        : fp.payments.where((p) => p.monthYear == monthYear).toList();

    List<dynamic> combined = [...list, ...payments];
    combined.sort((a, b) => b.date.compareTo(a.date));
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('REPORT CENTER', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 30),
                    Text('SELECT MONTH', style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 18, letterSpacing: 1)),
                    const SizedBox(height: 15),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.8,
                        ),
                        itemCount: _monthList.length,
                        itemBuilder: (ctx, i) {
                          final month = _monthList[i];
                          final isSelected = _selectedMonth == month;
                          final label = month == 'Overall' ? 'OVERALL' : month.toUpperCase();

                          return InkWell(
                            onTap: () => setState(() => _selectedMonth = month),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.orange.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: isSelected ? Colors.orange : Colors.white10),
                                boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10)] : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(color: isSelected ? Colors.orange : Colors.white38, fontSize: 13)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
            ),
        ],
      ),
      bottomNavigationBar: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _buildBottomAction(),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_motion_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 15),
              Text('PROFESSIONAL CLUB REPORTS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 15),
          _buildInfoRow('Fine & Account Status'),
          _buildInfoRow('Fund Report (Income/Expense)'),
          _buildInfoRow('Financial Summary (Sorted)'),
          _buildInfoRow('Official Payment Notice'),
          _buildInfoRow('Club Leaderboard'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 12),
          const SizedBox(width: 10),
          Text(text, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      color: const Color(0xFF020C3B),
      child: ElevatedButton.icon(
        onPressed: _generateMonthlyBundle,
        icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
        label: Text('GENERATE & SHARE REPORT', style: GoogleFonts.bebasNeue(fontSize: 18, color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      ),
    );
  }
}
