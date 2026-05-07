import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contribution.dart';
import '../models/fine_payment.dart';
import '../models/fund.dart';
import '../models/inventory.dart';
import '../models/player.dart';
import '../utils/date_utils.dart';

class CloudSyncService {
  // Base URL - Can be updated with a new Deploy ID
  static String _deployId = 'AKfycbyoCjp4KvDo_zf3Ro5Ztx22CCZWizWD2QoccX7bzd_aH5MPtJN8z0Mo8XtZl6Oz3-sU';
  static const String _lastSyncKey = 'last_google_sync_time';

  static void setDeployId(String id) {
    _deployId = id;
  }

  static String get _url => 'https://script.google.com/macros/s/$_deployId/exec';

  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final String? timeStr = prefs.getString(_lastSyncKey);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  static Future<void> updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Syncs a single user's info to the Google Sheet (Real-time sync)
  static Future<void> syncSingleUser({
    required String name,
    required String phone,
    required String password,
  }) async {
    if (_deployId.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'singleUserSync': {
            'name': name,
            'phone': phone,
            'password': password,
          }
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 302) {
        debugPrint("Single user sync successful: $name");
      }
    } catch (e) {
      debugPrint("Single user sync error: $e");
    }
  }

  static Future<Map<String, dynamic>> syncAllData({
    required Map<String, List<Map<String, dynamic>>> allMonthlyLeaderboards,
    required List<Map<String, dynamic>> leaderboardOverall,
    required List<Map<String, dynamic>> playerStatusOverall,
    required List<Fund> funds,
    required List<Contribution> contributions,
    required List<FinePayment> fines,
    required List<Inventory> stock,
    required List<Player> users, 
  }) async {
    try {
      final String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

      final Map<String, dynamic> payload = {
        // Now sending a map of [Month Name]: [Ranked List]
        'allMonthlyLeaderboards': allMonthlyLeaderboards.map((month, list) => MapEntry(
          DateUtilsHelper.normalizeMonthYear(month), 
          list.asMap().entries.map((e) => [e.key + 1, e.value['name'], e.value['total']]).toList()
        )),
        
        'leaderboardOverall': leaderboardOverall.asMap().entries.map((e) => [e.key + 1, e.value['name'], e.value['total']]).toList(),
        
        'playerStatus': playerStatusOverall.asMap().entries.map((e) => [
          e.key + 1,
          e.value['name'],
          e.value['phone'],
          e.value['total'],
          e.value['totalFine'],
          e.value['paid'],
          e.value['due'],
          e.value['surplus'],
        ]).toList(),
        
        'finance': funds.map((f) => [
          DateFormat('yyyy-MM-dd').format(f.date),
          f.name,
          f.type, 
          f.amount,
          f.note ?? '',
          DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date)),
        ]).toList(),
        
        'contributions': contributions.map((c) => [
          DateFormat('yyyy-MM-dd').format(c.date),
          c.name,
          c.taka,
          DateUtilsHelper.normalizeMonthYear(c.monthYear),
          c.isFinePayment ? 'Yes' : 'No',
          c.ballTape,
        ]).toList(),
        
        'fines': fines.map((f) => [
          DateFormat('yyyy-MM-dd').format(f.date),
          f.playerName,
          f.amountPaid,
          DateUtilsHelper.normalizeMonthYear(f.monthYear),
          f.note ?? '',
        ]).toList(),
        
        'stock': stock.map((s) => [
          DateFormat('yyyy-MM-dd').format(s.date),
          s.ballsBrought,
          s.tapesBrought,
          s.ballsTaken,
          s.ballsReturned,
          s.totalLost,
          s.uninteniollyLost,
          s.playerLost,
          s.isStockUpdate ? s.totalStock : '-',
          s.recordedBy,
          s.note,
        ]).toList(),

        'users': users.map((u) => [
          u.name,
          u.phone,
          (u.password.isNotEmpty) ? "ACTIVE" : "NO ACCOUNT",
          u.id != null ? "Yes" : "No",
        ]).toList(),
        
        'currentMonth': currentMonth,
      };

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 40));

      if (response.body.contains("Sync Successful") || response.statusCode == 200 || response.statusCode == 302) {
        await updateLastSyncTime();
        return {'success': true, 'message': 'Sync Successful'};
      } else {
        return {'success': false, 'message': response.body.isEmpty ? 'Status ${response.statusCode}' : response.body};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network Error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> fetchDataFromSheets() async {
    try {
      final response = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Fetch From Sheets Error: $e');
    }
    return null;
  }
}
