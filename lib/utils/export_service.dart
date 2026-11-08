import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/contribution.dart';
import '../models/fine_payment.dart';
import '../models/fund.dart';
import '../models/room.dart';
import 'string_utils.dart';
import 'date_utils.dart';
import '../app_config.dart';

class ExportService {
  // Brand Palette
  static final primaryColor = PdfColor.fromHex('#051970');
  static final primaryDark = PdfColor.fromHex('#020C3B');
  static final accentColor = PdfColor.fromHex('#00BFA5');
  static final accentLight = PdfColor.fromHex('#E0F2F1');
  static final bgLight = PdfColor.fromHex('#F8FAFC');
  static final bgCard = PdfColor.fromHex('#F1F5F9');
  static final borderLight = PdfColor.fromHex('#E2E8F0');
  static final textDark = PdfColor.fromHex('#0F172A');
  static final textMuted = PdfColor.fromHex('#64748B');

  // Status Badge Colors
  static final badgeRedBg = PdfColor.fromHex('#FEE2E2');
  static final badgeRedText = PdfColor.fromHex('#B91C1C');
  static final badgeGreenBg = PdfColor.fromHex('#DCFCE7');
  static final badgeGreenText = PdfColor.fromHex('#15803D');
  static final badgeBlueBg = PdfColor.fromHex('#E0F2FE');
  static final badgeBlueText = PdfColor.fromHex('#0369A1');
  static final badgeGoldBg = PdfColor.fromHex('#FEF3C7');
  static final badgeGoldText = PdfColor.fromHex('#B45309');

