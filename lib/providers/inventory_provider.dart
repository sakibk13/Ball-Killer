import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';

class InventoryProvider with ChangeNotifier {
  List<Inventory> _inventoryList = [];
  bool _isLoading = false;

  List<Inventory> get inventoryList => _inventoryList;
  bool get isLoading => _isLoading;

  Future<void> fetchInventory({bool force = false}) async {
    if (!force && _inventoryList.isNotEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    try {
      _inventoryList = await DatabaseService().getInventory();
    } catch (e) {
      debugPrint('Fetch Inventory Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await fetchInventory(force: true);
  }

  Future<bool> addInventory(Inventory inventory) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().addInventory(inventory);
      if (success) {
        await refresh();
      }
    } catch (e) {
      debugPrint('Add Inventory Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> updateInventory(Inventory inventory) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().updateInventory(inventory);
      if (success) {
        await refresh();
      }
    } catch (e) {
      debugPrint('Update Inventory Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> deleteInventory(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await DatabaseService().deleteInventory(id);
      await refresh();
    } catch (e) {
      debugPrint('Delete Inventory Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Map<String, Map<String, int>> getMonthlyTotals() {
    Map<String, Map<String, int>> totals = {
      "Overall": {"bought": 0, "tape": 0, "taken": 0, "totalLost": 0, "unin": 0, "player": 0, "returned": 0}
    };
    
    for (var item in _inventoryList) {
      String normalizedMonth = DateUtilsHelper.normalizeMonthYear(item.monthYear);
      if (!totals.containsKey(normalizedMonth)) {
        totals[normalizedMonth] = {"bought": 0, "tape": 0, "taken": 0, "totalLost": 0, "unin": 0, "player": 0, "returned": 0};
      }
      if (!item.isStockUpdate) {
        // Add to specific month
        totals[normalizedMonth]!["bought"] = totals[normalizedMonth]!["bought"]! + item.ballsBrought;
        totals[normalizedMonth]!["tape"] = totals[normalizedMonth]!["tape"]! + item.tapesBrought;
        totals[normalizedMonth]!["taken"] = totals[normalizedMonth]!["taken"]! + item.ballsTaken;
        totals[normalizedMonth]!["totalLost"] = totals[normalizedMonth]!["totalLost"]! + item.totalLost;
        totals[normalizedMonth]!["unin"] = totals[normalizedMonth]!["unin"]! + item.uninteniollyLost;
        totals[normalizedMonth]!["player"] = totals[normalizedMonth]!["player"]! + item.playerLost;
        totals[normalizedMonth]!["returned"] = totals[normalizedMonth]!["returned"]! + item.ballsReturned;

        // Add to Overall
        totals["Overall"]!["bought"] = totals["Overall"]!["bought"]! + item.ballsBrought;
        totals["Overall"]!["tape"] = totals["Overall"]!["tape"]! + item.tapesBrought;
        totals["Overall"]!["taken"] = totals["Overall"]!["taken"]! + item.ballsTaken;
        totals["Overall"]!["totalLost"] = totals["Overall"]!["totalLost"]! + item.totalLost;
        totals["Overall"]!["unin"] = totals["Overall"]!["unin"]! + item.uninteniollyLost;
        totals["Overall"]!["player"] = totals["Overall"]!["player"]! + item.playerLost;
        totals["Overall"]!["returned"] = totals["Overall"]!["returned"]! + item.ballsReturned;
      }
    }
    return totals;
  }

  // Calculate stock dynamically: 
  // Latest Manual Stock Update + Sum(Bought + Returned) - Sum(Total Lost) since that manual update.
  int getCumulativeRemaining(String upToMonthYear) {
    if (_inventoryList.isEmpty) return 0;

    String normalizedUpTo = DateUtilsHelper.normalizeMonthYear(upToMonthYear);
    List<Inventory> filtered = _inventoryList;
    if (normalizedUpTo != 'Overall') {
      try {
        DateTime limitDate = DateFormat('MMMM yyyy').parse(normalizedUpTo);
        DateTime endOfMonth = DateTime(limitDate.year, limitDate.month + 1, 0, 23, 59, 59);
        filtered = _inventoryList.where((item) => item.date.isBefore(endOfMonth)).toList();
      } catch (e) {
        debugPrint('Limit Date Parse Error: $e');
      }
    }

    if (filtered.isEmpty) return 0;

    List<Inventory> sorted = List.from(filtered);
    sorted.sort((a, b) => a.date.compareTo(b.date));

    int currentStock = 0;
    
    for (var item in sorted) {
      if (item.isStockUpdate) {
        currentStock = item.totalStock;
      } else {
        currentStock += item.ballsBrought;
        currentStock += item.ballsReturned;
        currentStock -= item.totalLost;
      }
    }
    
    return currentStock;
  }

  int getTodayLoss() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _inventoryList
        .where((item) => !item.isStockUpdate && 
                         item.date.year == today.year && 
                         item.date.month == today.month && 
                         item.date.day == today.day)
        .fold(0, (sum, item) => sum + item.totalLost);
  }

  int getTodayPlayerLoss() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _inventoryList
        .where((item) => !item.isStockUpdate && 
                         item.date.year == today.year && 
                         item.date.month == today.month && 
                         item.date.day == today.day)
        .fold(0, (sum, item) => sum + item.playerLost);
  }

  int getTodayUnintentionalLoss() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _inventoryList
        .where((item) => !item.isStockUpdate && 
                         item.date.year == today.year && 
                         item.date.month == today.month && 
                         item.date.day == today.day)
        .fold(0, (sum, item) => sum + item.uninteniollyLost);
  }

  int getUninteniollyLostForMonth(String monthYear) {
    final totals = getMonthlyTotals();
    String normalizedMonth = DateUtilsHelper.normalizeMonthYear(monthYear);
    if (normalizedMonth == 'Overall') {
      return totals.values.fold(0, (sum, m) => sum + (m['unin'] ?? 0));
    }
    return totals[normalizedMonth]?['unin'] ?? 0;
  }

  List<Inventory> getItemsForMonth(String monthYear) {
    String normalizedMonth = DateUtilsHelper.normalizeMonthYear(monthYear);
    if (normalizedMonth == 'Overall') return _inventoryList;
    return _inventoryList.where((item) => DateUtilsHelper.normalizeMonthYear(item.monthYear) == normalizedMonth).toList();
  }
}
