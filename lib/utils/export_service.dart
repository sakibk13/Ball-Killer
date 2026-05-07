import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/contribution.dart';
import '../models/fine_payment.dart';
import '../models/fund.dart';
import 'string_utils.dart';
import 'date_utils.dart';

class ExportService {
  static final primaryColor = PdfColor.fromHex('#051970');
  static final accentColor = PdfColor.fromHex('#00BFA5');
  static final bgLight = PdfColor.fromHex('#F8F9FA');
  static final textDark = PdfColor.fromHex('#1C1C1E');
  static final textMuted = PdfColor.fromHex('#6C757D');

  // --- PUBLIC EXPORT METHODS ---

  static Future<void> exportFundReport({required List<Fund> funds, required double grandTotal, required List<dynamic> players}) async {
    final pdf = pw.Document();
    await addFundReport(pdf, funds: funds, grandTotal: grandTotal, players: players);
    await addPaymentInstructionPage(pdf);
    await _saveAndDownload(await pdf.save(), 'club_fund_report.pdf');
  }

  static Future<void> exportPlayerStatusReport({required List<Map<String, dynamic>> players}) async {
    final pdf = pw.Document();
    await addPlayerStatusReport(pdf, players: players);
    await addPaymentInstructionPage(pdf);
    await _saveAndDownload(await pdf.save(), 'master_player_status.pdf');
  }

  static Future<void> exportFinancialSummaryReport({required String monthYear, required Map<String, Map<String, double>> data, required List<dynamic> players}) async {
    final pdf = pw.Document();
    await addFinancialSummaryReport(pdf, monthYear: monthYear, data: data, players: players);
    await addPaymentInstructionPage(pdf);
    await _saveAndDownload(await pdf.save(), 'financial_summary.pdf');
  }

  static Future<void> exportFinancialDetailedReport({required String monthYear, required List<dynamic> contributions, required List<dynamic> players}) async {
    final pdf = pw.Document();
    await addFinancialDetailedReport(pdf, monthYear: monthYear, contributions: contributions, players: players);
    await addPaymentInstructionPage(pdf);
    await _saveAndDownload(await pdf.save(), 'financial_detailed.pdf');
  }

  static Future<void> exportOtherContributionsReport({required String monthYear, required List<Contribution> contributions, required List<dynamic> players}) async {
    final pdf = pw.Document();
    await addOtherContributionsReport(pdf, monthYear: monthYear, contributions: contributions, players: players);
    await addPaymentInstructionPage(pdf);
    await _saveAndDownload(await pdf.save(), 'other_contributions.pdf');
  }

  static Future<void> exportLeaderboard({required String monthYear, required List<Map<String, dynamic>> players}) async {
    final pdf = pw.Document();
    await addLeaderboard(pdf, monthYear: monthYear, players: players);
    await addPaymentInstructionPage(pdf);
    await _saveAndDownload(await pdf.save(), 'leaderboard.pdf');
  }

  static Future<void> exportFineReport({required String monthYear, required List<Map<String, dynamic>> sortedPlayers}) async {
    final pdf = pw.Document();
    await addFineReport(pdf, monthYear: monthYear, sortedPlayers: sortedPlayers);
    await addPaymentInstructionPage(pdf);
    await _saveAndDownload(await pdf.save(), 'fine_report.pdf');
  }

  static Future<void> downloadMultiplePdfs(List<Uint8List> pdfs, List<String> filenames) async {
    final tempDir = await getTemporaryDirectory();
    final List<XFile> xFiles = [];
    for (int i = 0; i < pdfs.length; i++) {
      final file = File('${tempDir.path}/${filenames[i]}');
      await file.writeAsBytes(pdfs[i]);
      xFiles.add(XFile(file.path));
    }
    await Share.shareXFiles(xFiles, text: 'Download club reports');
  }

  // --- PDF BUILDERS ---

