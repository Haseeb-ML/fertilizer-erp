import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/report_models.dart';
import '../services/accounting_service.dart';

class CashbookItem {
  final String timeOrId;
  final String
  type; // Sale, Customer Payment, Purchase, Supplier Payment, Expense
  final String description;
  final double cashIn;
  final double cashOut;

  CashbookItem({
    required this.timeOrId,
    required this.type,
    required this.description,
    required this.cashIn,
    required this.cashOut,
  });
}

class CashbookRepository {
  final DatabaseHelper _dbHelper;
  CashbookRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<CashbookSummary> getDailyCashbookSummary(String date) async {
    final db = await _dbHelper.database;

    // 1. Initial cash balance from business settings
    final settingsRow = await db.query(
      DatabaseTables.businessSettings,
      columns: ['initial_cash_balance'],
      where: 'id = 1',
    );
    double initialCash = 0.0;
    if (settingsRow.isNotEmpty) {
      initialCash =
          (settingsRow.first['initial_cash_balance'] as num?)?.toDouble() ??
          0.0;
    }

    // Prior Cash In (before date)
    final priorSalesRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(paid_amount), 0) as total FROM ${DatabaseTables.sales}
      WHERE is_reversed = 0 AND (payment_method = 'Cash' OR payment_method IS NULL) AND paid_amount > 0 AND sale_date < ?
    ''',
      [date],
    );
    final priorCustPayRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DatabaseTables.payments}
      WHERE payment_type = 'CUSTOMER_IN' AND payment_method = 'Cash' AND payment_date < ?
    ''',
      [date],
    );

    // Prior Cash Out (before date)
    final priorPurchRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(paid_amount), 0) as total FROM ${DatabaseTables.purchases}
      WHERE is_reversed = 0 AND (payment_method = 'Cash' OR payment_method IS NULL) AND paid_amount > 0 AND purchase_date < ?
    ''',
      [date],
    );
    final priorSuppPayRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DatabaseTables.payments}
      WHERE payment_type = 'SUPPLIER_OUT' AND payment_method = 'Cash' AND payment_date < ?
    ''',
      [date],
    );
    final priorExpRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DatabaseTables.expenses}
      WHERE payment_method = 'Cash' AND expense_date < ?
    ''',
      [date],
    );

    final double priorIn =
        ((priorSalesRes.first['total'] as num?)?.toDouble() ?? 0.0) +
        ((priorCustPayRes.first['total'] as num?)?.toDouble() ?? 0.0);
    final double priorOut =
        ((priorPurchRes.first['total'] as num?)?.toDouble() ?? 0.0) +
        ((priorSuppPayRes.first['total'] as num?)?.toDouble() ?? 0.0) +
        ((priorExpRes.first['total'] as num?)?.toDouble() ?? 0.0);

    final double openingCash = initialCash + priorIn - priorOut;

    // Today's Cash In
    final todaySalesRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(paid_amount), 0) as total FROM ${DatabaseTables.sales}
      WHERE is_reversed = 0 AND (payment_method = 'Cash' OR payment_method IS NULL) AND paid_amount > 0 AND sale_date = ?
    ''',
      [date],
    );
    final double todaySales =
        (todaySalesRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final todayCustPayRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DatabaseTables.payments}
      WHERE payment_type = 'CUSTOMER_IN' AND payment_method = 'Cash' AND payment_date = ?
    ''',
      [date],
    );
    final double todayCustPay =
        (todayCustPayRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // Today's Cash Out
    final todayPurchRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(paid_amount), 0) as total FROM ${DatabaseTables.purchases}
      WHERE is_reversed = 0 AND (payment_method = 'Cash' OR payment_method IS NULL) AND paid_amount > 0 AND purchase_date = ?
    ''',
      [date],
    );
    final double todayPurchases =
        (todayPurchRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final todaySuppPayRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DatabaseTables.payments}
      WHERE payment_type = 'SUPPLIER_OUT' AND payment_method = 'Cash' AND payment_date = ?
    ''',
      [date],
    );
    final double todaySuppPay =
        (todaySuppPayRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final todayExpRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DatabaseTables.expenses}
      WHERE payment_method = 'Cash' AND expense_date = ?
    ''',
      [date],
    );
    final double todayExpenses =
        (todayExpRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final double totalCashIn = todaySales + todayCustPay;
    final double totalCashOut = todayPurchases + todaySuppPay + todayExpenses;
    final double closingCash = openingCash + totalCashIn - totalCashOut;

    return CashbookSummary(
      openingCash: openingCash,
      cashInSales: todaySales,
      cashInCustomerPayments: todayCustPay,
      totalCashIn: totalCashIn,
      cashOutPurchases: todayPurchases,
      cashOutSupplierPayments: todaySuppPay,
      cashOutExpenses: todayExpenses,
      totalCashOut: totalCashOut,
      closingCash: closingCash,
    );
  }

  Future<List<CashbookItem>> getDailyCashbookItems(String date) async {
    final db = await _dbHelper.database;
    final items = <CashbookItem>[];

    // Cash Sales
    final sales = await db.query(
      DatabaseTables.sales,
      where:
          "is_reversed = 0 AND (payment_method = 'Cash' OR payment_method IS NULL) AND paid_amount > 0 AND sale_date = ?",
      whereArgs: [date],
    );
    for (final s in sales) {
      items.add(
        CashbookItem(
          timeOrId: s['invoice_number'] as String,
          type: 'Cash Sale',
          description: 'Customer: ${s['customer_name']}',
          cashIn: (s['paid_amount'] as num).toDouble(),
          cashOut: 0.0,
        ),
      );
    }

    // Customer Payments
    final custPayments = await db.query(
      DatabaseTables.payments,
      where:
          "payment_type = 'CUSTOMER_IN' AND payment_method = 'Cash' AND payment_date = ?",
      whereArgs: [date],
    );
    for (final p in custPayments) {
      items.add(
        CashbookItem(
          timeOrId: 'RCP-${p['id']}',
          type: 'Customer Receipt',
          description: 'From: ${p['party_name']} (${p['notes']})',
          cashIn: (p['amount'] as num).toDouble(),
          cashOut: 0.0,
        ),
      );
    }

    // Cash Purchases
    final purchases = await db.query(
      DatabaseTables.purchases,
      where:
          "is_reversed = 0 AND (payment_method = 'Cash' OR payment_method IS NULL) AND paid_amount > 0 AND purchase_date = ?",
      whereArgs: [date],
    );
    for (final pu in purchases) {
      items.add(
        CashbookItem(
          timeOrId: pu['invoice_number'] as String,
          type: 'Cash Purchase',
          description: 'Supplier: ${pu['supplier_name']}',
          cashIn: 0.0,
          cashOut: (pu['paid_amount'] as num).toDouble(),
        ),
      );
    }

    // Supplier Payments
    final suppPayments = await db.query(
      DatabaseTables.payments,
      where:
          "payment_type = 'SUPPLIER_OUT' AND payment_method = 'Cash' AND payment_date = ?",
      whereArgs: [date],
    );
    for (final sp in suppPayments) {
      items.add(
        CashbookItem(
          timeOrId: 'PAY-${sp['id']}',
          type: 'Supplier Payment',
          description: 'To: ${sp['party_name']} (${sp['notes']})',
          cashIn: 0.0,
          cashOut: (sp['amount'] as num).toDouble(),
        ),
      );
    }

    // Expenses
    final expenses = await db.query(
      DatabaseTables.expenses,
      where: "payment_method = 'Cash' AND expense_date = ?",
      whereArgs: [date],
    );
    for (final exp in expenses) {
      items.add(
        CashbookItem(
          timeOrId: 'EXP-${exp['id']}',
          type: 'Expense (${exp['category']})',
          description: exp['title'] as String,
          cashIn: 0.0,
          cashOut: (exp['amount'] as num).toDouble(),
        ),
      );
    }

    return items;
  }

  Future<double> getCurrentCashBalance() async {
    final db = await _dbHelper.database;
    return await AccountingService.calculateCashBalance(db);
  }
}