  // --- LOGO LOADER ---
  static Future<pw.MemoryImage?> _loadClubLogo() async {
    try {
      final ByteData logoBytes = await rootBundle.load('assets/icon/logo3.png');
      return pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      try {
        final ByteData logoBytes = await rootBundle.load('assets/logonew.png');
        return pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
  }

  static Future<pw.MemoryImage?> _loadPdfImage(String source) async {
    try {
      if (source.startsWith('data:image') || (!source.startsWith('assets') && source.length > 100)) {
        final pure = source.contains(',') ? source.split(',').last : source;
        return pw.MemoryImage(base64Decode(pure));
      }
      final ByteData data = await rootBundle.load(source);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        if (source.endsWith('.jpeg')) {
          final ByteData data = await rootBundle.load(source.replaceAll('.jpeg', '.jpg'));
          return pw.MemoryImage(data.buffer.asUint8List());
        } else if (source.endsWith('.jpg')) {
          final ByteData data = await rootBundle.load(source.replaceAll('.jpg', '.jpeg'));
          return pw.MemoryImage(data.buffer.asUint8List());
        }
      } catch (_) {}
      return null;
    }
  }

  // --- PUBLIC EXPORT METHODS ---

  static Future<void> exportFundReport({
    required List<Fund> funds,
    required double grandTotal,
    required List<dynamic> players,
    String monthYear = 'Overall',
    Room? room,
  }) async {
    final pdf = pw.Document();
    await addFundReport(pdf, funds: funds, grandTotal: grandTotal, players: players, monthYear: monthYear);
    await addPaymentInstructionPage(pdf, room: room);
    await sharePdf(await pdf.save(), 'club_fund_report.pdf');
  }

  static Future<void> exportPlayerStatusReport({
    required List<Map<String, dynamic>> players,
    Room? room,
  }) async {
    final pdf = pw.Document();
    await addPlayerStatusReport(pdf, players: players);
    await addPaymentInstructionPage(pdf, room: room);
    await sharePdf(await pdf.save(), 'master_player_status.pdf');
  }

  static Future<void> exportFinancialSummaryReport({
    required String monthYear,
    required Map<String, Map<String, double>> data,
    required List<dynamic> players,
    Room? room,
  }) async {
    final pdf = pw.Document();
    await addFinancialSummaryReport(pdf, monthYear: monthYear, data: data, players: players);
    await addPaymentInstructionPage(pdf, room: room);
    await sharePdf(await pdf.save(), 'financial_summary.pdf');
  }

  static Future<void> exportFinancialDetailedReport({
    required String monthYear,
    required List<dynamic> contributions,
    required List<dynamic> players,
    Room? room,
  }) async {
    final pdf = pw.Document();
    await addFinancialDetailedReport(pdf, monthYear: monthYear, contributions: contributions, players: players);
    await addPaymentInstructionPage(pdf, room: room);
    await sharePdf(await pdf.save(), 'financial_detailed.pdf');
  }

  static Future<void> exportOtherContributionsReport({
    required String monthYear,
    required List<Contribution> contributions,
    required List<dynamic> players,
    Room? room,
  }) async {
    final pdf = pw.Document();
    await addOtherContributionsReport(pdf, monthYear: monthYear, contributions: contributions, players: players);
    await addPaymentInstructionPage(pdf, room: room);
    await sharePdf(await pdf.save(), 'other_contributions.pdf');
  }

  static Future<void> exportLeaderboard({
    required String monthYear,
    required List<Map<String, dynamic>> players,
    Map<String, List<Map<String, dynamic>>>? monthlyBreakdown,
    Room? room,
  }) async {
    final pdf = pw.Document();
    await addLeaderboard(pdf, monthYear: monthYear, players: players, monthlyBreakdown: monthlyBreakdown);
    await addPaymentInstructionPage(pdf, room: room);
    await sharePdf(await pdf.save(), 'leaderboard.pdf');
  }

  static Future<void> exportFineReport({
    required String monthYear,
    required List<Map<String, dynamic>> sortedPlayers,
    Room? room,
  }) async {
    final pdf = pw.Document();
    await addFineReport(pdf, monthYear: monthYear, sortedPlayers: sortedPlayers);
    await addPaymentInstructionPage(pdf, room: room);
    await sharePdf(await pdf.save(), 'fine_report.pdf');
  }

  static Future<void> downloadMultiplePdfs(List<Uint8List> pdfs, List<String> filenames) async {
    try {
      if (pdfs.isEmpty) return;
      if (pdfs.length == 1) {
        await sharePdf(pdfs.first, filenames.first);
        return;
      }
      final List<XFile> xFiles = [];
      for (int i = 0; i < pdfs.length; i++) {
        xFiles.add(XFile.fromData(pdfs[i], name: filenames[i], mimeType: 'application/pdf'));
      }
      await Share.shareXFiles(xFiles, text: 'Download club reports');
    } catch (e) {
      if (pdfs.isNotEmpty) {
        await sharePdf(pdfs.first, filenames.first);
      }
    }
  }

  // --- PDF BUILDERS ---

  static Future<void> addPaymentInstructionPage(pw.Document pdf, {Room? room}) async {
    final String rCode = room?.code ?? 'SPK13';
    final String bkash1 = (room?.bkash1Number != null && room!.bkash1Number.isNotEmpty) ? room.bkash1Number : '01724293453';
    final String rawBkash1 = (room?.bkash1Name != null && room!.bkash1Name.isNotEmpty) ? room.bkash1Name : 'bKash Personal';
    final String bkash1Title = rawBkash1.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim().isNotEmpty
        ? rawBkash1.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
        : 'bKash Personal';
    final String bkash1QrPath = (room?.bkash1Qr != null && room!.bkash1Qr.isNotEmpty) ? room.bkash1Qr : 'assets/1.jpeg';

    final String bkash2 = (room?.bkash2Number != null && room!.bkash2Number.isNotEmpty) ? room.bkash2Number : '01832465446';
    final String rawBkash2 = (room?.bkash2Name != null && room!.bkash2Name.isNotEmpty) ? room.bkash2Name : 'bKash Personal';
    final String bkash2Title = rawBkash2.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim().isNotEmpty
        ? rawBkash2.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
        : 'bKash Personal';
    final String bkash2QrPath = (room?.bkash2Qr != null && room!.bkash2Qr.isNotEmpty) ? room.bkash2Qr : 'assets/2.jpeg';

    final String bName = (room?.bankName != null && room!.bankName.isNotEmpty) ? room.bankName : AppConfig.bankName;
    final String bAccName = (room?.bankAccountName != null && room!.bankAccountName.isNotEmpty) ? room.bankAccountName : AppConfig.bankAccountName;
    final String bAccNum = (room?.bankAccountNumber != null && room!.bankAccountNumber.isNotEmpty) ? room.bankAccountNumber : AppConfig.bankAccountNumber;
    final String bRouting = (room?.routingNumber != null && room!.routingNumber.isNotEmpty) ? room.routingNumber : AppConfig.routingNumber;
    final String bBranch = (room != null && room.bankBranch.isNotEmpty && room.bankBranch != 'Principal Branch') 
        ? room.bankBranch 
        : 'Gulshan Principal Branch';
    final String bLogoPath = (room?.bankLogo != null && room!.bankLogo.isNotEmpty) ? room.bankLogo : 'assets/brack_bank.jpg';
    final String noticeMsg = (room?.noticeText != null && room!.noticeText.isNotEmpty) ? room.noticeText : 'Please clear your fine or contribution before or during match sessions. You can scan the QR code or send directly to the numbers below.';
    final String refInstruction = (room?.referenceNote != null && room!.referenceNote.isNotEmpty) ? room.referenceNote : 'Always write your Player Name in the Reference so we can credit your payment.';

    final pw.MemoryImage? bkashLogo = await _loadPdfImage('assets/bkash.png');
    final pw.MemoryImage? bracLogo = await _loadPdfImage(bLogoPath);
    final pw.MemoryImage? qr1Img = await _loadPdfImage(bkash1QrPath);
    final pw.MemoryImage? qr2Img = await _loadPdfImage(bkash2QrPath);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: borderLight, width: 1.2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(
                      'OFFICIAL PAYMENT INSTRUCTIONS',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1.1),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'SUDDEN PLAN CRICKET CLUB | TREASURY NOTICE | ROOM: $rCode',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentColor, letterSpacing: 0.8),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    noticeMsg,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 8, lineSpacing: 1.3, color: textMuted),
                  ),
                  pw.SizedBox(height: 10),

                  // Important Reference Callout
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: pw.BoxDecoration(
                      color: badgeGoldBg,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColor.fromHex('#F59E0B'), width: 0.8),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'MANDATORY: WRITE YOUR PLAYER NAME IN REFERENCE / REMARKS',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: badgeGoldText),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          refInstruction,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 7.5, color: textDark),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Two bKash Cards Side-by-Side
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Option 1
                      pw.Expanded(
                        child: pw.Container(
                          margin: const pw.EdgeInsets.only(right: 6),
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: bgLight,
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: borderLight, width: 0.8),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  if (bkashLogo != null)
                                    pw.Container(height: 16, width: 32, child: pw.Image(bkashLogo, fit: pw.BoxFit.contain)),
                                  pw.SizedBox(width: 4),
                                  pw.Text(bkash1Title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark)),
                                ],
                              ),
                              pw.SizedBox(height: 6),
                              if (qr1Img != null)
                                pw.Container(
                                  height: 80,
                                  width: 80,
                                  padding: const pw.EdgeInsets.all(3),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.circular(6),
                                    border: pw.Border.all(color: borderLight),
                                  ),
                                  child: pw.Image(qr1Img, fit: pw.BoxFit.contain),
                                ),
                              pw.SizedBox(height: 6),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FCE4EC'), borderRadius: pw.BorderRadius.circular(4)),
                                child: pw.Text(
                                  bkash1,
                                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#C2185B'), fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text('Send Money / Scan QR', style: pw.TextStyle(fontSize: 6.5, color: textMuted)),
                            ],
                          ),
                        ),
                      ),

                      // Option 2
                      pw.Expanded(
                        child: pw.Container(
                          margin: const pw.EdgeInsets.only(left: 6),
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: bgLight,
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: borderLight, width: 0.8),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  if (bkashLogo != null)
                                    pw.Container(height: 16, width: 32, child: pw.Image(bkashLogo, fit: pw.BoxFit.contain)),
                                  pw.SizedBox(width: 4),
                                  pw.Text(bkash2Title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark)),
                                ],
                              ),
                              pw.SizedBox(height: 6),
                              if (qr2Img != null)
                                pw.Container(
                                  height: 80,
                                  width: 80,
                                  padding: const pw.EdgeInsets.all(3),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.circular(6),
                                    border: pw.Border.all(color: borderLight),
                                  ),
                                  child: pw.Image(qr2Img, fit: pw.BoxFit.contain),
                                ),
                              pw.SizedBox(height: 6),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3E5F5'), borderRadius: pw.BorderRadius.circular(4)),
                                child: pw.Text(
                                  bkash2,
                                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#7B1FA2'), fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text('Send Money / Scan QR', style: pw.TextStyle(fontSize: 6.5, color: textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),

                  // Bank Account Card
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: bgCard,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderLight, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('OFFICIAL BANK TRANSFER DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: primaryColor, letterSpacing: 0.6)),
                            if (bracLogo != null)
                              pw.Container(height: 16, width: 40, child: pw.Image(bracLogo, fit: pw.BoxFit.contain)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        _buildBankRow('Account Name', bAccName),
                        _buildBankRow('Account Number', bAccNum),
                        _buildBankRow('Bank Name', bName),
                        _buildBankRow('Routing Number', bRouting),
                        _buildBankRow('Branch', bBranch),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Sudden Plan Cricket Team | Official Treasury Document', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 6.5, color: textMuted)),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }

  static Future<void> addFundReport(
    pw.Document pdf, {
    required List<Fund> funds,
    required double grandTotal,
    required List<dynamic> players,
    String monthYear = 'Overall',
  }) async {
    if (funds.isEmpty) return;
    final logoImage = await _loadClubLogo();

    Map<String, List<Fund>> monthGroups = {};
    for (var f in funds) {
      String monthKey = DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date));
      monthGroups.putIfAbsent(monthKey, () => []);
      monthGroups[monthKey]!.add(f);
    }

    var sortedMonths = monthGroups.keys.toList()
      ..sort((a, b) {
        try {
          DateTime da = DateFormat('MMMM yyyy').parse(a);
          DateTime db = DateFormat('MMMM yyyy').parse(b);
          return db.compareTo(da);
        } catch (_) {
          return b.compareTo(a);
        }
      });

    final totalIncome = funds.where((f) => f.type != 'EXPENSE').fold(0.0, (sum, f) => sum + f.amount);
    final totalExpense = funds.where((f) => f.type == 'EXPENSE').fold(0.0, (sum, f) => sum + f.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildPdfHeader(
          'Official Treasury & Fund Report',
          monthYear == 'Overall' ? 'Full Historical Statement' : 'Financial Statement: $monthYear',
          logoImage,
        ),
        footer: (context) => _buildPdfFooter('Club Fund Document', context.pageNumber),
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          // KPI summary
          content.add(
            _buildKpiBar([
              {'title': 'Total Income', 'value': '+${totalIncome.toInt()} BDT', 'color': badgeGreenText},
              {'title': 'Total Expense', 'value': '-${totalExpense.toInt()} BDT', 'color': badgeRedText},
              {'title': 'Net Fund Balance', 'value': '${grandTotal.toInt()} BDT', 'color': primaryColor},
            ]),
          );

          for (var monthName in sortedMonths) {
            final monthFunds = monthGroups[monthName]!;
            final incomes = monthFunds.where((f) => f.type != 'EXPENSE').toList();
            final expenses = monthFunds.where((f) => f.type == 'EXPENSE').toList();
            final totalInc = incomes.fold(0.0, (sum, f) => sum + f.amount);
            final totalExp = expenses.fold(0.0, (sum, f) => sum + f.amount);

            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: pw.BoxDecoration(color: primaryDark, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(monthName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white)),
                    pw.Text('Month Net: BDT ${(totalInc - totalExp).toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: accentColor)),
                  ],
                ),
              ),
            );

            if (incomes.isNotEmpty) content.add(_buildFundSubTable(incomes, players, isExpense: false));
            if (expenses.isNotEmpty) content.add(_buildFundSubTable(expenses, players, isExpense: true));
          }

          content.add(pw.SizedBox(height: 12));
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: bgCard, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: primaryColor, width: 0.8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    monthYear == 'Overall' ? 'GRAND TOTAL CLUB TREASURY BALANCE' : 'STATEMENT PERIOD BALANCE',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.Text(
                    '${grandTotal.toInt()} BDT',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                ],
              ),
            ),
          );
          return content;
        },
      ),
    );
  }

  static Future<void> addPlayerStatusReport(pw.Document pdf, {required List<Map<String, dynamic>> players}) async {
    if (players.isEmpty) return;
    final logoImage = await _loadClubLogo();

    final int totalPlayers = players.length;
    final int totalBalls = players.fold<int>(0, (sum, p) => sum + ((p['total'] ?? 0) as num).toInt());
    final double totalFine = players.fold<double>(0.0, (sum, p) => sum + ((p['totalFine'] ?? 0.0) as num).toDouble());
    final double totalPaid = players.fold<double>(0.0, (sum, p) => sum + ((p['paid'] ?? 0.0) as num).toDouble());
    final double totalDue = players.fold<double>(0.0, (sum, p) => sum + ((p['due'] ?? 0.0) as num).toDouble());
    final double totalSurplus = players.fold<double>(0.0, (sum, p) => sum + ((p['surplus'] ?? 0.0) as num).toDouble());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildPdfHeader('Master Player Status', 'All-Time Cumulative Account Audit', logoImage),
        footer: (context) => _buildPdfFooter('Player Status Audit Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildKpiBar([
              {'title': 'Players', 'value': '$totalPlayers Active', 'color': primaryColor},
              {'title': 'Balls Lost', 'value': '$totalBalls Balls', 'color': accentColor},
              {'title': 'Total Fine', 'value': '${totalFine.toInt()} BDT', 'color': textDark},
              {'title': 'Total Paid', 'value': '${totalPaid.toInt()} BDT', 'color': badgeGreenText},
              {'title': 'Net Outstanding', 'value': '${totalDue.toInt()} BDT', 'color': badgeRedText},
              {'title': 'Total Surplus', 'value': '${totalSurplus.toInt()} BDT', 'color': badgeBlueText},
            ]),
            _buildTable(
              columnWidths: {
                0: const pw.FixedColumnWidth(28), // Rank
                1: const pw.FixedColumnWidth(30), // Photo
                2: const pw.FlexColumnWidth(1.6), // Name
                3: const pw.FixedColumnWidth(38), // Balls
                4: const pw.FixedColumnWidth(48), // Fine
                5: const pw.FixedColumnWidth(48), // Paid
                6: const pw.FixedColumnWidth(55), // Due
                7: const pw.FixedColumnWidth(55), // Credit
              },
              [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    _buildHeaderCell('Rank', align: pw.TextAlign.center),
                    _buildHeaderCell('Pic', align: pw.TextAlign.center),
                    _buildHeaderCell('Player Name'),
                    _buildHeaderCell('Balls', align: pw.TextAlign.center),
                    _buildHeaderCell('Fine', align: pw.TextAlign.right),
                    _buildHeaderCell('Paid', align: pw.TextAlign.right),
                    _buildHeaderCell('Net Due', align: pw.TextAlign.right),
                    _buildHeaderCell('Credit', align: pw.TextAlign.right),
                  ],
                ),
                ...players.asMap().entries.map((entry) {
                  final p = entry.value;
                  pw.MemoryImage? playerPhoto;
                  try {
                    if (p['photoUrl'] != null && p['photoUrl'] != '') playerPhoto = pw.MemoryImage(base64Decode(p['photoUrl']));
                  } catch (_) {}

                  final double due = (p['due'] as num?)?.toDouble() ?? 0.0;
                  final double credit = (p['surplus'] as num?)?.toDouble() ?? 0.0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : bgLight),
                    children: [
                      _buildDataCell('${entry.key + 1}', align: pw.TextAlign.center, fontWeight: entry.key < 3 ? pw.FontWeight.bold : pw.FontWeight.normal),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(
                          child: pw.Container(
                            height: 18,
                            width: 18,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: PdfColors.grey200,
                              border: pw.Border.all(color: borderLight, width: 0.5),
                              image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null,
                            ),
                            child: playerPhoto == null ? pw.Center(child: pw.Text(p['name'][0].toUpperCase(), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))) : null,
                          ),
                        ),
                      ),
                      _buildDataCell(StringUtils.capitalize(p['name']), fontWeight: pw.FontWeight.bold),
                      _buildDataCell('${p['total']}', align: pw.TextAlign.center),
                      _buildDataCell('${(p['totalFine'] as num).toInt()} BDT', align: pw.TextAlign.right),
                      _buildDataCell('${(p['paid'] as num).toInt()} BDT', align: pw.TextAlign.right, color: badgeGreenText, fontWeight: pw.FontWeight.bold),
                      due > 0
                          ? _buildBadgeCell('${due.toInt()} BDT', bg: badgeRedBg, fg: badgeRedText, align: pw.TextAlign.right)
                          : _buildBadgeCell('0 (CLEAR)', bg: badgeGreenBg, fg: badgeGreenText, align: pw.TextAlign.right),
                      credit > 0
                          ? _buildBadgeCell('${credit.toInt()} BDT', bg: badgeBlueBg, fg: badgeBlueText, align: pw.TextAlign.right)
                          : _buildDataCell('-', align: pw.TextAlign.right, color: textMuted),
                    ],
                  );
                }),
                // Grand Totals Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgCard),
                  children: [
                    pw.SizedBox(),
                    pw.SizedBox(),
                    _buildDataCell('GRAND TOTALS', fontWeight: pw.FontWeight.bold, color: primaryColor),
                    _buildDataCell('$totalBalls', align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    _buildDataCell('${totalFine.toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: textDark),
                    _buildDataCell('${totalPaid.toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: badgeGreenText),
                    _buildBadgeCell('${totalDue.toInt()} BDT', bg: badgeRedBg, fg: badgeRedText, align: pw.TextAlign.right),
                    _buildBadgeCell('${totalSurplus.toInt()} BDT', bg: badgeBlueBg, fg: badgeBlueText, align: pw.TextAlign.right),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );
  }

  static Future<void> addFinancialSummaryReport(
    pw.Document pdf, {
    required String monthYear,
    required Map<String, Map<String, double>> data,
    required List<dynamic> players,
  }) async {
    if (data.isEmpty) return;
    final logoImage = await _loadClubLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildPdfHeader('Aggregated Financial Summary', 'Unified Contributions & Fines', logoImage),
        footer: (context) => _buildPdfFooter('Financial Summary Document', context.pageNumber),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];
          for (var monthKey in data.keys) {
            Map<String, double> playersMap = data[monthKey]!;
            double monthlyTotal = playersMap.values.fold(0, (s, v) => s + v);
            final sortedEntries = playersMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(monthKey.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white)),
                    pw.Text('Total Given: BDT ${monthlyTotal.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: accentColor)),
                  ],
                ),
              ),
            );

            widgets.add(
              _buildTable(
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FixedColumnWidth(30),
                  2: const pw.FlexColumnWidth(),
                  3: const pw.FixedColumnWidth(90),
                },
                [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: bgCard),
                    children: [
                      _buildHeaderCell('No.', align: pw.TextAlign.center, textColor: textDark),
                      _buildHeaderCell('Pic', align: pw.TextAlign.center, textColor: textDark),
                      _buildHeaderCell('Player Name', textColor: textDark),
                      _buildHeaderCell('Total Given', align: pw.TextAlign.right, textColor: textDark),
                    ],
                  ),
                  ...sortedEntries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final e = entry.value;
                    pw.MemoryImage? playerPhoto;
                    try {
                      final p = players.firstWhere((p) => StringUtils.capitalize(p.name) == e.key);
                      if (p.photoUrl != null && p.photoUrl != '') playerPhoto = pw.MemoryImage(base64Decode(p.photoUrl));
                    } catch (_) {}
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.white : bgLight),
                      children: [
                        _buildDataCell('${idx + 1}', align: pw.TextAlign.center),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Center(
                            child: pw.Container(
                              height: 16,
                              width: 16,
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                color: PdfColors.grey200,
                                image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null,
                              ),
                              child: playerPhoto == null ? pw.Center(child: pw.Text(e.key[0].toUpperCase(), style: pw.TextStyle(fontSize: 6))) : null,
                            ),
                          ),
                        ),
                        _buildDataCell(e.key, fontWeight: pw.FontWeight.bold),
                        _buildDataCell('${e.value.toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: badgeGreenText),
                      ],
                    );
                  }),
                ],
              ),
            );
          }
          return widgets;
        },
      ),
    );
  }

  static Future<void> addFinancialDetailedReport(
    pw.Document pdf, {
    required String monthYear,
    required List<dynamic> contributions,
    required List<dynamic> players,
  }) async {
    if (contributions.isEmpty) return;
    final logoImage = await _loadClubLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildPdfHeader('Detailed Transaction List', 'Unified Contribution History', logoImage),
        footer: (context) => _buildPdfFooter('Transaction Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildTable(
              columnWidths: {
                0: const pw.FixedColumnWidth(55),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(70),
              },
              [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    _buildHeaderCell('Date'),
                    _buildHeaderCell('Name'),
                    _buildHeaderCell('Description / Note'),
                    _buildHeaderCell('Amount', align: pw.TextAlign.right),
                  ],
                ),
                ...contributions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  bool isFine = item is FinePayment;
                  String name = StringUtils.capitalize(isFine ? item.playerName : (item as Contribution).name);
                  String note = isFine ? (item.note ?? "Fine Payment") : (item as Contribution).ballTape;
                  double amount = isFine ? item.amountPaid : (item as Contribution).taka;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.white : bgLight),
                    children: [
                      _buildDataCell(DateFormat('dd MMM yy').format(isFine ? item.date : (item as Contribution).date)),
                      _buildDataCell(name, fontWeight: pw.FontWeight.bold),
                      _buildDataCell(note),
                      _buildDataCell('${amount.toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: isFine ? badgeGreenText : null),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );
  }

  static Future<void> addOtherContributionsReport(
    pw.Document pdf, {
    required String monthYear,
    required List<Contribution> contributions,
    required List<dynamic> players,
  }) async {
    if (contributions.isEmpty) return;
    final logoImage = await _loadClubLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildPdfHeader('Non-Cash Contributions', 'Balls, Tape & Equipment Items', logoImage),
        footer: (context) => _buildPdfFooter('Other Contributions Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildTable(
              columnWidths: {
                0: const pw.FixedColumnWidth(55),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(70),
              },
              [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#00796B')),
                  children: [
                    _buildHeaderCell('Date'),
                    _buildHeaderCell('Contributor'),
                    _buildHeaderCell('Item Detail'),
                    _buildHeaderCell('Est. Value', align: pw.TextAlign.right),
                  ],
                ),
                ...contributions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final c = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.white : bgLight),
                    children: [
                      _buildDataCell(DateFormat('dd MMM yy').format(c.date)),
                      _buildDataCell(StringUtils.capitalize(c.name), fontWeight: pw.FontWeight.bold),
                      _buildDataCell(c.ballTape),
                      _buildDataCell(c.taka > 0 ? '${c.taka.toInt()} BDT' : '-', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00796B')),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E0F2F1')),
                  children: [
                    pw.SizedBox(),
                    _buildDataCell('TOTAL SUMMARY', fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00796B')),
                    _buildDataCell('${contributions.fold(0, (sum, c) => sum + c.ballCount)} Balls, ${contributions.fold(0, (sum, c) => sum + c.tapeCount)} Tapes', fontWeight: pw.FontWeight.bold, fontSize: 8),
                    _buildDataCell('${contributions.fold(0.0, (sum, c) => sum + c.taka).toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00796B')),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );
  }

  static Future<void> addLeaderboard(
    pw.Document pdf, {
    required String monthYear,
    required List<Map<String, dynamic>> players,
    Map<String, List<Map<String, dynamic>>>? monthlyBreakdown,
  }) async {
    if (players.isEmpty) return;
    final logoImage = await _loadClubLogo();

    final bool isOverall = monthYear == 'Overall';
    final sorted = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) {
        int cmp = (b['total'] as num).compareTo(a['total'] as num);
        if (cmp != 0) return cmp;
        int cmpOverall = ((b['totalOverall'] ?? b['total']) as num).compareTo((a['totalOverall'] ?? a['total']) as num);
        if (cmpOverall != 0) return cmpOverall;
        return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
      });

    final int totalMonthly = sorted.fold<int>(0, (sum, p) => sum + ((p['total'] ?? 0) as num).toInt());
    final int totalOverall = sorted.fold<int>(0, (sum, p) => sum + ((p['totalOverall'] ?? p['total'] ?? 0) as num).toInt());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildPdfHeader(
          'Club Leaderboard',
          isOverall ? 'Cumulative Performance & Overall Rankings' : 'Performance Rankings: $monthYear',
          logoImage,
        ),
        footer: (context) => _buildPdfFooter('Leaderboard Document', context.pageNumber),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];

          // Leaderboard KPI Bar
          widgets.add(
            _buildKpiBar([
              {'title': 'Ranked Players', 'value': '${sorted.length} Players', 'color': primaryColor},
              if (!isOverall) {'title': 'Month Loss Total', 'value': '$totalMonthly Balls', 'color': badgeRedText},
              {'title': 'Club Cumulative Loss', 'value': '$totalOverall Balls', 'color': textDark},
            ]),
          );

          // Main Table
          widgets.add(
            _buildTable(
              columnWidths: isOverall
                  ? {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FixedColumnWidth(30),
                      2: const pw.FlexColumnWidth(),
                      3: const pw.FixedColumnWidth(100),
                    }
                  : {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FixedColumnWidth(30),
                      2: const pw.FlexColumnWidth(),
                      3: const pw.FixedColumnWidth(90),
                      4: const pw.FixedColumnWidth(90),
                    },
              [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: isOverall
                      ? [
                          _buildHeaderCell('Rank', align: pw.TextAlign.center),
                          _buildHeaderCell('Pic', align: pw.TextAlign.center),
                          _buildHeaderCell('Player Name'),
                          _buildHeaderCell('Total Balls Lost', align: pw.TextAlign.center),
                        ]
                      : [
                          _buildHeaderCell('Rank', align: pw.TextAlign.center),
                          _buildHeaderCell('Pic', align: pw.TextAlign.center),
                          _buildHeaderCell('Player Name'),
                          _buildHeaderCell('$monthYear Balls', align: pw.TextAlign.center),
                          _buildHeaderCell('Overall Total', align: pw.TextAlign.center),
                        ],
                ),
                ...sorted.asMap().entries.map((entry) {
                  final p = entry.value;
                  final int rank = entry.key + 1;
                  final int monthCount = (p['total'] as num).toInt();
                  final int overallCount = ((p['totalOverall'] ?? p['total']) as num).toInt();

                  pw.MemoryImage? playerPhoto;
                  try {
                    if (p['photoUrl'] != null && p['photoUrl'] != '') {
                      playerPhoto = pw.MemoryImage(base64Decode(p['photoUrl']));
                    }
                  } catch (_) {}

                  PdfColor rankBg = rank == 1
                      ? badgeGoldBg
                      : (rank == 2 ? PdfColor.fromHex('#ECEFF1') : (rank == 3 ? PdfColor.fromHex('#FFE0B2') : const PdfColor(0, 0, 0, 0)));
                  PdfColor rankFg = rank == 1
                      ? badgeGoldText
                      : (rank == 2 ? textDark : (rank == 3 ? PdfColor.fromHex('#E65100') : textMuted));

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : bgLight),
                    children: isOverall
                        ? [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                              child: pw.Center(
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: pw.BoxDecoration(color: rankBg, borderRadius: pw.BorderRadius.circular(3)),
                                  child: pw.Text('$rank', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: rankFg)),
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                              child: pw.Center(
                                child: pw.Container(
                                  height: 18,
                                  width: 18,
                                  decoration: pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    color: PdfColors.grey200,
                                    image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null,
                                  ),
                                  child: playerPhoto == null ? pw.Center(child: pw.Text(p['name'][0].toUpperCase(), style: pw.TextStyle(fontSize: 7))) : null,
                                ),
                              ),
                            ),
                            _buildDataCell(StringUtils.capitalize(p['name']), fontWeight: pw.FontWeight.bold),
                            _buildDataCell('$overallCount', align: pw.TextAlign.center, color: entry.key < 3 ? badgeRedText : textDark, fontWeight: pw.FontWeight.bold),
                          ]
                        : [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                              child: pw.Center(
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: pw.BoxDecoration(color: rankBg, borderRadius: pw.BorderRadius.circular(3)),
                                  child: pw.Text('$rank', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: rankFg)),
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                              child: pw.Center(
                                child: pw.Container(
                                  height: 18,
                                  width: 18,
                                  decoration: pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    color: PdfColors.grey200,
                                    image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null,
                                  ),
                                  child: playerPhoto == null ? pw.Center(child: pw.Text(p['name'][0].toUpperCase(), style: pw.TextStyle(fontSize: 7))) : null,
                                ),
                              ),
                            ),
                            _buildDataCell(StringUtils.capitalize(p['name']), fontWeight: pw.FontWeight.bold),
                            _buildDataCell('$monthCount', align: pw.TextAlign.center, color: monthCount > 0 ? badgeRedText : textDark, fontWeight: pw.FontWeight.bold),
                            _buildDataCell('$overallCount', align: pw.TextAlign.center, color: primaryColor, fontWeight: pw.FontWeight.bold),
                          ],
                  );
                }),
                // Total Summary Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgCard),
                  children: isOverall
                      ? [
                          pw.SizedBox(),
                          pw.SizedBox(),
                          _buildDataCell('TOTAL BALLS LOST', fontWeight: pw.FontWeight.bold, color: primaryColor),
                          _buildDataCell('$totalOverall Balls', align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold, color: badgeRedText),
                        ]
                      : [
                          pw.SizedBox(),
                          pw.SizedBox(),
                          _buildDataCell('TOTAL SUMMARY', fontWeight: pw.FontWeight.bold, color: primaryColor),
                          _buildDataCell('$totalMonthly Balls', align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold, color: badgeRedText),
                          _buildDataCell('$totalOverall Balls', align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ],
                ),
              ],
            ),
          );

          // Monthly Breakdown Section
          if (monthlyBreakdown != null && monthlyBreakdown.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 18));
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                decoration: pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text('MONTH-BY-MONTH BREAKDOWN SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: primaryColor, letterSpacing: 0.8)),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));

            final sortedBreakdownMonths = monthlyBreakdown.keys.toList()
              ..sort((a, b) {
                try {
                  DateTime da = DateFormat('MMMM yyyy').parse(a);
                  DateTime db = DateFormat('MMMM yyyy').parse(b);
                  return db.compareTo(da);
                } catch (_) {
                  return b.compareTo(a);
                }
              });

            for (var mName in sortedBreakdownMonths) {
              final mList = monthlyBreakdown[mName] ?? [];
              final activePlayersInMonth = mList.where((p) => ((p['total'] ?? 0) as num) > 0).toList()
                ..sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));

              if (activePlayersInMonth.isEmpty) continue;
              final int monthSum = activePlayersInMonth.fold<int>(0, (sum, p) => sum + ((p['total'] ?? 0) as num).toInt());

              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(mName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: primaryColor)),
                      pw.Text('Month Total: $monthSum Balls', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: badgeRedText)),
                    ],
                  ),
                ),
              );

              widgets.add(
                _buildTable(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(28),
                    1: const pw.FlexColumnWidth(),
                    2: const pw.FixedColumnWidth(70),
                  },
                  [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: bgCard),
                      children: [
                        _buildHeaderCell('No.', align: pw.TextAlign.center, textColor: textDark),
                        _buildHeaderCell('Player Name', textColor: textDark),
                        _buildHeaderCell('Balls Lost', align: pw.TextAlign.center, textColor: textDark),
                      ],
                    ),
                    ...activePlayersInMonth.asMap().entries.map((entry) {
                      final p = entry.value;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : bgLight),
                        children: [
                          _buildDataCell('${entry.key + 1}', align: pw.TextAlign.center, fontSize: 8),
                          _buildDataCell(StringUtils.capitalize(p['name']), fontSize: 8, fontWeight: pw.FontWeight.bold),
                          _buildDataCell('${p['total']}', align: pw.TextAlign.center, fontSize: 8, color: badgeRedText, fontWeight: pw.FontWeight.bold),
                        ],
                      );
                    }),
                  ],
                ),
              );
            }
          }

          return widgets;
        },
      ),
    );
  }

  static Future<void> addFineReport(
    pw.Document pdf, {
    required String monthYear,
    required List<Map<String, dynamic>> sortedPlayers,
  }) async {
    if (sortedPlayers.isEmpty) return;
    final logoImage = await _loadClubLogo();

    final int totalBalls = sortedPlayers.fold<int>(0, (sum, p) => sum + ((p['lifetimeBalls'] ?? p['total'] ?? 0) as num).toInt());
    final double totalFine = sortedPlayers.fold<double>(0.0, (sum, p) => sum + ((p['totalFine'] ?? 0.0) as num).toDouble());
    final double totalPaid = sortedPlayers.fold<double>(0.0, (sum, p) => sum + ((p['paid'] ?? 0.0) as num).toDouble());
    final double totalDue = sortedPlayers.fold<double>(0.0, (sum, p) => sum + ((p['due'] ?? 0.0) as num).toDouble());
    final double totalCredit = sortedPlayers.fold<double>(0.0, (sum, p) => sum + ((p['surplus'] ?? 0.0) as num).toDouble());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildPdfHeader(
          'Official Player Fine Status',
          monthYear == 'Overall' ? 'All-Time Cumulative Audit' : 'Statement Period: $monthYear',
          logoImage,
        ),
        footer: (context) => _buildPdfFooter('Fine Record Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildKpiBar([
              {'title': 'Fined Players', 'value': '${sortedPlayers.length} Active', 'color': primaryColor},
              {'title': 'Total Balls', 'value': '$totalBalls Balls', 'color': accentColor},
              {'title': 'Fine Accrued', 'value': '${totalFine.toInt()} BDT', 'color': textDark},
              {'title': 'Total Collected', 'value': '${totalPaid.toInt()} BDT', 'color': badgeGreenText},
              {'title': 'Net Outstanding', 'value': '${totalDue.toInt()} BDT', 'color': badgeRedText},
            ]),
            _buildTable(
              columnWidths: {
                0: const pw.FixedColumnWidth(28), // No.
                1: const pw.FixedColumnWidth(30), // PIC
                2: const pw.FlexColumnWidth(1.6), // Name
                3: const pw.FixedColumnWidth(38), // Balls
                4: const pw.FixedColumnWidth(48), // Fine
                5: const pw.FixedColumnWidth(48), // Paid
                6: const pw.FixedColumnWidth(55), // Due
                7: const pw.FixedColumnWidth(55), // Credit
              },
              [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    _buildHeaderCell('No.', align: pw.TextAlign.center),
                    _buildHeaderCell('Pic', align: pw.TextAlign.center),
                    _buildHeaderCell('Player Name'),
                    _buildHeaderCell('Balls', align: pw.TextAlign.center),
                    _buildHeaderCell('Fine', align: pw.TextAlign.right),
                    _buildHeaderCell('Paid', align: pw.TextAlign.right),
                    _buildHeaderCell('Net Due', align: pw.TextAlign.right),
                    _buildHeaderCell('Credit', align: pw.TextAlign.right),
                  ],
                ),
                ...sortedPlayers.asMap().entries.map((entry) {
                  final p = entry.value;
                  pw.MemoryImage? playerPhoto;
                  try {
                    if (p['photoUrl'] != null && p['photoUrl'] != '') {
                      playerPhoto = pw.MemoryImage(base64Decode(p['photoUrl']));
                    }
                  } catch (_) {}

                  final double due = (p['due'] as num?)?.toDouble() ?? 0.0;
                  final double credit = (p['surplus'] as num?)?.toDouble() ?? 0.0;
                  final ballsLost = p['lifetimeBalls'] ?? p['total'] ?? 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : bgLight),
                    children: [
                      _buildDataCell('${entry.key + 1}', align: pw.TextAlign.center, fontWeight: entry.key < 3 ? pw.FontWeight.bold : pw.FontWeight.normal),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Center(
                          child: pw.Container(
                            height: 18,
                            width: 18,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: PdfColors.grey200,
                              border: pw.Border.all(color: borderLight, width: 0.5),
                              image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null,
                            ),
                            child: playerPhoto == null ? pw.Center(child: pw.Text(p['name'][0].toUpperCase(), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))) : null,
                          ),
                        ),
                      ),
                      _buildDataCell(StringUtils.capitalize(p['name']), fontWeight: pw.FontWeight.bold),
                      _buildDataCell('$ballsLost', align: pw.TextAlign.center),
                      _buildDataCell('${(p['totalFine'] as num).toInt()} BDT', align: pw.TextAlign.right),
                      _buildDataCell('${(p['paid'] as num).toInt()} BDT', align: pw.TextAlign.right, color: badgeGreenText, fontWeight: pw.FontWeight.bold),
                      due > 0
                          ? _buildBadgeCell('${due.toInt()} BDT', bg: badgeRedBg, fg: badgeRedText, align: pw.TextAlign.right)
                          : _buildBadgeCell('0 (CLEAR)', bg: badgeGreenBg, fg: badgeGreenText, align: pw.TextAlign.right),
                      credit > 0
                          ? _buildBadgeCell('${credit.toInt()} BDT', bg: badgeBlueBg, fg: badgeBlueText, align: pw.TextAlign.right)
                          : _buildDataCell('-', align: pw.TextAlign.right, color: textMuted),
                    ],
                  );
                }),
                // Total Summary Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgCard),
                  children: [
                    pw.SizedBox(),
                    pw.SizedBox(),
                    _buildDataCell('GRAND TOTALS', fontWeight: pw.FontWeight.bold, color: primaryColor),
                    _buildDataCell('$totalBalls', align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    _buildDataCell('${totalFine.toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: textDark),
                    _buildDataCell('${totalPaid.toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: badgeGreenText),
                    _buildBadgeCell('${totalDue.toInt()} BDT', bg: badgeRedBg, fg: badgeRedText, align: pw.TextAlign.right),
                    _buildBadgeCell('${totalCredit.toInt()} BDT', bg: badgeBlueBg, fg: badgeBlueText, align: pw.TextAlign.right),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );
  }

  // --- REUSABLE PDF HELPERS ---

  static pw.Widget _buildPdfHeader(String title, String subtitle, pw.MemoryImage? logo, {String? tag}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logo != null)
                    pw.Container(
                      height: 38,
                      width: 38,
                      margin: const pw.EdgeInsets.only(right: 10),
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: borderLight, width: 0.8),
                      ),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SUDDEN PLAN CRICKET CLUB',
                        style: pw.TextStyle(
                          fontSize: 12.5,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'BALL TERMINATOR | OFFICIAL AUDIT & RECORD SYSTEM',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: bgCard,
                  borderRadius: pw.BorderRadius.circular(5),
                  border: pw.Border.all(color: borderLight, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'GENERATED: ${DateFormat('dd MMM yyyy | hh:mm a').format(DateTime.now()).toUpperCase()}',
                      style: pw.TextStyle(fontSize: 6.5, color: textMuted, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      tag ?? 'STATUS: OFFICIAL AUDIT',
                      style: pw.TextStyle(fontSize: 6.5, color: badgeGreenText, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 1,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    subtitle.toUpperCase(),
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(String docType, int pageNum) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        children: [
          pw.Divider(color: borderLight, thickness: 0.8),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Sudden Plan Cricket Team | Ball Terminator Management System',
                style: pw.TextStyle(fontSize: 6.5, color: textMuted),
              ),
              pw.Text(
                docType.toUpperCase(),
                style: pw.TextStyle(fontSize: 6.5, color: textDark, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Page $pageNum',
                style: pw.TextStyle(fontSize: 6.5, color: textMuted, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiBar(List<Map<String, dynamic>> kpis) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        children: kpis.map((kpi) {
          final color = (kpi['color'] as PdfColor?) ?? primaryColor;
          return pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 2.5),
              padding: const pw.EdgeInsets.symmetric(vertical: 5.5, horizontal: 7),
              decoration: pw.BoxDecoration(
                color: bgLight,
                borderRadius: pw.BorderRadius.circular(5),
                border: pw.Border.all(color: borderLight, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    (kpi['title'] as String).toUpperCase(),
                    style: pw.TextStyle(fontSize: 6, color: textMuted, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2.5),
                  pw.Text(
                    kpi['value'] as String,
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildBadgeCell(String text, {required PdfColor bg, required PdfColor fg, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
      child: pw.Align(
        alignment: align == pw.TextAlign.right
            ? pw.Alignment.centerRight
            : (align == pw.TextAlign.left ? pw.Alignment.centerLeft : pw.Alignment.center),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: fg),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      child: pw.Text(
        text.toUpperCase(),
        textAlign: align,
        style: pw.TextStyle(color: textColor ?? PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5, letterSpacing: 0.4),
      ),
    );
  }

  static pw.Widget _buildDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    pw.FontWeight? fontWeight,
    PdfColor? color,
    double fontSize = 8.5,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color ?? textDark),
      ),
    );
  }

  static pw.Widget _buildTable(List<pw.TableRow> rows, {Map<int, pw.TableColumnWidth>? columnWidths}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: borderLight, width: 0.8),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 5,
        verticalRadius: 5,
        child: pw.Table(
          border: _premiumTableBorder(),
          columnWidths: columnWidths,
          children: rows,
        ),
      ),
    );
  }

  static pw.TableBorder _premiumTableBorder() {
    return pw.TableBorder(
      horizontalInside: pw.BorderSide(color: borderLight, width: 0.5),
    );
  }

  static pw.Widget _buildBankRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 110, child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: textMuted))),
          pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textDark)),
        ],
      ),
    );
  }

  static pw.Widget _buildFundSubTable(List<Fund> funds, List<dynamic> players, {required bool isExpense}) {
    final titleColor = isExpense ? badgeRedText : badgeGreenText;
    final headerBg = isExpense ? badgeRedBg : badgeGreenBg;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            isExpense ? 'EXPENSES BREAKDOWN' : 'INCOME BREAKDOWN',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleColor, letterSpacing: 0.8),
          ),
        ),
        _buildTable(
          columnWidths: {
            0: const pw.FixedColumnWidth(55),
            1: const pw.FixedColumnWidth(30),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(65),
          },
          [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerBg),
              children: [
                _buildHeaderCell('Date', textColor: titleColor),
                _buildHeaderCell('Pic', textColor: titleColor, align: pw.TextAlign.center),
                _buildHeaderCell('Name', textColor: titleColor),
                _buildHeaderCell('Source / Note', textColor: titleColor),
                _buildHeaderCell('Amount', align: pw.TextAlign.right, textColor: titleColor),
              ],
            ),
            ...funds.asMap().entries.map((entry) {
              final idx = entry.key;
              final f = entry.value;
              pw.MemoryImage? playerPhoto;
              String playerName = StringUtils.capitalize(f.name);
              if (f.playerId != null) {
                try {
                  final p = players.firstWhere((p) => p.id == f.playerId);
                  if (p.photoUrl != null && p.photoUrl != '') playerPhoto = pw.MemoryImage(base64Decode(p.photoUrl));
                } catch (_) {}
              }
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.white : bgLight),
                children: [
                  _buildDataCell(DateFormat('dd MMM yy').format(f.date)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2.5),
                    child: pw.Center(
                      child: pw.Container(
                        height: 18,
                        width: 18,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.grey200,
                          border: pw.Border.all(color: borderLight, width: 0.5),
                          image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null,
                        ),
                        child: playerPhoto == null ? pw.Center(child: pw.Text(playerName.isNotEmpty ? playerName[0].toUpperCase() : '?', style: pw.TextStyle(fontSize: 7))) : null,
                      ),
                    ),
                  ),
                  _buildDataCell(playerName, fontWeight: pw.FontWeight.bold),
                  _buildDataCell(f.note ?? '-'),
                  _buildDataCell(
                    '${isExpense ? '-' : '+'}${f.amount.toInt()} BDT',
                    align: pw.TextAlign.right,
                    color: isExpense ? badgeRedText : badgeGreenText,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static Future<void> sharePdf(Uint8List bytes, String fileName) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
