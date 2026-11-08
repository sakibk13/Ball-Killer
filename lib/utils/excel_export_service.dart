import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ball_record.dart';
import '../models/unintentional_record.dart';
import '../models/player.dart';
import '../models/fine_payment.dart';
import '../models/contribution.dart';
import '../models/fund.dart';
import '../models/inventory.dart';
import 'date_utils.dart';

class ExcelExportService {
  /// Generates a comprehensive multi-sheet Excel file (.xlsx)
  /// Scope can be:
  /// - 'Overall' (All-time full app data)
  /// - 'Year: 2026' (All data for a given year)
  /// - 'Month: November 2026' (Data for a specific month)
  static Future<void> exportComprehensiveExcel({
    required String scopeTitle,
    required List<BallRecord> playerRecords,
    required List<UnintentionalRecord> unintentionalRecords,
    required List<Player> players,
    required List<FinePayment> finePayments,
    required List<Contribution> contributions,
    required List<Fund> funds,
    required List<Inventory> inventoryList,
    required String exportedBy,
  }) async {
    final excel = Excel.createExcel();

    // 1. FILTER DATA ACCORDING TO SCOPE
    final filteredPlayerRecords = _filterByScope(playerRecords, scopeTitle, (r) => r.date, (r) => r.monthYear);
    final filteredUnintRecords = _filterByScope(unintentionalRecords, scopeTitle, (r) => r.date, (r) => r.monthYear);
    final filteredFinePayments = _filterByScope(finePayments, scopeTitle, (r) => r.date, (r) => r.monthYear);
    final filteredContribs = _filterByScope(contributions, scopeTitle, (r) => r.date, (r) => r.monthYear);
    final filteredFunds = _filterByScope(funds, scopeTitle, (r) => r.date, (r) => DateFormat('MMMM yyyy').format(r.date));
    final filteredInventory = _filterByScope(inventoryList, scopeTitle, (r) => r.date, (r) => r.monthYear);

    // 2. BUILD SHEETS (SUB-SECTIONS)
    _buildOverviewSheet(
      excel,
      scopeTitle: scopeTitle,
      exportedBy: exportedBy,
      playerRecords: filteredPlayerRecords,
      unintRecords: filteredUnintRecords,
      players: players,
      finePayments: filteredFinePayments,
      contributions: filteredContribs,
      funds: filteredFunds,
      inventoryList: filteredInventory,
    );

    _buildMonthlySummarySheet(
      excel,
      allPlayerRecords: playerRecords,
      allUnintRecords: unintentionalRecords,
      allFinePayments: finePayments,
      allContribs: contributions,
      allFunds: funds,
    );

    _buildPlayerBallLossSheet(excel, filteredPlayerRecords);
    _buildUnintentionalLossSheet(excel, filteredUnintRecords);
    _buildDailyLossComparisonSheet(excel, filteredPlayerRecords, filteredUnintRecords);
    _buildFinesAndDuesSheet(excel, players, filteredPlayerRecords, filteredFinePayments, filteredContribs, scopeTitle);
    _buildFinePaymentsSheet(excel, filteredFinePayments);
    _buildContributionsSheet(excel, filteredContribs);
    _buildTreasuryFundsSheet(excel, filteredFunds);
    _buildInventoryStockSheet(excel, filteredInventory);
    _buildPlayersRosterSheet(excel, players);

    // Set first sheet as default & clean up default 'Sheet1'
    excel.setDefaultSheet('OVERVIEW_SUMMARY');
    try {
      excel.delete('Sheet1');
    } catch (_) {}

    // 3. SAVE AND SHARE EXCEL FILE
    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) {
      throw 'Failed to encode Excel file.';
    }

    final String safeScope = scopeTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String filename = 'Ball_Terminator_${safeScope}_$timestamp.xlsx';

