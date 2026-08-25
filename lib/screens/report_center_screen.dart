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
import '../models/fund.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';
import '../utils/date_utils.dart';

class ReportCenterScreen extends StatefulWidget {
  const ReportCenterScreen({super.key});

  @override
  State<ReportCenterScreen> createState() => _ReportCenterScreenState();
}

class _ReportCenterScreenState extends State<ReportCenterScreen> {
  bool _isProcessing = false;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = 'Overall';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).init();
      Provider.of<FundProvider>(context, listen: false).fetchFunds();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
    });
  }

  Future<void> _generateMonthlyBundle({String? overrideMonth}) async {
    final String month = overrideMonth ?? _selectedMonth ?? 'Overall';

    setState(() => _isProcessing = true);

    try {
      final ballProv = Provider.of<BallProvider>(context, listen: false);
      final fineProv = Provider.of<FineProvider>(context, listen: false);
      final contProv = Provider.of<ContributionProvider>(context, listen: false);
      final fundProv = Provider.of<FundProvider>(context, listen: false);

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
      final List<Fund> filteredFunds = month == 'Overall' 
          ? fundProv.funds 
          : fundProv.funds.where((f) => DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date)) == month).toList();

      await ExportService.addFundReport(
        masterPdf, 
        funds: filteredFunds, 
        grandTotal: month == 'Overall' ? fundProv.grandTotal : filteredFunds.fold(0, (sum, f) => f.type == 'EXPENSE' ? sum - f.amount : sum + f.amount), 
        players: ballProv.players,
        monthYear: month,
      );

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

      // PAGE 5: LEADERBOARD WITH DUAL COLUMNS AND MONTH-BY-MONTH BREAKDOWN
      final leaderboardPlayers = ballProv.getPlayersWithTotals(monthYear: month);
      final monthlyBreakdownMap = _getMonthlyBreakdownMap(ballProv);
      await ExportService.addLeaderboard(
        masterPdf, 
        monthYear: month, 
        players: leaderboardPlayers,
        monthlyBreakdown: monthlyBreakdownMap,
      );

      final Uint8List mergedBytes = await masterPdf.save();
      final String filename = 'Club_Master_Report_${month.replaceAll(' ', '_')}.pdf';

      await ExportService.downloadMultiplePdfs([mergedBytes], [filename]);
      if (mounted) {
        StatusDialog.show(
          context, 
          title: "SUCCESS", 
          message: "${month == 'Overall' ? 'Overall' : month} Master Report Generated!", 
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

  Map<String, List<Map<String, dynamic>>> _getMonthlyBreakdownMap(BallProvider ballProv) {
    Set<String> monthsWithData = {};
    for (var r in ballProv.allRecords) {
      if (r.monthYear.isNotEmpty) {
        monthsWithData.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
      }
    }
    monthsWithData.add(DateFormat('MMMM yyyy').format(DateTime.now()));

    Map<String, List<Map<String, dynamic>>> monthlyBreakdown = {};
    for (var m in monthsWithData) {
      monthlyBreakdown[m] = ballProv.getPlayersWithTotals(monthYear: m);
    }
    return monthlyBreakdown;
  }

  Future<void> _generateSpecificPdf(String type) async {
    final String month = _selectedMonth ?? 'Overall';
    setState(() => _isProcessing = true);

    try {
      final ballProv = Provider.of<BallProvider>(context, listen: false);
      final fineProv = Provider.of<FineProvider>(context, listen: false);
      final contProv = Provider.of<ContributionProvider>(context, listen: false);
      final fundProv = Provider.of<FundProvider>(context, listen: false);

      if (type == 'LEADERBOARD') {
        final players = ballProv.getPlayersWithTotals(monthYear: month);
        final breakdown = _getMonthlyBreakdownMap(ballProv);
        await ExportService.exportLeaderboard(monthYear: month, players: players, monthlyBreakdown: breakdown);
      } else if (type == 'FINES') {
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
        await ExportService.exportFineReport(monthYear: month, sortedPlayers: enriched);
      } else if (type == 'FINANCIALS') {
        final summaryData = _getSummaryData(contProv, fineProv, month);
        await ExportService.exportFinancialSummaryReport(monthYear: month, data: summaryData, players: ballProv.players);
      } else if (type == 'TREASURY') {
        final List<Fund> filteredFunds = month == 'Overall' 
            ? fundProv.funds 
            : fundProv.funds.where((f) => DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date)) == month).toList();
        final double grandTotal = month == 'Overall' 
            ? fundProv.grandTotal 
            : filteredFunds.fold(0, (sum, f) => f.type == 'EXPENSE' ? sum - f.amount : sum + f.amount);
        await ExportService.exportFundReport(funds: filteredFunds, grandTotal: grandTotal, players: ballProv.players, monthYear: month);
      }

      if (mounted) {
        StatusDialog.show(context, title: "SUCCESS", message: "$type PDF Exported!", isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        StatusDialog.show(context, title: "ERROR", message: "Export Failed: $e", isSuccess: false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      body: Consumer<BallProvider>(
        builder: (context, ballProvider, child) {
          final monthList = _getMonths(ballProvider);
          final List<String> monthlyOnly = monthList.where((m) => m != 'Overall').toList();
          
          if (_selectedMonth == null || !monthList.contains(_selectedMonth)) {
            _selectedMonth = 'Overall';
          }

          return Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildHeader(),
                          const SizedBox(height: 25),
                          _buildInfoCard(),
                          const SizedBox(height: 30),
                          
                          // INDIVIDUAL EXPORTS
                          _buildSectionTitle('INDIVIDUAL REPORT EXPORTS', Colors.tealAccent),
                          const SizedBox(height: 15),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.2,
                            children: [
                              _buildQuickExportChip('LEADERBOARD PDF', Icons.emoji_events_rounded, Colors.amberAccent, () => _generateSpecificPdf('LEADERBOARD')),
                              _buildQuickExportChip('FINES PDF', Icons.money_off_rounded, Colors.redAccent, () => _generateSpecificPdf('FINES')),
                              _buildQuickExportChip('FINANCIALS PDF', Icons.payments_rounded, const Color(0xFF00E676), () => _generateSpecificPdf('FINANCIALS')),
                              _buildQuickExportChip('TREASURY PDF', Icons.account_balance_rounded, Colors.cyanAccent, () => _generateSpecificPdf('TREASURY')),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // OVERALL SECTION
                          _buildSectionTitle('REPORT PERIOD SELECTION', Colors.orangeAccent),
                          const SizedBox(height: 15),
                          _buildReportItem('OVERALL (ALL TIME)', 'Overall', Icons.analytics_outlined, Colors.tealAccent),
                          const SizedBox(height: 15),
                          
                          // MONTHLY SECTION
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.2,
                            ),
                            itemCount: monthlyOnly.length,
                            itemBuilder: (ctx, i) {
                              final month = monthlyOnly[i];
                              return _buildReportItem(month.toUpperCase(), month, Icons.calendar_month_rounded, Colors.orangeAccent);
                            },
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.orange),
                        const SizedBox(height: 20),
                        Text('GENERATING PDF REPORT...', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomActionContainer(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickExportChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF020C3B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 12, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ANALYTICS & EXPORTS', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
            Text('REPORT CENTER', style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.white, letterSpacing: 1.5)),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildReportItem(String label, String value, IconData icon, Color activeColor) {
    final isSelected = _selectedMonth == value;
    return InkWell(
      onTap: () => setState(() => _selectedMonth = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected 
              ? [activeColor.withOpacity(0.2), activeColor.withOpacity(0.05)]
              : [const Color(0xFF0A1235), const Color(0xFF020C3B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Colors.white10, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.1), blurRadius: 10)] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.white24, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label, 
                textAlign: TextAlign.center, 
                style: GoogleFonts.bebasNeue(
                  color: isSelected ? Colors.white : Colors.white38, 
                  fontSize: 14,
                  letterSpacing: 0.8
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionContainer() {
    final label = _selectedMonth != null 
        ? (_selectedMonth == 'Overall' ? 'GENERATE MASTER BUNDLE REPORT' : 'GENERATE ${_selectedMonth!.toUpperCase()} MASTER BUNDLE')
        : 'SELECT A REPORT';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, const Color(0xFF020C3B).withOpacity(0.8), const Color(0xFF020C3B)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ElevatedButton.icon(
            onPressed: _selectedMonth != null ? () => _generateMonthlyBundle() : null,
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            label: Text(label, style: GoogleFonts.bebasNeue(fontSize: 18, color: Colors.white, letterSpacing: 1.2)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, 
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              shadowColor: Colors.orange.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getMonths(BallProvider ballProvider) {
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
    
    return ['Overall', ...sortedMonths];
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
              Text('UPDATED CLUB PDF SUITE', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 15),
          _buildInfoRow('Leaderboard: Month Loss + Lifetime Overall + History'),
          _buildInfoRow('Fine & Account Standing (With Profile Photos)'),
          _buildInfoRow('Treasury Fund Report (Income & Expense Breakdown)'),
          _buildInfoRow('Financial Collection Summary (Unified Player Logs)'),
          _buildInfoRow('Official Club Payment Instructions'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.tealAccent, size: 14),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
