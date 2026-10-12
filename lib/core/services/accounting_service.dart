import 'package:sqflite/sqflite.dart';
import '../database/database_tables.dart';

class AccountingService {
  /// Adds entry to Customer Ledger and updates customer's current balance atomically
  static Future<double> addCustomerLedgerEntry(
    DatabaseExecutor db, {
    required int customerId,
    required String transactionDate,
    required String transactionType,
    int? referenceId,
    String? referenceNumber,
    required String description,
    required double debit, // increases customer receivable
    required double credit, // decreases customer receivable
  }) async {
    // Fetch latest balance
    final customerRow = await db.query(
      DatabaseTables.customers,
      columns: ['current_balance'],
      where: 'id = ?',
      whereArgs: [customerId],
    );

    double currentBal = 0.0;
    if (customerRow.isNotEmpty) {
      currentBal =
          (customerRow.first['current_balance'] as num?)?.toDouble() ?? 0.0;
    }

    final newRunningBalance = currentBal + debit - credit;
    final now = DateTime.now().toIso8601String();

    await db.insert(DatabaseTables.customerLedger, {
      'customer_id': customerId,
      'transaction_date': transactionDate,
      'transaction_type': transactionType,
      'reference_id': referenceId,
      'reference_number': referenceNumber,
      'description': description,
      'debit': debit,
      'credit': credit,
      'running_balance': newRunningBalance,
      'created_at': now,
    });

    await db.update(
      DatabaseTables.customers,
      {'current_balance': newRunningBalance, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [customerId],
    );

    return newRunningBalance;
  }

  /// Adds entry to Supplier Ledger and updates supplier's current balance atomically
  static Future<double> addSupplierLedgerEntry(
    DatabaseExecutor db, {
    required int supplierId,
    required String transactionDate,
    required String transactionType,
    int? referenceId,
    String? referenceNumber,
    required String description,
    required double debit, // decreases supplier payable (payment or return)
    required double credit, // increases supplier payable (purchase)
  }) async {
    final supplierRow = await db.query(
      DatabaseTables.suppliers,
      columns: ['current_balance'],
      where: 'id = ?',
      whereArgs: [supplierId],
    );

    double currentBal = 0.0;
    if (supplierRow.isNotEmpty) {
      currentBal =
          (supplierRow.first['current_balance'] as num?)?.toDouble() ?? 0.0;
    }

    final newRunningBalance = currentBal + credit - debit;
    final now = DateTime.now().toIso8601String();

    await db.insert(DatabaseTables.supplierLedger, {
      'supplier_id': supplierId,
      'transaction_date': transactionDate,
      'transaction_type': transactionType,
      'reference_id': referenceId,
      'reference_number': referenceNumber,
      'description': description,
      'debit': debit,
      'credit': credit,
      'running_balance': newRunningBalance,
      'created_at': now,
    });

    await db.update(
      DatabaseTables.suppliers,
      {'current_balance': newRunningBalance, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [supplierId],
    );

    return newRunningBalance;
  }

  /// Calculates total Cash in Hand consistently from all actual cash movements
  static Future<double> calculateCashBalance(DatabaseExecutor db) async {
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

    // 2. Cash collected directly at the time of sale
    // Only non-reversed sales where payment_method is Cash and paid_amount > 0
    final salesCashResult = await db.rawQuery('''
      SELECT COALESCE(SUM(paid_amount), 0) as total_cash_sales
      FROM ${DatabaseTables.sales}
      WHERE is_reversed = 0 AND (payment_method = 'Cash' OR payment_method IS NULL) AND paid_amount > 0
    ''');
    final double cashFromSales =
        (salesCashResult.first['total_cash_sales'] as num?)?.toDouble() ?? 0.0;

    // 3. Cash received from Customer Payments recorded through the Payments screen
    final customerPaymentsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total_customer_payments
      FROM ${DatabaseTables.payments}
      WHERE payment_type = 'CUSTOMER_IN' AND payment_method = 'Cash'
    ''');
    final double cashFromCustomerPayments =
        (customerPaymentsResult.first['total_customer_payments'] as num?)
            ?.toDouble() ??
        0.0;

    // 4. Cash paid out directly at the time of purchase
    final purchasesCashResult = await db.rawQuery('''
      SELECT COALESCE(SUM(paid_amount), 0) as total_cash_purchases
      FROM ${DatabaseTables.purchases}
      WHERE is_reversed = 0 AND (payment_method = 'Cash' OR payment_method IS NULL) AND paid_amount > 0
    ''');
    final double cashPaidPurchases =
        (purchasesCashResult.first['total_cash_purchases'] as num?)
            ?.toDouble() ??
        0.0;

    // 5. Cash paid to Suppliers recorded through Payments screen
    final supplierPaymentsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total_supplier_payments
      FROM ${DatabaseTables.payments}
      WHERE payment_type = 'SUPPLIER_OUT' AND payment_method = 'Cash'
    ''');
    final double cashPaidSupplierPayments =
        (supplierPaymentsResult.first['total_supplier_payments'] as num?)
            ?.toDouble() ??
        0.0;

    // 6. Cash paid for Expenses
    final expensesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total_expenses
      FROM ${DatabaseTables.expenses}
      WHERE payment_method = 'Cash'
    ''');
    final double cashPaidExpenses =
        (expensesResult.first['total_expenses'] as num?)?.toDouble() ?? 0.0;

    return initialCash +
        cashFromSales +
        cashFromCustomerPayments -
        cashPaidPurchases -
        cashPaidSupplierPayments -
        cashPaidExpenses;
  }
}
