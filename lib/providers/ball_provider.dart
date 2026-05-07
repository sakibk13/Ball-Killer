import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/player.dart';
import '../models/audit_log.dart';
import '../models/ball_record.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';

class BallProvider with ChangeNotifier {
  List<Player> _players = [];
  List<BallRecord> _allRecords = [];
  List<BallRecord> _todayRecords = [];
  bool _isLoading = false;

  BallProvider() {
    init();
  }

  Future<void> init({bool force = false}) async {
    if (!force && _players.isNotEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _fetchPlayersNoNotify(),
        _fetchTodayRecordsNoNotify(),
        _fetchAllRecordsNoNotify(),
      ]);
    } catch (e) {
      debugPrint('Init Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await init(force: true);
  }

  Future<void> _fetchPlayersNoNotify() async {
    try {
      _players = await DatabaseService().getPlayers();
      _players.sort((a, b) {
        int cmp = b.totalLost.compareTo(a.totalLost);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }); 
    } catch (e) {
      debugPrint('Fetch Players Error: $e');
    }
  }

  Future<void> _fetchAllRecordsNoNotify() async {
    try {
      _allRecords = await DatabaseService().getRecords();
    } catch (e) {
      debugPrint('Fetch All Records Error: $e');
    }
  }

  Future<void> _fetchTodayRecordsNoNotify() async {
    try {
      _todayRecords = await DatabaseService().getTodayRecords();
    } catch (e) {
      debugPrint('Fetch Today Records Error: $e');
    }
  }

  List<Player> get players => _players;
  List<BallRecord> get allRecords => _allRecords;
  List<BallRecord> get todayRecords => _todayRecords;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> getPlayersWithTotals({String? monthYear}) {
    if (monthYear == null || monthYear == 'Overall') {
      return _players.map((p) => {
        'id': p.id,
        'name': p.name,
        'phone': p.phone,
        'photoUrl': p.photoUrl,
        'password': p.password,
        'total': p.totalLost,
      }).toList();
    }

    String normalizedSearchMonth = DateUtilsHelper.normalizeMonthYear(monthYear);
    Map<String, int> monthlyTotals = {};
    
    for (var record in _allRecords) {
      if (DateUtilsHelper.normalizeMonthYear(record.monthYear) == normalizedSearchMonth) {
        monthlyTotals[record.playerId] = (monthlyTotals[record.playerId] ?? 0) + record.lostCount;
      }
    }

    return _players.map((p) => {
      'id': p.id,
      'name': p.name,
      'phone': p.phone,
      'photoUrl': p.photoUrl,
      'password': p.password,
      'total': max(0, monthlyTotals[p.id!] ?? 0),
      'totalOverall': p.totalLost,
    }).toList()..sort((a, b) {
      int cmp = (b['total'] as num).compareTo(a['total'] as num);
      if (cmp != 0) return cmp;
      return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
    });
  }

  List<Map<String, dynamic>> getMonthlyLeaderboard(String monthYear) {
    List<Map<String, dynamic>> playersWithData = getPlayersWithTotals(monthYear: monthYear);
    return playersWithData.map((p) => {
      'name': p['name'],
      'total': p['total'],
      'photoUrl': p['photoUrl'],
    }).toList();
  }

  Future<void> fetchPlayers() async {
    _isLoading = true;
    notifyListeners();
    await _fetchPlayersNoNotify();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllRecords() async {
    _isLoading = true;
    notifyListeners();
    await _fetchAllRecordsNoNotify();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchTodayRecords() async {
    _isLoading = true;
    notifyListeners();
    await _fetchTodayRecordsNoNotify();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addPlayer({
    required String name,
    required String phone,
    int initialLoss = 0,
    required String recordedBy,
  }) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      final player = Player(name: name, phone: phone, totalLost: initialLoss); 
      final insertedPlayer = await DatabaseService().addOrUpdatePlayer(player);
      
      if (insertedPlayer != null) {
        success = true;
      }
      
      await fetchPlayers();
      await fetchTodayRecords();
      await fetchAllRecords();
    } catch (e) {
      debugPrint('Add Player Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> overridePlayerTotalLost(String playerId, int newTotal, String adminName) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      final player = _players.firstWhere((p) => p.id == playerId);
      final oldTotal = player.totalLost;
      
      success = await DatabaseService().updatePlayerTotalLost(playerId, newTotal);
      if (success) {
        await DatabaseService().addAuditLog(AuditLog(
          adminName: adminName,
          action: 'EDIT_LOSS',
          details: 'Changed ${player.name} loss from $oldTotal to $newTotal',
          timestamp: DateTime.now(),
        ));
        await fetchPlayers();
      }
    } catch (e) {
      debugPrint('Override Player Total Lost Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> addBallRecordWithDate({
    required String playerId,
    required String playerName,
    required int lostCount,
    required DateTime date,
    required String recordedBy,
    String note = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final record = BallRecord(
        playerId: playerId,
        playerName: playerName,
        lostCount: lostCount,
        date: date,
        recordedBy: recordedBy,
        monthYear: DateFormat('MMMM yyyy').format(date),
        note: note,
      );

      await DatabaseService().addRecord(record);
      await fetchPlayers();
      await fetchTodayRecords();
      await fetchAllRecords();
    } catch (e) {
      debugPrint('Force Entry Error: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updatePlayerLoss(String playerId, int change, String recordedBy, {String? monthYear}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final player = _players.firstWhere((p) => p.id == playerId);
      DateTime now = DateTime.now();
      if (monthYear != null && monthYear != 'Overall' && monthYear != DateFormat('MMMM yyyy').format(now)) {
        try {
          now = DateFormat('MMMM yyyy').parse(monthYear);
        } catch (e) {
          debugPrint('Date Parsing error: $e');
        }
      }


      final record = BallRecord(
        playerId: playerId,
        playerName: player.name,
        lostCount: change,
        date: now,
        recordedBy: recordedBy,
        monthYear: monthYear ?? DateFormat('MMMM yyyy').format(now),
      );

      await DatabaseService().addRecord(record);
      await fetchPlayers();
      await fetchTodayRecords();
      await fetchAllRecords();
    } catch (e) {
      debugPrint('Update Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addBallRecord({
    required String playerName,
    required int lostCount,
    required String recordedBy,
    String note = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      Player? player = await DatabaseService().getPlayerByName(playerName);
      if (player == null) {
        player = Player(name: playerName, phone: 'Unknown');
        player = await DatabaseService().addOrUpdatePlayer(player);
      }

      final now = DateTime.now();
      final record = BallRecord(
        playerId: player!.id!,
        playerName: player.name,
        lostCount: lostCount,
        date: now,
        recordedBy: recordedBy,
        monthYear: DateFormat('MMMM yyyy').format(now),
        note: note,
      );

      await DatabaseService().addRecord(record);
      await fetchPlayers();
      await fetchTodayRecords();
      await fetchAllRecords();
    } catch (e) {
      debugPrint('Error: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  int getTotalLostForMonth(String monthYear) {
    String normalizedSearchMonth = DateUtilsHelper.normalizeMonthYear(monthYear);
    if (normalizedSearchMonth == 'Overall') {
      return _players.fold(0, (sum, p) => sum + p.totalLost);
    }
    
    int total = 0;
    for (var record in _allRecords) {
      if (DateUtilsHelper.normalizeMonthYear(record.monthYear) == normalizedSearchMonth) {
        total += record.lostCount;
      }
    }
    return total;
  }

  Future<bool> updatePlayer(Player player) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().updatePlayer(player);
      if (success) {
        await fetchPlayers();
      }
    } catch (e) {
      debugPrint('Update Player Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> addPlayerDirect(Player player) async {
    _isLoading = true;
    notifyListeners();
    try {
      await DatabaseService().addOrUpdatePlayer(player);
      await fetchPlayers();
    } catch (e) {
      debugPrint('Add Player Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePlayer(String id, String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      await DatabaseService().deletePlayer(id, phone);
      await fetchPlayers();
    } catch (e) {
      debugPrint('Delete Player Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateRecord(BallRecord record, int oldCount) async {
    _isLoading = true;
    notifyListeners();
    try {
      await DatabaseService().updateRecord(record, oldCount);
      await fetchPlayers();
      await fetchTodayRecords();
      await fetchAllRecords();
    } catch (e) {
      debugPrint('Update Record Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteRecord(String recordId, String playerId, int lostCount, String adminName) async {
    _isLoading = true;
    notifyListeners();
    try {
      final player = _players.firstWhere((p) => p.id == playerId);
      await DatabaseService().deleteRecord(recordId, playerId, lostCount);
      await DatabaseService().addAuditLog(AuditLog(
        adminName: adminName,
        action: 'DELETE_RECORD',
        details: 'Deleted record of $lostCount balls for ${player.name}',
        timestamp: DateTime.now(),
      ));
      await fetchPlayers();
      await fetchTodayRecords();
      await fetchAllRecords();
    } catch (e) {
      debugPrint('Delete Record Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }
}
