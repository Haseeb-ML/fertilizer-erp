import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _displayDate = DateFormat('dd MMM yyyy');
  static final DateFormat _displayDateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _sqlDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _sqlDateTime = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');

  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return _displayDate.format(date);
  }

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _displayDateTime.format(dateTime);
  }

  static String toSqlDate(DateTime date) {
    return _sqlDate.format(date);
  }

  static String toSqlDateTime(DateTime dateTime) {
    return _sqlDateTime.format(dateTime);
  }

  static DateTime parseSqlDate(String? sqlDate) {
    if (sqlDate == null || sqlDate.isEmpty) return DateTime.now();
    try {
      if (sqlDate.contains(' ')) {
        return _sqlDateTime.parse(sqlDate);
      }
      return _sqlDate.parse(sqlDate);
    } catch (_) {
      return DateTime.tryParse(sqlDate) ?? DateTime.now();
    }
  }

  static String formatMonthYear(DateTime date) {
    return _monthYear.format(date);
  }
}