  static Future<void> addPaymentInstructionPage(pw.Document pdf) async {
    pw.MemoryImage? bkashImg;
    pw.MemoryImage? bracImg;
    try {
      final ByteData bData = await rootBundle.load('assets/bkash.png');
      bkashImg = pw.MemoryImage(bData.buffer.asUint8List());
      final ByteData brData = await rootBundle.load('assets/brack_bank.jpg');
      bracImg = pw.MemoryImage(brData.buffer.asUint8List());
    } catch (e) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(30),
              decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(15), border: pw.Border.all(color: primaryColor, width: 2)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('OFFICIAL PAYMENT NOTICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 1.2)),
                  pw.SizedBox(height: 10),
                  pw.Container(height: 3, width: 80, color: accentColor),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E0F2F1'), borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: PdfColor.fromHex('#B2DFDB'))),
                    child: pw.Text(
                      'NOTICE: When you come to play, please bring your fine or contribution if you have any outstanding. You can also pay via bKash or Bank Transfer.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00796B'), lineSpacing: 1.5),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text('Dear Members,', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'To ensure the smooth operation of the club and maintain our inventory, we kindly request all members to clear their outstanding fines and contributions. Your support is vital for our growth.',
                    textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, lineSpacing: 1.6, color: textMuted),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (bkashImg != null) 
                        pw.Container(
                          padding: const pw.EdgeInsets.all(15),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200), borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Column(children: [
                            pw.Container(height: 40, width: 80, child: pw.Image(bkashImg, fit: pw.BoxFit.contain)),
                            pw.SizedBox(height: 12),
                            pw.Text('bKash (Personal)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: textDark)),
                            pw.SizedBox(height: 5),
                            pw.Text('01832465446', style: pw.TextStyle(fontSize: 14, color: PdfColor.fromHex('#E91E63'), fontWeight: pw.FontWeight.bold)),
                          ])
                        ),
                      if (bracImg != null) 
                        pw.Container(
                          padding: const pw.EdgeInsets.all(15),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200), borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Column(children: [
                            pw.Container(height: 40, width: 80, child: pw.Image(bracImg, fit: pw.BoxFit.contain)),
                            pw.SizedBox(height: 12),
                            pw.Text('Bank Transfer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: textDark)),
                            pw.SizedBox(height: 5),
                            pw.Text('Details Below', style: pw.TextStyle(fontSize: 9, color: textMuted)),
                          ])
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 45),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(25),
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F3F9'), borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: PdfColors.grey300)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BANK ACCOUNT DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: primaryColor, letterSpacing: 1)),
                        pw.SizedBox(height: 15),
                        _buildBankRow('Account Name', 'SAKIB KHAN'),
                        _buildBankRow('Account Number', '1062020640001'),
                        _buildBankRow('Bank Name', 'BRAC Bank PLC'),
                        _buildBankRow('Routing No.', '060261726'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 35),
                  pw.Text('Thank you for your cooperation.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10, color: textMuted)),
                ],
              ),
            )
          ];
        },
      ),
    );
  }

  static Future<void> addFundReport(pw.Document pdf, {required List<Fund> funds, required double grandTotal, required List<dynamic> players}) async {
    if (funds.isEmpty) return;
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoBytes = await rootBundle.load('assets/icon/logo3.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {}

    Map<String, List<Fund>> monthGroups = {};
    for (var f in funds) {
      String monthKey = DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date));
      monthGroups.putIfAbsent(monthKey, () => []);
      monthGroups[monthKey]!.add(f);
    }
    
    var sortedMonths = monthGroups.keys.toList()..sort((a, b) {
      try {
        DateTime da = DateFormat('MMMM yyyy').parse(a);
        DateTime db = DateFormat('MMMM yyyy').parse(b);
        return db.compareTo(da);
      } catch (_) { return b.compareTo(a); }
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader('Official Fund Report', 'Income & Expense Breakdown', logoImage),
        footer: (context) => _buildPdfFooter('Club Fund Document', context.pageNumber),
        build: (pw.Context context) {
          List<pw.Widget> content = [];
          for (var monthName in sortedMonths) {
            final monthFunds = monthGroups[monthName]!;
            final incomes = monthFunds.where((f) => f.type != 'EXPENSE').toList();
            final expenses = monthFunds.where((f) => f.type == 'EXPENSE').toList();
            final totalInc = incomes.fold(0.0, (sum, f) => sum + f.amount);
            final totalExp = expenses.fold(0.0, (sum, f) => sum + f.amount);

            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 15, bottom: 8),
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(monthName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white)),
                  pw.Text('Net: BDT ${(totalInc - totalExp).toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accentColor)),
                ]),
              )
            );

            if (incomes.isNotEmpty) content.add(_buildFundSubTable(incomes, players, isExpense: false));
            if (expenses.isNotEmpty) content.add(_buildFundSubTable(expenses, players, isExpense: true));
          }
          content.add(pw.SizedBox(height: 15));
          content.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E3F2FD'), borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: primaryColor, width: 0.5)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('GRAND TOTAL CLUB BALANCE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.Text('${grandTotal.toInt()} BDT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            ])
          ));
          return content;
        },
      ),
    );
  }

  static Future<void> addPlayerStatusReport(pw.Document pdf, {required List<Map<String, dynamic>> players}) async {
    if (players.isEmpty) return;
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoBytes = await rootBundle.load('assets/icon/logo3.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader('Master Player Status', 'All Players Cumulative Account Standing', logoImage),
        footer: (context) => _buildPdfFooter('Player Status Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildTable(
              columnWidths: {0: const pw.FixedColumnWidth(25), 1: const pw.FlexColumnWidth(2), 2: const pw.FixedColumnWidth(40), 3: const pw.FixedColumnWidth(50), 4: const pw.FixedColumnWidth(50), 5: const pw.FixedColumnWidth(50), 6: const pw.FixedColumnWidth(50)},
              [
                pw.TableRow(decoration: pw.BoxDecoration(color: primaryColor), children: [
                    _buildHeaderCell('Rank'), _buildHeaderCell('Name'), _buildHeaderCell('Balls'), _buildHeaderCell('Fine'), _buildHeaderCell('Paid'), _buildHeaderCell('Due'), _buildHeaderCell('Credit')
                ]),
                ...players.asMap().entries.map((entry) {
                  final p = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : bgLight),
                    children: [
                      _buildDataCell('${entry.key + 1}', align: pw.TextAlign.center),
                      _buildDataCell(StringUtils.capitalize(p['name']), fontWeight: pw.FontWeight.bold),
                      _buildDataCell('${p['total']}', align: pw.TextAlign.center),
                      _buildDataCell('${(p['totalFine'] as double).toInt()}', align: pw.TextAlign.right),
                      _buildDataCell('${(p['paid'] as double).toInt()}', align: pw.TextAlign.right, color: PdfColor.fromHex('#2E7D32')),
                      _buildDataCell('${(p['due'] as double).toInt()}', align: pw.TextAlign.right, color: (p['due'] as double) > 0 ? PdfColor.fromHex('#C62828') : textDark),
                      _buildDataCell('${(p['surplus'] as double).toInt()}', align: pw.TextAlign.right, color: (p['surplus'] as double) > 0 ? primaryColor : textDark),
                    ]);
                }),
              ],
            ),
          ];
        },
      ),
    );
  }

  static Future<void> addFinancialSummaryReport(pw.Document pdf, {required String monthYear, required Map<String, Map<String, double>> data, required List<dynamic> players}) async {
    if (data.isEmpty) return;
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoBytes = await rootBundle.load('assets/icon/logo3.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader('Aggregated Financial Summary', 'Unified Contributions & Fines', logoImage),
        footer: (context) => _buildPdfFooter('Financial Summary Document', context.pageNumber),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];
          for (var monthKey in data.keys) {
            Map<String, double> playersMap = data[monthKey]!;
            double monthlyTotal = playersMap.values.fold(0, (s, v) => s + v);
            final sortedEntries = playersMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

            widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(top: 15, bottom: 8),
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(monthKey.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white)),
                  pw.Text('Total: BDT ${monthlyTotal.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accentColor)),
                ])
            ));
            
            widgets.add(_buildTable(
              columnWidths: {0: const pw.FixedColumnWidth(40), 1: const pw.FlexColumnWidth(), 2: const pw.FixedColumnWidth(80)},
              [
                pw.TableRow(decoration: pw.BoxDecoration(color: bgLight), children: [_buildHeaderCell('PIC', align: pw.TextAlign.center), _buildHeaderCell('Player Name'), _buildHeaderCell('Total Given', align: pw.TextAlign.right)]),
                ...sortedEntries.map((e) {
                   pw.MemoryImage? playerPhoto;
                   try {
                      final p = players.firstWhere((p) => StringUtils.capitalize(p.name) == e.key);
                      if (p.photoUrl != null && p.photoUrl != '') playerPhoto = pw.MemoryImage(base64Decode(p.photoUrl));
                   } catch (err) {}
                   return pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Container(
                      height: 12, width: 12, decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey200, image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null),
                      child: playerPhoto == null ? pw.Center(child: pw.Text(e.key[0].toUpperCase(), style: const pw.TextStyle(fontSize: 5))) : null,
                    ))),
                    _buildDataCell(e.key, fontWeight: pw.FontWeight.bold),
                    _buildDataCell('${e.value.toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2E7D32')),
                  ]);
                }),
              ]
            ));
          }
          return widgets;
        },
      ),
    );
  }

  static Future<void> addFinancialDetailedReport(pw.Document pdf, {required String monthYear, required List<dynamic> contributions, required List<dynamic> players}) async {
    if (contributions.isEmpty) return;
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoBytes = await rootBundle.load('assets/icon/logo3.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader('Detailed Transaction List', 'Unified Contribution History', logoImage),
        footer: (context) => _buildPdfFooter('Transaction Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildTable(
              columnWidths: {0: const pw.FixedColumnWidth(55), 1: const pw.FlexColumnWidth(1.2), 2: const pw.FlexColumnWidth(2), 3: const pw.FixedColumnWidth(60)},
              [
                pw.TableRow(decoration: pw.BoxDecoration(color: primaryColor), children: [_buildHeaderCell('Date'), _buildHeaderCell('Name'), _buildHeaderCell('Description/Note'), _buildHeaderCell('Amount', align: pw.TextAlign.right)]),
                ...contributions.map((item) {
                  bool isFine = item is FinePayment;
                  String name = StringUtils.capitalize(isFine ? item.playerName : (item as Contribution).name);
                  String note = isFine ? (item.note ?? "Fine Payment") : (item as Contribution).ballTape;
                  double amount = isFine ? item.amountPaid : (item as Contribution).taka;
                  return pw.TableRow(children: [
                    _buildDataCell(DateFormat('dd MMM yy').format(isFine ? item.date : (item as Contribution).date)),
                    _buildDataCell(name, fontWeight: pw.FontWeight.bold),
                    _buildDataCell(note),
                    _buildDataCell('${amount.toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: isFine ? PdfColor.fromHex('#2E7D32') : null),
                  ]);
                }),
              ],
            ),
          ];
        },
      ),
    );
  }

  static Future<void> addOtherContributionsReport(pw.Document pdf, {required String monthYear, required List<Contribution> contributions, required List<dynamic> players}) async {
    if (contributions.isEmpty) return;
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoBytes = await rootBundle.load('assets/icon/logo3.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader('Non-Cash Contributions', 'Balls, Tape & Equipment Items', logoImage),
        footer: (context) => _buildPdfFooter('Other Contributions Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildTable(
              columnWidths: {0: const pw.FixedColumnWidth(55), 1: const pw.FlexColumnWidth(1.2), 2: const pw.FlexColumnWidth(2), 3: const pw.FixedColumnWidth(60)},
              [
                pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('#00796B')), children: [_buildHeaderCell('Date'), _buildHeaderCell('Contributor'), _buildHeaderCell('Item Detail'), _buildHeaderCell('Est. Value', align: pw.TextAlign.right)]),
                ...contributions.map((c) => pw.TableRow(children: [
                    _buildDataCell(DateFormat('dd MMM yy').format(c.date)),
                    _buildDataCell(StringUtils.capitalize(c.name), fontWeight: pw.FontWeight.bold),
                    _buildDataCell(c.ballTape),
                    _buildDataCell(c.taka > 0 ? '${c.taka.toInt()} BDT' : '-', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00796B')),
                  ])),
                pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E0F2F1')), children: [
                    pw.SizedBox(), _buildDataCell('TOTAL SUMMARY', fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00796B')),
                    _buildDataCell('${contributions.fold(0, (sum, c) => sum + c.ballCount)} Balls, ${contributions.fold(0, (sum, c) => sum + c.tapeCount)} Tapes', fontWeight: pw.FontWeight.bold, fontSize: 8),
                    _buildDataCell('${contributions.fold(0.0, (sum, c) => sum + c.taka).toInt()} BDT', align: pw.TextAlign.right, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00796B')),
                  ]),
              ],
            ),
          ];
        },
      ),
    );
  }

  static Future<void> addLeaderboard(pw.Document pdf, {required String monthYear, required List<Map<String, dynamic>> players}) async {
    if (players.isEmpty) return;
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoBytes = await rootBundle.load('assets/icon/logo3.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {}

    final sorted = List<Map<String, dynamic>>.from(players)..sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader('Club Leaderboard', 'Performance Rankings: $monthYear', logoImage),
        footer: (context) => _buildPdfFooter('Leaderboard Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildTable(
              columnWidths: {0: const pw.FixedColumnWidth(40), 1: const pw.FixedColumnWidth(40), 2: const pw.FlexColumnWidth(), 3: const pw.FixedColumnWidth(80)},
              [
                pw.TableRow(decoration: pw.BoxDecoration(color: primaryColor), children: [_buildHeaderCell('Rank', align: pw.TextAlign.center), _buildHeaderCell('PIC', align: pw.TextAlign.center), _buildHeaderCell('Player Name'), _buildHeaderCell('Balls Lost', align: pw.TextAlign.center)]),
                ...sorted.asMap().entries.map((entry) {
                  final p = entry.value;
                  pw.MemoryImage? playerPhoto;
                   try {
                      if (p['photoUrl'] != null && p['photoUrl'] != '') playerPhoto = pw.MemoryImage(base64Decode(p['photoUrl']));
                   } catch (err) {}

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : bgLight),
                    children: [
                      _buildDataCell('${entry.key + 1}', align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Container(
                        height: 12, width: 12, decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey200, image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null),
                        child: playerPhoto == null ? pw.Center(child: pw.Text(p['name'][0].toUpperCase(), style: const pw.TextStyle(fontSize: 5))) : null,
                      ))),
                      _buildDataCell(StringUtils.capitalize(p['name']), fontWeight: pw.FontWeight.bold),
                      _buildDataCell('${p['total']}', align: pw.TextAlign.center, color: entry.key < 3 ? PdfColor.fromHex('#C62828') : textDark, fontWeight: pw.FontWeight.bold),
                    ]);
                }),
              ],
            ),
          ];
        },
      ),
    );
  }

  static Future<void> addFineReport(pw.Document pdf, {required String monthYear, required List<Map<String, dynamic>> sortedPlayers}) async {
    if (sortedPlayers.isEmpty) return;
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoBytes = await rootBundle.load('assets/icon/logo3.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildPdfHeader('Official Player Fine Status', 'Cumulative Financial Account Standing', logoImage),
        footer: (context) => _buildPdfFooter('Fine Record Document', context.pageNumber),
        build: (pw.Context context) {
          return [
            _buildTable(
              columnWidths: {0: const pw.FixedColumnWidth(25), 1: const pw.FixedColumnWidth(30), 2: const pw.FlexColumnWidth(2), 3: const pw.FixedColumnWidth(40), 4: const pw.FixedColumnWidth(50), 5: const pw.FixedColumnWidth(50), 6: const pw.FixedColumnWidth(50), 7: const pw.FixedColumnWidth(50)},
              [
                pw.TableRow(decoration: pw.BoxDecoration(color: primaryColor), children: [
                    _buildHeaderCell('No.'), _buildHeaderCell('PIC'), _buildHeaderCell('Player Name'), _buildHeaderCell('Balls'), _buildHeaderCell('Fine'), _buildHeaderCell('Paid'), _buildHeaderCell('Due'), _buildHeaderCell('Credit')
                ]),
                ...sortedPlayers.asMap().entries.map((entry) {
                  final p = entry.value;
                  pw.MemoryImage? playerPhoto;
                   try {
                      if (p['photoUrl'] != null && p['photoUrl'] != '') playerPhoto = pw.MemoryImage(base64Decode(p['photoUrl']));
                   } catch (err) {}

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : bgLight),
                    children: [
                      _buildDataCell('${entry.key + 1}', align: pw.TextAlign.center),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Container(
                        height: 12, width: 12, decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey200, image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null),
                        child: playerPhoto == null ? pw.Center(child: pw.Text(p['name'][0].toUpperCase(), style: const pw.TextStyle(fontSize: 5))) : null,
                      ))),
                      _buildDataCell(StringUtils.capitalize(p['name']), fontWeight: pw.FontWeight.bold),
                      _buildDataCell('${p['lifetimeBalls'] ?? p['total']}', align: pw.TextAlign.center),
                      _buildDataCell('${(p['totalFine'] as double).toInt()}', align: pw.TextAlign.right),
                      _buildDataCell('${(p['paid'] as double).toInt()}', align: pw.TextAlign.right, color: PdfColor.fromHex('#2E7D32')),
                      _buildDataCell('${(p['due'] as double).toInt()}', align: pw.TextAlign.right, color: (p['due'] as double) > 0 ? PdfColor.fromHex('#C62828') : textDark),
                      _buildDataCell('${(p['surplus'] as double).toInt()}', align: pw.TextAlign.right, color: (p['surplus'] as double) > 0 ? primaryColor : textDark),
                    ]);
                }),
              ],
            ),
          ];
        },
      ),
    );
  }

  // --- HELPERS ---

  static pw.Widget _buildPdfHeader(String title, String subtitle, pw.MemoryImage? logo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Row(children: [
                if (logo != null) pw.Container(height: 35, width: 35, margin: const pw.EdgeInsets.only(right: 12), child: pw.Image(logo, fit: pw.BoxFit.contain)),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('BALL KILLER MINI CRICKET', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.8)),
                    pw.Text('$title | $subtitle', style: pw.TextStyle(fontSize: 9, color: textDark, fontWeight: pw.FontWeight.bold)),
                ]),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Export Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                  pw.Text('OFFICIAL DOCUMENT', style: pw.TextStyle(fontSize: 6, color: accentColor, fontWeight: pw.FontWeight.bold)),
              ]),
            ]),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.5, color: primaryColor),
        ])
    );
  }

  static pw.Widget _buildPdfFooter(String docType, int pageNum) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(children: [
          pw.Divider(color: primaryColor, thickness: 0.5),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(docType, style: pw.TextStyle(fontSize: 7, color: textMuted, fontWeight: pw.FontWeight.bold)),
              pw.Text('Page $pageNum', style: pw.TextStyle(fontSize: 7, color: textMuted, fontWeight: pw.FontWeight.bold)),
            ]),
        ])
    );
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4), 
      child: pw.Text(text.toUpperCase(), textAlign: align, style: pw.TextStyle(color: textColor ?? PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8))
    );
  }

  static pw.Widget _buildDataCell(String text, {pw.TextAlign align = pw.TextAlign.left, pw.FontWeight? fontWeight, PdfColor? color, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6), 
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color ?? textDark))
    );
  }

  static pw.Widget _buildTable(List<pw.TableRow> rows, {Map<int, pw.TableColumnWidth>? columnWidths}) {
    return pw.Table(
      border: _premiumTableBorder(),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  static pw.TableBorder _premiumTableBorder() {
    return pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      bottom: pw.BorderSide(color: primaryColor, width: 1.0),
    );
  }

  static pw.Widget _buildBankRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: textMuted))),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
        ],
      ),
    );
  }

  static pw.Widget _buildFundSubTable(List<Fund> funds, List<dynamic> players, {required bool isExpense}) {
    final titleColor = isExpense ? PdfColor.fromHex('#B71C1C') : PdfColor.fromHex('#1B5E20');
    final headerBg = isExpense ? PdfColor.fromHex('#FFCDD2') : PdfColor.fromHex('#C8E6C9');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 15, bottom: 5),
          child: pw.Text(isExpense ? 'EXPENSES' : 'INCOME', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleColor, letterSpacing: 1)),
        ),
        _buildTable(
          columnWidths: {0: const pw.FixedColumnWidth(60), 1: const pw.FixedColumnWidth(40), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(2), 4: const pw.FixedColumnWidth(70)},
          [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerBg), 
              children: [
                _buildHeaderCell('Date', textColor: titleColor), 
                _buildHeaderCell('PIC', textColor: titleColor, align: pw.TextAlign.center), 
                _buildHeaderCell('Name', textColor: titleColor), 
                _buildHeaderCell('Source/Note', textColor: titleColor), 
                _buildHeaderCell('Amount', align: pw.TextAlign.right, textColor: titleColor)
              ]
            ),
            ...funds.map((f) {
              pw.MemoryImage? playerPhoto;
              String playerName = StringUtils.capitalize(f.name);
              if (f.playerId != null) {
                try {
                  final p = players.firstWhere((p) => p.id == f.playerId);
                  if (p.photoUrl != null && p.photoUrl != '') playerPhoto = pw.MemoryImage(base64Decode(p.photoUrl));
                } catch (e) {}
              }
              return pw.TableRow(children: [
                _buildDataCell(DateFormat('dd MMM yy').format(f.date)),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Container(
                  height: 22, width: 22, decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey200, border: pw.Border.all(color: PdfColors.grey400, width: 0.5), image: playerPhoto != null ? pw.DecorationImage(image: playerPhoto, fit: pw.BoxFit.cover) : null),
                  child: playerPhoto == null ? pw.Center(child: pw.Text(playerName.isNotEmpty ? playerName[0].toUpperCase() : '?', style: const pw.TextStyle(fontSize: 8))) : null,
                ))),
                _buildDataCell(playerName, fontWeight: pw.FontWeight.bold),
                _buildDataCell(f.note ?? '-'),
                _buildDataCell('${isExpense ? '-' : '+'}${f.amount.toInt()} BDT', align: pw.TextAlign.right, color: isExpense ? PdfColor.fromHex('#C62828') : PdfColor.fromHex('#2E7D32'), fontWeight: pw.FontWeight.bold),
              ]);
            }),
          ]
        ),
      ]
    );
  }

  static Future<void> _saveAndDownload(Uint8List bytes, String fileName) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
