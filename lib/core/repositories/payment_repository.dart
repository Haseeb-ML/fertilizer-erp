import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/payment.dart';
import '../services/accounting_service.dart';

class PaymentRepository {
  final DatabaseHelper _dbHelper;
  PaymentRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Payment>> getPayments({
    String? partyType,
    int? partyId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (partyType != null && partyType.isNotEmpty) {
      whereClauses.add('party_type = ?');
      whereArgs.add(partyType);
    }

    if (partyId != null) {
      whereClauses.add('party_id = ?');
      whereArgs.add(partyId);
    }

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('payment_date >= ?');
      whereArgs.add(fromDate);
    }

    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('payment_date <= ?');
      whereArgs.add(toDate);
    }

    final whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;
    final maps = await db.query(
      DatabaseTables.payments,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'id DESC',
    );

    return maps.map((e) => Payment.fromMap(e)).toList();
  }

  /// Receive payment from customer
  Future<int> recordCustomerPayment(Payment payment) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final today = payment.paymentDate.isNotEmpty
          ? payment.paymentDate
          : now.substring(0, 10);

      final paymentMap = payment.toMap();
      paymentMap['created_at'] = now;
      final paymentId = await txn.insert(DatabaseTables.payments, paymentMap);

      // Customer Ledger: Credit decreases customer receivable
      await AccountingService.addCustomerLedgerEntry(
        txn,
        customerId: payment.partyId,
        transactionDate: today,
        transactionType: 'PAYMENT_RECEIVED',
        referenceId: paymentId,
        referenceNumber: payment.referenceNumber,
        description:
            'Payment Received (${payment.paymentMethod})${payment.notes.isNotEmpty ? ' - ${payment.notes}' : ''}',
        debit: 0.0,
        credit: payment.amount,
      );

      return paymentId;
    });
  }

  /// Make payment to supplier
  Future<int> recordSupplierPayment(Payment payment) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final today = payment.paymentDate.isNotEmpty
          ? payment.paymentDate
          : now.substring(0, 10);

      final paymentMap = payment.toMap();
      paymentMap['created_at'] = now;
      final paymentId = await txn.insert(DatabaseTables.payments, paymentMap);

      // Supplier Ledger: Debit decreases supplier payable
      await AccountingService.addSupplierLedgerEntry(
        txn,
        supplierId: payment.partyId,
        transactionDate: today,
        transactionType: 'PAYMENT_PAID',
        referenceId: paymentId,
        referenceNumber: payment.referenceNumber,
        description:
            'Payment Made (${payment.paymentMethod})${payment.notes.isNotEmpty ? ' - ${payment.notes}' : ''}',
        debit: payment.amount,
        credit: 0.0,
      );

      return paymentId;
    });
  }
}
