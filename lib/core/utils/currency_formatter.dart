import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat(
    '#,##,###.##',
    'en_US',
  );
  static final NumberFormat _integerFormat = NumberFormat('#,##,###', 'en_US');

  /// Formats amount in PKR currency: e.g. ₨ 150,000.00
  static String format(
    double amount, {
    bool showSymbol = true,
    bool showDecimals = true,
  }) {
    final prefix = showSymbol ? '₨ ' : '';
    if (showDecimals && (amount % 1 != 0)) {
      return '$prefix${_currencyFormat.format(amount)}';
    } else {
      return '$prefix${_integerFormat.format(amount)}';
    }
  }

  /// Formats amount for PDF documents with ASCII safe currency prefix (Rs.) avoiding missing glyph boxes: e.g. Rs. 150,000
  static String formatPdf(double amount, {bool showDecimals = true}) {
    if (showDecimals && (amount % 1 != 0)) {
      return 'Rs. ${_currencyFormat.format(amount)}';
    } else {
      return 'Rs. ${_integerFormat.format(amount)}';
    }
  }

  /// Compact format for dashboard KPI tiles on small screens: e.g. 1.25M or 450K
  static String formatCompact(double amount, {bool showSymbol = true}) {
    final prefix = showSymbol ? '₨ ' : '';
    if (amount.abs() >= 10000000) {
      // Crores
      return '$prefix${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount.abs() >= 100000) {
      // Lakhs
      return '$prefix${(amount / 100000).toStringAsFixed(2)} Lac';
    } else if (amount.abs() >= 1000) {
      return '$prefix${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '$prefix${amount.toStringAsFixed(0)}';
  }

  /// Parse double safely
  static double parseDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 0.0;
    final cleaned = value.replaceAll(',', '').replaceAll('₨', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }
}
