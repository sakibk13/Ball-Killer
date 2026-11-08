import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/unintentional_record.dart';
import '../models/audit_log.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';

class UnintentionalProvider with ChangeNotifier {
  List<UnintentionalRecord> _records = [];
  bool _isLoading = false;

  UnintentionalProvider() {
    init();
  }

  List<UnintentionalRecord> get records => _records;
  bool get isLoading => _isLoading;

  Future<void> init({bool force = false}) async {
    if (!force && _records.isNotEmpty) return;
    await fetchRecords();
  }

  Future<void> refresh() async {
    await fetchRecords();
  }

  Future<void> fetchRecords() async {
    _isLoading = true;
    notifyListeners();
    try {
      _records = await DatabaseService().getUnintentionalRecords();
    } catch (e) {
      debugPrint('Fetch Unintentional Records Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addRecord({
    required int lostCount,
    required DateTime date,
    required String recordedBy,
    String note = '',
  }) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      final record = UnintentionalRecord(
        lostCount: lostCount,
        date: date,
        monthYear: DateFormat('MMMM yyyy').format(date),
        recordedBy: recordedBy,
        note: note,
        createdAt: DateTime.now(),
      );

      success = await DatabaseService().addUnintentionalRecord(record);
      if (success) {
        await DatabaseService().addAuditLog(AuditLog(
          adminName: recordedBy,
          action: 'ADD_UNINTENTIONAL_LOSS',
          details: 'Recorded $lostCount unintentional ball(s) on ${DateFormat('dd MMM yyyy').format(date)}',
          timestamp: DateTime.now(),
        ));
        await fetchRecords();
      }
    } catch (e) {
      debugPrint('Add Unintentional Record Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> updateRecord(UnintentionalRecord record, int oldCount, String adminName) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().updateUnintentionalRecord(record);
      if (success) {
        await DatabaseService().addAuditLog(AuditLog(
          adminName: adminName,
          action: 'UPDATE_UNINTENTIONAL_LOSS',
          details: 'Updated unintentional loss from $oldCount to ${record.lostCount} balls',
          timestamp: DateTime.now(),
        ));
        await fetchRecords();
      }
    } catch (e) {
      debugPrint('Update Unintentional Record Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> deleteRecord(String id, int lostCount, String adminName) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      await DatabaseService().deleteUnintentionalRecord(id);
      await DatabaseService().addAuditLog(AuditLog(
        adminName: adminName,
        action: 'DELETE_UNINTENTIONAL_LOSS',
        details: 'Deleted unintentional loss record of $lostCount ball(s)',
        timestamp: DateTime.now(),
      ));
      await fetchRecords();
      success = true;
    } catch (e) {
      debugPrint('Delete Unintentional Record Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  int getOverallTotal() {
    return _records.fold(0, (sum, r) => sum + r.lostCount);
  }

  int getTotalLostForMonth(String monthYear) {
    final normalized = DateUtilsHelper.normalizeMonthYear(monthYear);
    if (normalized == 'Overall') {
      return getOverallTotal();
    }
    return _records
        .where((r) => DateUtilsHelper.normalizeMonthYear(r.monthYear) == normalized)
        .fold(0, (sum, r) => sum + r.lostCount);
  }

  List<UnintentionalRecord> getRecordsForMonth(String monthYear) {
    final normalized = DateUtilsHelper.normalizeMonthYear(monthYear);
    if (normalized == 'Overall') return _records;
    return _records
        .where((r) => DateUtilsHelper.normalizeMonthYear(r.monthYear) == normalized)
        .toList();
  }

  Map<String, int> getDailySubtotals(String monthYear) {
    final records = getRecordsForMonth(monthYear);
    final Map<String, int> daily = {};
    for (var r in records) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
      daily[dateStr] = (daily[dateStr] ?? 0) + r.lostCount;
    }
    return daily;
  }

  List<String> getAvailableMonths() {
    final Set<String> months = {'Overall'};
    for (var r in _records) {
      if (r.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
      }
    }
    // Also include current month and last month
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
}
