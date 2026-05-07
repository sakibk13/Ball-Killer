import 'package:flutter/material.dart';
import '../models/fine_payment.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';

class FineProvider with ChangeNotifier {
  List<FinePayment> _payments = [];
  bool _isLoading = false;

  List<FinePayment> get payments => _payments;
  bool get isLoading => _isLoading;

  FineProvider() {
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    _isLoading = true;
    notifyListeners();
    try {
      _payments = await DatabaseService().getFinePayments();
    } catch (e) {
      debugPrint('Fetch Payments Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addPayment(FinePayment payment) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await DatabaseService().addFinePayment(payment);
      if (success) {
        await fetchPayments();
      }
    } catch (e) {
      debugPrint('Add Payment Error: $e');
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> deletePayment(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await DatabaseService().deleteFinePayment(id);
      await fetchPayments();
    } catch (e) {
      debugPrint('Delete Payment Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  double getTotalPaidForPlayer(String playerId, String monthYear) {
    String normalizedSearchMonth = DateUtilsHelper.normalizeMonthYear(monthYear);
    
    if (normalizedSearchMonth == 'Overall') {
      return _payments
          .where((p) => p.playerId == playerId)
          .fold(0.0, (sum, p) => sum + p.amountPaid);
    }
    return _payments
        .where((p) => p.playerId == playerId && 
                      DateUtilsHelper.normalizeMonthYear(p.monthYear) == normalizedSearchMonth)
        .fold(0.0, (sum, p) => sum + p.amountPaid);
  }

  List<FinePayment> getPaymentsForMonth(String monthYear) {
    String normalizedSearchMonth = DateUtilsHelper.normalizeMonthYear(monthYear);
    if (normalizedSearchMonth == 'Overall') return _payments;
    return _payments.where((p) => DateUtilsHelper.normalizeMonthYear(p.monthYear) == normalizedSearchMonth).toList();
  }
}