    await _shareExcelFile(bytes, filename);
  }

  // --- FILTERING HELPER ---
  static List<T> _filterByScope<T>(
    List<T> list,
    String scope,
    DateTime Function(T) dateGetter,
    String Function(T) monthYearGetter,
  ) {
    if (scope == 'Overall' || scope.toLowerCase().contains('all time')) {
      return list;
    }

    if (scope.startsWith('Year:')) {
      final yearStr = scope.replaceAll('Year:', '').trim();
      final targetYear = int.tryParse(yearStr);
      if (targetYear != null) {
        return list.where((item) => dateGetter(item).year == targetYear).toList();
      }
    }

    // Month scope (e.g. "November 2026")
    final cleanMonth = DateUtilsHelper.normalizeMonthYear(scope.replaceAll('Month:', '').trim());
    return list.where((item) {
      final itemMonth = DateUtilsHelper.normalizeMonthYear(monthYearGetter(item));
      return itemMonth == cleanMonth;
    }).toList();
  }

  // --- SHEET 1: OVERVIEW SUMMARY ---
  static void _buildOverviewSheet(
    Excel excel, {
    required String scopeTitle,
    required String exportedBy,
    required List<BallRecord> playerRecords,
    required List<UnintentionalRecord> unintRecords,
    required List<Player> players,
    required List<FinePayment> finePayments,
    required List<Contribution> contributions,
    required List<Fund> funds,
    required List<Inventory> inventoryList,
  }) {
    final sheet = excel['OVERVIEW_SUMMARY'];

    sheet.appendRow([TextCellValue('BALL TERMINATOR - CLUB MANAGEMENT SYSTEM')]);
    sheet.appendRow([TextCellValue('EXECUTIVE DATA SUMMARY REPORT')]);
    sheet.appendRow([TextCellValue('Scope / Period:'), TextCellValue(scopeTitle)]);
    sheet.appendRow([TextCellValue('Generated At:'), TextCellValue(DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now()))]);
    sheet.appendRow([TextCellValue('Generated By:'), TextCellValue(exportedBy)]);
    sheet.appendRow([TextCellValue('')]); // Blank line

    // Calculate metrics
    final int totalPlayerLost = playerRecords.fold(0, (sum, r) => sum + r.lostCount);
    final int totalUnintLost = unintRecords.fold(0, (sum, r) => sum + r.lostCount);
    final int grandTotalLost = totalPlayerLost + totalUnintLost;

    final double totalFinesIncurred = totalPlayerLost * 50.0;
    final double totalDirectFinePaid = finePayments.fold(0.0, (sum, p) => sum + p.amountPaid);
    final double totalContribFinePaid = contributions.where((c) => !c.isOther).fold(0.0, (sum, c) => sum + c.taka);
    final double totalFinesCollected = totalDirectFinePaid + totalContribFinePaid;
    final double netFineDues = (totalFinesIncurred > totalFinesCollected) ? (totalFinesIncurred - totalFinesCollected) : 0.0;

    final double totalFundIncome = funds.where((f) => f.type == 'INCOME').fold(0.0, (sum, f) => sum + f.amount);
    final double totalFundExpense = funds.where((f) => f.type == 'EXPENSE').fold(0.0, (sum, f) => sum + f.amount);
    final double netTreasuryBalance = totalFundIncome - totalFundExpense;

    final double totalAllContribs = contributions.fold(0.0, (sum, c) => sum + c.taka);

    final int ballsBought = inventoryList.fold(0, (sum, item) => sum + item.ballsBrought);
    final int ballsReturned = inventoryList.fold(0, (sum, item) => sum + item.ballsReturned);
    final int ballsLostInInventory = inventoryList.fold(0, (sum, item) => sum + item.totalLost);
    final int netInventoryStock = ballsBought + ballsReturned - ballsLostInInventory;

    sheet.appendRow([TextCellValue('--- KEY PERFORMANCE INDICATORS (KPIS) ---')]);
    sheet.appendRow([TextCellValue('Metric Description'), TextCellValue('Value'), TextCellValue('Unit / Notes')]);
    sheet.appendRow([TextCellValue('Player Lost Balls'), IntCellValue(totalPlayerLost), TextCellValue('Balls (Responsibility of Players)')]);
    sheet.appendRow([TextCellValue('Unintentional Lost Balls'), IntCellValue(totalUnintLost), TextCellValue('Balls (Ground / Accidental Loss)')]);
    sheet.appendRow([TextCellValue('Grand Total Lost Balls'), IntCellValue(grandTotalLost), TextCellValue('Combined Lost Balls')]);
    sheet.appendRow([TextCellValue('Total Fines Incurred'), DoubleCellValue(totalFinesIncurred), TextCellValue('৳ (At 50 ৳ per player ball lost)')]);
    sheet.appendRow([TextCellValue('Total Fines Collected'), DoubleCellValue(totalFinesCollected), TextCellValue('৳ (Paid directly + match contributions)')]);
    sheet.appendRow([TextCellValue('Total Outstanding Fine Dues'), DoubleCellValue(netFineDues), TextCellValue('৳ (Unpaid fine debt)')]);
    sheet.appendRow([TextCellValue('Total Club Contributions'), DoubleCellValue(totalAllContribs), TextCellValue('৳ (All player contributions combined)')]);
    sheet.appendRow([TextCellValue('Treasury Total Income'), DoubleCellValue(totalFundIncome), TextCellValue('৳ (Club fund deposits)')]);
    sheet.appendRow([TextCellValue('Treasury Total Expenses'), DoubleCellValue(totalFundExpense), TextCellValue('৳ (Club fund expenditures)')]);
    sheet.appendRow([TextCellValue('Net Treasury Balance'), DoubleCellValue(netTreasuryBalance), TextCellValue('৳ (Current cash in hand)')]);
    sheet.appendRow([TextCellValue('Calculated Stock Remaining'), IntCellValue(netInventoryStock), TextCellValue('Balls in inventory')]);
    sheet.appendRow([TextCellValue('Total Registered Players'), IntCellValue(players.length), TextCellValue('Active roster members')]);
  }

  // --- SHEET 2: MONTHLY SUMMARY (FULL APP CHRONOLOGY) ---
  static void _buildMonthlySummarySheet(
    Excel excel, {
    required List<BallRecord> allPlayerRecords,
    required List<UnintentionalRecord> allUnintRecords,
    required List<FinePayment> allFinePayments,
    required List<Contribution> allContribs,
    required List<Fund> allFunds,
  }) {
    final sheet = excel['MONTHLY_SUMMARY'];

    // Discover all unique month-years across all datasets
    final Set<String> months = {};
    for (var r in allPlayerRecords) {
      if (r.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
      }
    }
    for (var r in allUnintRecords) {
      if (r.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
      }
    }
    for (var p in allFinePayments) {
      if (p.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(p.monthYear));
      }
    }
    for (var c in allContribs) {
      if (c.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(c.monthYear));
      }
    }
    for (var f in allFunds) {
      months.add(DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date)));
    }

    months.remove('Overall');
    final sortedMonths = months.toList();
    sortedMonths.sort((a, b) {
      try {
        final da = DateFormat('MMMM yyyy').parse(a);
        final db = DateFormat('MMMM yyyy').parse(b);
        return da.compareTo(db); // Chronological ascending
      } catch (_) {
        return a.compareTo(b);
      }
    });

    sheet.appendRow([TextCellValue('BALL TERMINATOR - MONTH-BY-MONTH COMPREHENSIVE FINANCIAL & LOSS SUMMARY')]);
    sheet.appendRow([
      TextCellValue('Month & Year'),
      TextCellValue('Player Lost (Balls)'),
      TextCellValue('Unintentional (Balls)'),
      TextCellValue('Total Lost (Balls)'),
      TextCellValue('Fine Owed (৳)'),
      TextCellValue('Fines Paid (৳)'),
      TextCellValue('Contributions (৳)'),
      TextCellValue('Treasury Income (৳)'),
      TextCellValue('Treasury Expense (৳)'),
      TextCellValue('Net Monthly Treasury (৳)'),
    ]);

    int grandPlayerLost = 0;
    int grandUnintLost = 0;
    int grandTotalLost = 0;
    double grandFineOwed = 0;
    double grandFinePaid = 0;
    double grandContribs = 0;
    double grandIncome = 0;
    double grandExpense = 0;

    for (var m in sortedMonths) {
      final pLost = allPlayerRecords.where((r) => DateUtilsHelper.normalizeMonthYear(r.monthYear) == m).fold(0, (s, r) => s + r.lostCount);
      final uLost = allUnintRecords.where((r) => DateUtilsHelper.normalizeMonthYear(r.monthYear) == m).fold(0, (s, r) => s + r.lostCount);
      final totLost = pLost + uLost;
      final fineOwed = pLost * 50.0;

      final finePaid = allFinePayments.where((p) => DateUtilsHelper.normalizeMonthYear(p.monthYear) == m).fold(0.0, (s, p) => s + p.amountPaid);
      final contribs = allContribs.where((c) => DateUtilsHelper.normalizeMonthYear(c.monthYear) == m).fold(0.0, (s, c) => s + c.taka);

      final inc = allFunds.where((f) => DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date)) == m && f.type == 'INCOME').fold(0.0, (s, f) => s + f.amount);
      final exp = allFunds.where((f) => DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date)) == m && f.type == 'EXPENSE').fold(0.0, (s, f) => s + f.amount);
      final netFund = inc - exp;

      grandPlayerLost += pLost;
      grandUnintLost += uLost;
      grandTotalLost += totLost;
      grandFineOwed += fineOwed;
      grandFinePaid += finePaid;
      grandContribs += contribs;
      grandIncome += inc;
      grandExpense += exp;

      sheet.appendRow([
        TextCellValue(m),
        IntCellValue(pLost),
        IntCellValue(uLost),
        IntCellValue(totLost),
        DoubleCellValue(fineOwed),
        DoubleCellValue(finePaid),
        DoubleCellValue(contribs),
        DoubleCellValue(inc),
        DoubleCellValue(exp),
        DoubleCellValue(netFund),
      ]);
    }

    // OVERALL TOTAL ROW
    sheet.appendRow([
      TextCellValue('OVERALL TOTAL'),
      IntCellValue(grandPlayerLost),
      IntCellValue(grandUnintLost),
      IntCellValue(grandTotalLost),
      DoubleCellValue(grandFineOwed),
      DoubleCellValue(grandFinePaid),
      DoubleCellValue(grandContribs),
      DoubleCellValue(grandIncome),
      DoubleCellValue(grandExpense),
      DoubleCellValue(grandIncome - grandExpense),
    ]);
  }

  // --- SHEET 3: PLAYER BALL LOSS ---
  static void _buildPlayerBallLossSheet(Excel excel, List<BallRecord> records) {
    final sheet = excel['PLAYER_BALL_LOSS'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Player Name'),
      TextCellValue('Balls Lost'),
      TextCellValue('Month & Year'),
      TextCellValue('Recorded By'),
      TextCellValue('Note / Reason'),
    ]);

    final sorted = List<BallRecord>.from(records)..sort((a, b) => b.date.compareTo(a.date));
    int total = 0;

    for (var r in sorted) {
      total += r.lostCount;
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(r.date)),
        TextCellValue(r.playerName),
        IntCellValue(r.lostCount),
        TextCellValue(r.monthYear),
        TextCellValue(r.recordedBy),
        TextCellValue(r.note),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      IntCellValue(total),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
  }

  // --- SHEET 4: UNINTENTIONAL LOSS ---
  static void _buildUnintentionalLossSheet(Excel excel, List<UnintentionalRecord> records) {
    final sheet = excel['UNINTENTIONAL_LOSS'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Unintentional Lost (Balls)'),
      TextCellValue('Month & Year'),
      TextCellValue('Reason / Description'),
      TextCellValue('Recorded By'),
    ]);

    final sorted = List<UnintentionalRecord>.from(records)..sort((a, b) => b.date.compareTo(a.date));
    int total = 0;

    for (var r in sorted) {
      total += r.lostCount;
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(r.date)),
        IntCellValue(r.lostCount),
        TextCellValue(r.monthYear),
        TextCellValue(r.note.isNotEmpty ? r.note : 'Ground Loss / Accidental'),
        TextCellValue(r.recordedBy),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL'),
      IntCellValue(total),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
  }

  // --- SHEET 5: DAILY LOSS COMPARISON ---
  static void _buildDailyLossComparisonSheet(
    Excel excel,
    List<BallRecord> playerRecords,
    List<UnintentionalRecord> unintRecords,
  ) {
    final sheet = excel['DAILY_LOSS_COMPARISON'];
    sheet.appendRow([
      TextCellValue('Date (YYYY-MM-DD)'),
      TextCellValue('Day of Week'),
      TextCellValue('Player Lost Subtotal'),
      TextCellValue('Unintentional Subtotal'),
      TextCellValue('Combined Daily Total'),
      TextCellValue('% Player Lost'),
      TextCellValue('% Unintentional'),
    ]);

    // Group player losses by date
    final Map<String, int> playerDaily = {};
    for (var r in playerRecords) {
      final key = DateFormat('yyyy-MM-dd').format(r.date);
      playerDaily[key] = (playerDaily[key] ?? 0) + r.lostCount;
    }

    // Group unintentional losses by date
    final Map<String, int> unintDaily = {};
    for (var r in unintRecords) {
      final key = DateFormat('yyyy-MM-dd').format(r.date);
      unintDaily[key] = (unintDaily[key] ?? 0) + r.lostCount;
    }

    final Set<String> allDates = {...playerDaily.keys, ...unintDaily.keys};
    final sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));

    int sumPlayer = 0;
    int sumUnint = 0;
    int sumCombined = 0;

    for (var d in sortedDates) {
      final dateObj = DateTime.parse(d);
      final pCount = playerDaily[d] ?? 0;
      final uCount = unintDaily[d] ?? 0;
      final dayTotal = pCount + uCount;

      sumPlayer += pCount;
      sumUnint += uCount;
      sumCombined += dayTotal;

      final double pRatio = dayTotal > 0 ? (pCount / dayTotal) * 100 : 0.0;
      final double uRatio = dayTotal > 0 ? (uCount / dayTotal) * 100 : 0.0;

      sheet.appendRow([
        TextCellValue(d),
        TextCellValue(DateFormat('EEEE').format(dateObj)),
        IntCellValue(pCount),
        IntCellValue(uCount),
        IntCellValue(dayTotal),
        TextCellValue('${pRatio.toStringAsFixed(1)}%'),
        TextCellValue('${uRatio.toStringAsFixed(1)}%'),
      ]);
    }

    sheet.appendRow([
      TextCellValue('SUBTOTAL / TOTAL'),
      TextCellValue(''),
      IntCellValue(sumPlayer),
      IntCellValue(sumUnint),
      IntCellValue(sumCombined),
      TextCellValue(sumCombined > 0 ? '${((sumPlayer / sumCombined) * 100).toStringAsFixed(1)}%' : '0%'),
      TextCellValue(sumCombined > 0 ? '${((sumUnint / sumCombined) * 100).toStringAsFixed(1)}%' : '0%'),
    ]);
  }

  // --- SHEET 6: FINES AND DUES STATUS ---
  static void _buildFinesAndDuesSheet(
    Excel excel,
    List<Player> players,
    List<BallRecord> playerRecords,
    List<FinePayment> finePayments,
    List<Contribution> contributions,
    String scopeTitle,
  ) {
    final sheet = excel['FINES_AND_DUES'];
    sheet.appendRow([
      TextCellValue('Player Name'),
      TextCellValue('Phone Number'),
      TextCellValue('Lost Balls Count'),
      TextCellValue('Total Fine Owed (৳)'),
      TextCellValue('Direct Fine Paid (৳)'),
      TextCellValue('Match Contrib Paid (৳)'),
      TextCellValue('Total Money Paid (৳)'),
      TextCellValue('Pending Due (৳)'),
      TextCellValue('Surplus Credit (৳)'),
      TextCellValue('Status'),
    ]);

    double grandFineOwed = 0;
    double grandDirectPaid = 0;
    double grandContribPaid = 0;
    double grandTotalPaid = 0;
    double grandDue = 0;
    double grandSurplus = 0;

    for (var p in players) {
      final pId = p.id ?? '';
      // Count balls lost in this scope
      final int lostCount = playerRecords.where((r) =>
        (r.playerId.isNotEmpty && r.playerId == pId) ||
        r.playerName.toLowerCase() == p.name.toLowerCase()
      ).fold(0, (sum, r) => sum + r.lostCount);

      // Fine calculations
      final double fineOwed = lostCount * 50.0;
      final double directPaid = finePayments.where((pay) => pay.playerId == pId).fold(0.0, (s, pay) => s + pay.amountPaid);
      final double contribPaid = contributions.where((c) => c.playerId == pId && !c.isOther).fold(0.0, (s, c) => s + c.taka);
      final double totalPaid = directPaid + contribPaid;

      double due = 0;
      double surplus = 0;
      String status = 'CLEARED';

      if (totalPaid >= fineOwed) {
        surplus = totalPaid - fineOwed;
        status = surplus > 0 ? 'ADVANCE CREDIT' : 'CLEARED';
      } else {
        due = fineOwed - totalPaid;
        status = 'PENDING DUE';
      }

      grandFineOwed += fineOwed;
      grandDirectPaid += directPaid;
      grandContribPaid += contribPaid;
      grandTotalPaid += totalPaid;
      grandDue += due;
      grandSurplus += surplus;

      sheet.appendRow([
        TextCellValue(p.name),
        TextCellValue(p.phone),
        IntCellValue(lostCount),
        DoubleCellValue(fineOwed),
        DoubleCellValue(directPaid),
        DoubleCellValue(contribPaid),
        DoubleCellValue(totalPaid),
        DoubleCellValue(due),
        DoubleCellValue(surplus),
        TextCellValue(status),
      ]);
    }

    sheet.appendRow([
      TextCellValue('OVERALL TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(grandFineOwed),
      DoubleCellValue(grandDirectPaid),
      DoubleCellValue(grandContribPaid),
      DoubleCellValue(grandTotalPaid),
      DoubleCellValue(grandDue),
      DoubleCellValue(grandSurplus),
      TextCellValue(''),
    ]);
  }

  // --- SHEET 7: FINE PAYMENTS ---
  static void _buildFinePaymentsSheet(Excel excel, List<FinePayment> payments) {
    final sheet = excel['FINE_PAYMENTS'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Player Name'),
      TextCellValue('Amount Paid (৳)'),
      TextCellValue('Month & Year'),
      TextCellValue('Note'),
    ]);

    final sorted = List<FinePayment>.from(payments)..sort((a, b) => b.date.compareTo(a.date));
    double total = 0;

    for (var p in sorted) {
      total += p.amountPaid;
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(p.date)),
        TextCellValue(p.playerName),
        DoubleCellValue(p.amountPaid),
        TextCellValue(p.monthYear),
        TextCellValue(p.note ?? ''),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      DoubleCellValue(total),
      TextCellValue(''),
      TextCellValue(''),
    ]);
  }

  // --- SHEET 8: CONTRIBUTIONS ---
  static void _buildContributionsSheet(Excel excel, List<Contribution> contribs) {
    final sheet = excel['CONTRIBUTIONS'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Contributor Name'),
      TextCellValue('Amount (৳)'),
      TextCellValue('Category / Type'),
      TextCellValue('Item Details'),
      TextCellValue('Month & Year'),
    ]);

    final sorted = List<Contribution>.from(contribs)..sort((a, b) => b.date.compareTo(a.date));
    double total = 0;

    for (var c in sorted) {
      total += c.taka;
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(c.date)),
        TextCellValue(c.name),
        DoubleCellValue(c.taka),
        TextCellValue(c.isOther ? 'OTHER CONTRIBUTION' : 'MATCH CONTRIBUTION'),
        TextCellValue(c.ballTape.isNotEmpty ? c.ballTape : '-'),
        TextCellValue(c.monthYear),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      DoubleCellValue(total),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
  }

  // --- SHEET 9: TREASURY FUNDS ---
  static void _buildTreasuryFundsSheet(Excel excel, List<Fund> funds) {
    final sheet = excel['TREASURY_FUNDS'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Transaction Type'),
      TextCellValue('Source / Beneficiary Name'),
      TextCellValue('Amount (৳)'),
      TextCellValue('Note / Description'),
    ]);

    final sorted = List<Fund>.from(funds)..sort((a, b) => b.date.compareTo(a.date));
    double totalIncome = 0;
    double totalExpense = 0;

    for (var f in sorted) {
      if (f.type == 'INCOME') totalIncome += f.amount;
      if (f.type == 'EXPENSE') totalExpense += f.amount;

      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(f.date)),
        TextCellValue(f.type),
        TextCellValue(f.name),
        DoubleCellValue(f.amount),
        TextCellValue(f.note ?? ''),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL INCOME'),
      TextCellValue('INCOME'),
      TextCellValue(''),
      DoubleCellValue(totalIncome),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('TOTAL EXPENSE'),
      TextCellValue('EXPENSE'),
      TextCellValue(''),
      DoubleCellValue(totalExpense),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('NET BALANCE'),
      TextCellValue('BALANCE'),
      TextCellValue(''),
      DoubleCellValue(totalIncome - totalExpense),
      TextCellValue(''),
    ]);
  }

  // --- SHEET 10: INVENTORY STOCK ---
  static void _buildInventoryStockSheet(Excel excel, List<Inventory> inventoryList) {
    final sheet = excel['INVENTORY_STOCK'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Balls Bought'),
      TextCellValue('Tapes Bought'),
      TextCellValue('Balls Taken'),
      TextCellValue('Balls Returned'),
      TextCellValue('Player Lost'),
      TextCellValue('Unintentional Lost'),
      TextCellValue('Total Lost'),
      TextCellValue('Stock Update?'),
      TextCellValue('Recorded By'),
      TextCellValue('Session Notes'),
    ]);

    final sorted = List<Inventory>.from(inventoryList)..sort((a, b) => b.date.compareTo(a.date));

    for (var item in sorted) {
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(item.date)),
        IntCellValue(item.ballsBrought),
        IntCellValue(item.tapesBrought),
        IntCellValue(item.ballsTaken),
        IntCellValue(item.ballsReturned),
        IntCellValue(item.playerLost),
        IntCellValue(item.uninteniollyLost),
        IntCellValue(item.totalLost),
        TextCellValue(item.isStockUpdate ? 'MANUAL RESET (${item.totalStock})' : 'SESSION LOG'),
        TextCellValue(item.recordedBy),
        TextCellValue(item.note),
      ]);
    }
  }

  // --- SHEET 11: PLAYERS ROSTER ---
  static void _buildPlayersRosterSheet(Excel excel, List<Player> players) {
    final sheet = excel['PLAYERS_ROSTER'];
    sheet.appendRow([
      TextCellValue('Player ID'),
      TextCellValue('Player Name'),
      TextCellValue('Phone Number'),
      TextCellValue('Career Total Balls Lost'),
    ]);

    for (var p in players) {
      sheet.appendRow([
        TextCellValue(p.id ?? ''),
        TextCellValue(p.name),
        TextCellValue(p.phone),
        IntCellValue(p.totalLost),
      ]);
    }
  }

  // --- PLATFORM SHARING / SAVING HELPER ---
  static Future<void> _shareExcelFile(List<int> bytes, String fileName) async {
    const mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    if (!kIsWeb) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: mime, name: fileName)],
          text: 'Ball Terminator Club Excel Export: $fileName',
        );
        return;
      } catch (e) {
        debugPrint('File path sharing failed, falling back to memory XFile: $e');
      }
    }

    // Web or fallback
    await Share.shareXFiles(
      [XFile.fromData(Uint8List.fromList(bytes), name: fileName, mimeType: mime)],
      text: 'Ball Terminator Club Excel Export: $fileName',
    );
  }
}
