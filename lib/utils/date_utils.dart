import 'package:intl/intl.dart';

class DateUtilsHelper {
  static String normalizeMonthYear(String monthYear) {
    if (monthYear.isEmpty || monthYear == 'Overall') return monthYear;
    
    String input = monthYear.trim();
    
    // Support formats like "04-26" or "05-2026"
    if (input.contains('-')) {
      try {
        List<String> parts = input.split('-');
        if (parts.length == 2) {
          int month = int.parse(parts[0]);
          int year = int.parse(parts[1]);
          if (year < 100) year += 2000;
          return DateFormat('MMMM yyyy').format(DateTime(year, month));
        }
      } catch (_) {}
    }

    // Support formats like "April 2026" or "april 2026"
    try {
      // First try to parse directly
      DateTime date = DateFormat('MMMM yyyy').parse(input);
      return DateFormat('MMMM yyyy').format(date);
    } catch (_) {
      try {
        // Try title casing for the month part
        List<String> parts = input.split(' ');
        if (parts.length >= 2) {
          String m = parts[0][0].toUpperCase() + parts[0].substring(1).toLowerCase();
          String y = parts[1];
          if (y.length == 2) y = "20$y";
          DateTime date = DateFormat('MMMM yyyy').parse("$m $y");
          return DateFormat('MMMM yyyy').format(date);
        }
      } catch (_) {}
    }
    
    return input;
  }
  
  static String formatDate(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }
}
