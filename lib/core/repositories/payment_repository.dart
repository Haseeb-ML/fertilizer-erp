import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/payment.dart';
import '../services/accounting_service.dart';
import 'customer_repository.dart';

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

  /// Finds the payments row behind a PAYMENT_RECEIVED ledger entry.
  Future<Payment?> getCustomerPaymentById(int paymentId, int customerId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseTables.payments,
      where: 'id = ? AND party_id = ?',
      whereArgs: [paymentId, customerId],
    );
    if (rows.isEmpty) return null;
    return Payment.fromMap(rows.first);
  }

  /// Edit a standalone customer payment (not linked to a bill).
  Future<void> updateCustomerPayment({
    required int paymentId,
    required double amount,
    required String paymentDate,
    required String paymentMethod,
    required String notes,
  }) async {
    if (amount <= 0) throw Exception('Amount must be greater than 0');
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        DatabaseTables.payments,
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      if (rows.isEmpty) throw Exception('Payment not found');
      final p = rows.first;
      if (p['reference_invoice_id'] != null) {
        throw Exception('This payment belongs to a bill. Edit the bill instead.');
      }
      final customerId = p['party_id'] as int;
      final oldAmount = (p['amount'] as num).toDouble();

      await txn.update(
        DatabaseTables.payments,
        {
          'amount': amount,
          'payment_date': paymentDate,
          'payment_method': paymentMethod,
          'notes': notes,
        },
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      await txn.update(
        DatabaseTables.customerLedger,
        {
          'transaction_date': paymentDate,
          'credit': amount,
          'description':
              'Payment Received ($paymentMethod)${notes.isNotEmpty ? ' - $notes' : ''}',
        },
        where:
            "customer_id = ? AND reference_id = ? AND transaction_type = 'PAYMENT_RECEIVED' AND credit = ?",
        whereArgs: [customerId, paymentId, oldAmount],
      );
      await CustomerRepository.reconcileCustomerLedger(txn, customerId);
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
