import 'package:flutter/material.dart';
import '../models/fund.dart';
import '../models/audit_log.dart';
import '../services/database_service.dart';

class FundProvider with ChangeNotifier {
  List<Fund> _funds = [];
  bool _isLoading = false;

  List<Fund> get funds => _funds;
  bool get isLoading => _isLoading;

  double get grandTotal => _funds.fold(0, (sum, item) {
    if (item.type == 'EXPENSE') {
      return sum - item.amount;
    }
    return sum + item.amount;
  });

  Future<void> fetchFunds() async {
    _isLoading = true;
    notifyListeners();
    try {
      _funds = await DatabaseService().getFunds();
    } catch (e) {
      debugPrint('Fetch Funds Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addFund(Fund fund, String adminName) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().addFund(fund);
      if (success) {
        await DatabaseService().addAuditLog(AuditLog(
          adminName: adminName,
          action: 'ADD_FUND',
          details: 'Added ${fund.type}: ${fund.amount} for ${fund.name}',
          timestamp: DateTime.now(),
        ));
        await fetchFunds();
      }
    } catch (e) {
      debugPrint('Add Fund Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> updateFund(Fund fund, String adminName) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().updateFund(fund);
      if (success) {
        await DatabaseService().addAuditLog(AuditLog(
          adminName: adminName,
          action: 'EDIT_FUND',
          details: 'Edited ${fund.type}: ${fund.amount} for ${fund.name}',
          timestamp: DateTime.now(),
        ));
        await fetchFunds();
      }
    } catch (e) {
      debugPrint('Update Fund Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> deleteFund(String id, String adminName) async {
    _isLoading = true;
    notifyListeners();
    try {
      final fund = _funds.firstWhere((f) => f.id == id);
      await DatabaseService().deleteFund(id);
      await DatabaseService().addAuditLog(AuditLog(
        adminName: adminName,
        action: 'DELETE_FUND',
        details: 'Deleted ${fund.type}: ${fund.amount} for ${fund.name}',
        timestamp: DateTime.now(),
      ));
      await fetchFunds();
    } catch (e) {
      debugPrint('Delete Fund Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }
}
