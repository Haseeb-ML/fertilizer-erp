import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/customer.dart';
import '../models/ledger_entry.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper;
  CustomerRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Customer>> getCustomers({
    String? search,
    bool? onlyActive = true,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (onlyActive != null) {
      whereClauses.add('is_active = ?');
      whereArgs.add(onlyActive ? 1 : 0);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add(
        '(name LIKE ? OR phone LIKE ? OR village_or_address LIKE ?)',
      );
      final query = '%${search.trim()}%';
      whereArgs.addAll([query, query, query]);
    }

    final whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;
    final maps = await db.query(
      DatabaseTables.customers,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return maps.map((e) => Customer.fromMap(e)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.customers,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final now = customer.createdAt.isNotEmpty
          ? customer.createdAt
          : DateTime.now().toIso8601String();
      final today = now.length >= 10
          ? now.substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);
      final custMap = customer
          .copyWith(
            currentBalance: customer.openingBalance,
            createdAt: now,
            updatedAt: customer.updatedAt.isNotEmpty ? customer.updatedAt : now,
          )
          .toMap();

      final id = await txn.insert(DatabaseTables.customers, custMap);

      if (customer.openingBalance != 0) {
        await txn.insert(DatabaseTables.customerLedger, {
          'customer_id': id,
          'transaction_date': today,
          'transaction_type': 'OPENING_BALANCE',
          'reference_id': null,
          'reference_number': null,
          'description': 'Opening Balance',
          'debit': customer.openingBalance > 0 ? customer.openingBalance : 0.0,
          'credit': customer.openingBalance < 0
              ? customer.openingBalance.abs()
              : 0.0,
          'running_balance': customer.openingBalance,
          'created_at': now,
        });
      }

      return id;
    });
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      DatabaseTables.customers,
      {
        'name': customer.name,
        'phone': customer.phone,
        'village_or_address': customer.villageOrAddress,
        'credit_limit': customer.creditLimit,
        'notes': customer.notes,
        'is_active': customer.isActive ? 1 : 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> deactivateCustomer(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.customers,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> activateCustomer(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.customers,
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LedgerEntry>> getCustomerLedger(
    int customerId, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>['customer_id = ?'];
    final whereArgs = <dynamic>[customerId];

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('transaction_date >= ?');
      whereArgs.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('transaction_date <= ?');
      whereArgs.add(toDate);
    }

    final maps = await db.query(
      DatabaseTables.customerLedger,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy:
          "CASE WHEN transaction_type = 'OPENING_BALANCE' THEN 0 ELSE 1 END, transaction_date ASC, id ASC",
    );

    final entries = <LedgerEntry>[];
    for (final map in maps) {
      final entry = LedgerEntry.fromMap(map, isCustomer: true);
      final itemsDetails = <String>[];
      double totalBags = 0.0;
      double? invoicePaidAmount;
      double? invoiceBalanceDue;
      String? invoicePaymentStatus;
      String? invoiceNotes;

      if (entry.isReturn) {
        final returnRows = await db.query(
          DatabaseTables.returns,
          where: 'original_invoice_id = ? OR id = ?',
          whereArgs: [entry.referenceId, entry.referenceId],
        );
        for (final ret in returnRows) {
          final qty = (ret['quantity'] as num?)?.toDouble() ?? 0.0;
          final name = ret['product_name'] as String? ?? '';
          final rate = (ret['unit_price'] as num?)?.toDouble() ?? 0.0;
          final total = (ret['total_amount'] as num?)?.toDouble() ?? 0.0;
          final reason = ret['reason'] as String? ?? '';
          final reasonStr = reason.isNotEmpty ? ' ($reason)' : '';
          final qtyStr = qty == qty.roundToDouble()
              ? qty.toInt().toString()
              : qty.toString();
          final rateStr = rate == rate.roundToDouble()
              ? rate.toInt().toString()
              : rate.toStringAsFixed(0);
          final totalStr = total == total.roundToDouble()
              ? total.toInt().toString()
              : total.toStringAsFixed(0);
          itemsDetails.add(
            'Returned: $qtyStr Bag × $name @ ₨$rateStr = ₨$totalStr$reasonStr',
          );
        }
        entries.add(
          entry.copyWith(itemsDetails: itemsDetails, totalBags: totalBags),
        );
      } else if (entry.isSale && entry.referenceId != null) {
        final saleRows = await db.query(
          DatabaseTables.sales,
          where: 'id = ?',
          whereArgs: [entry.referenceId],
        );
        if (saleRows.isNotEmpty) {
          final s = saleRows.first;
          invoicePaidAmount = (s['paid_amount'] as num?)?.toDouble();
          invoiceBalanceDue = (s['balance_due'] as num?)?.toDouble();
          invoicePaymentStatus = s['payment_status'] as String?;
          invoiceNotes = s['notes'] as String?;
        }

        final items = await db.query(
          DatabaseTables.saleItems,
          where: 'sale_id = ?',
          whereArgs: [entry.referenceId],
        );
        for (final item in items) {
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final unit = item['unit'] as String? ?? 'Bag';
          final name = item['product_name'] as String? ?? '';
          final rate = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
          final total = (item['total_price'] as num?)?.toDouble() ?? 0.0;
          totalBags += qty;
          final qtyStr = qty == qty.roundToDouble()
              ? qty.toInt().toString()
              : qty.toString();
          final rateStr = rate == rate.roundToDouble()
              ? rate.toInt().toString()
              : rate.toStringAsFixed(0);
          final totalStr = total == total.roundToDouble()
              ? total.toInt().toString()
              : total.toStringAsFixed(0);
          itemsDetails.add(
            '$qtyStr $unit × $name @ ₨$rateStr = ₨$totalStr',
          );
        }

        entries.add(
          entry.copyWith(
            itemsDetails: itemsDetails,
            totalBags: totalBags,
            invoicePaidAmount: invoicePaidAmount,
            invoiceBalanceDue: invoiceBalanceDue,
            invoicePaymentStatus: invoicePaymentStatus,
            invoiceNotes: invoiceNotes,
          ),
        );
      } else {
        entries.add(entry);
      }
    }

    return entries;
  }

  /// Reconciles all transactions and recomputes the exact running balance for a customer
  static Future<void> reconcileCustomerLedger(
    DatabaseExecutor db,
    int customerId,
  ) async {
    final customerRows = await db.query(
      DatabaseTables.customers,
      where: 'id = ?',
      whereArgs: [customerId],
    );
    if (customerRows.isEmpty) return;
    final customer = customerRows.first;
    final customerName = customer['name'] as String;
    final openingBalance =
        (customer['opening_balance'] as num?)?.toDouble() ?? 0.0;

    // 1. Ensure opening balance entry exists if openingBalance != 0
    if (openingBalance != 0.0) {
      final existingOpening = await db.query(
        DatabaseTables.customerLedger,
        where: "customer_id = ? AND transaction_type = 'OPENING_BALANCE'",
        whereArgs: [customerId],
      );
      if (existingOpening.isEmpty) {
        final createdAt =
            (customer['created_at'] as String?) ??
            DateTime.now().toIso8601String();
        final date = createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : DateTime.now().toIso8601String().substring(0, 10);
        await db.insert(DatabaseTables.customerLedger, {
          'customer_id': customerId,
          'transaction_date': date,
          'transaction_type': 'OPENING_BALANCE',
          'reference_id': null,
          'reference_number': null,
          'description': 'Opening Balance',
          'debit': openingBalance > 0 ? openingBalance : 0.0,
          'credit': openingBalance < 0 ? openingBalance.abs() : 0.0,
          'running_balance': openingBalance,
          'created_at': createdAt,
        });
      } else {
        final createdAt =
            (customer['created_at'] as String?) ??
            DateTime.now().toIso8601String();
        final date = createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : DateTime.now().toIso8601String().substring(0, 10);
        final existingDate =
            existingOpening.first['transaction_date'] as String?;
        if (existingDate != null && existingDate.compareTo(date) > 0) {
          await db.update(
            DatabaseTables.customerLedger,
            {'transaction_date': date},
            where: 'id = ?',
            whereArgs: [existingOpening.first['id']],
          );
        }
      }
    }

    // 2. Reconcile sales invoices for this customer
    final sales = await db.query(
      DatabaseTables.sales,
      where: 'customer_id = ? OR (customer_id IS NULL AND customer_name = ?)',
      whereArgs: [customerId, customerName],
      orderBy: 'sale_date ASC, id ASC',
    );

    for (final sale in sales) {
      final saleId = sale['id'] as int;
      final invoiceNum = sale['invoice_number'] as String;
      final saleDate = sale['sale_date'] as String;
      final grandTotal = (sale['grand_total'] as num?)?.toDouble() ?? 0.0;
      final paidAmount = (sale['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final balanceDue = (sale['balance_due'] as num?)?.toDouble() ?? 0.0;
      final paymentMethod = sale['payment_method'] as String? ?? 'Cash';
      final isReversed = (sale['is_reversed'] as int? ?? 0) == 1;

      if (sale['customer_id'] == null) {
        await db.update(
          DatabaseTables.sales,
          {'customer_id': customerId},
          where: 'id = ?',
          whereArgs: [saleId],
        );
      }

      // Check if sale debit entry exists
      final existingSaleEntry = await db.query(
        DatabaseTables.customerLedger,
        where:
            "customer_id = ? AND reference_number = ? AND (transaction_type = 'SALE' OR transaction_type LIKE '%_SALE')",
        whereArgs: [customerId, invoiceNum],
      );

      if (existingSaleEntry.isEmpty) {
        final items = await db.query(
          DatabaseTables.saleItems,
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );
        final itemsDetailed = items.map((i) {
          final qty = (i['quantity'] as num?)?.toDouble() ?? 0.0;
          final unit = i['unit'] as String? ?? 'Bag';
          final name = i['product_name'] as String? ?? '';
          final rate = (i['unit_price'] as num?)?.toDouble() ?? 0.0;
          final qtyStr = qty == qty.roundToDouble()
              ? qty.toInt().toString()
              : qty.toString();
          final rateStr = rate == rate.roundToDouble()
              ? rate.toInt().toString()
              : rate.toStringAsFixed(0);
          return '$qtyStr $unit $name @ ₨$rateStr';
        }).join(', ');

        final transactionType = balanceDue <= 0
            ? 'CASH_SALE'
            : (paidAmount > 0 ? 'PARTIAL_SALE' : 'CREDIT_SALE');

        final typeLabel = balanceDue <= 0
            ? 'Cash Sale'
            : (paidAmount > 0 ? 'Partial Credit Sale' : 'Credit Sale');

        final desc = itemsDetailed.isNotEmpty
            ? '$typeLabel #$invoiceNum ($itemsDetailed)'
            : 'Sales Invoice #$invoiceNum';

        await db.insert(DatabaseTables.customerLedger, {
          'customer_id': customerId,
          'transaction_date': saleDate,
          'transaction_type': transactionType,
          'reference_id': saleId,
          'reference_number': invoiceNum,
          'description': desc,
          'debit': grandTotal,
          'credit': 0.0,
          'running_balance': 0.0,
          'created_at': sale['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      // Check if paidAmount has corresponding payment entry
      if (paidAmount > 0) {
        final existingPaymentEntry = await db.query(
          DatabaseTables.customerLedger,
          where:
              "customer_id = ? AND reference_number = ? AND transaction_type = 'PAYMENT_RECEIVED'",
          whereArgs: [customerId, invoiceNum],
        );
        if (existingPaymentEntry.isEmpty) {
          await db.insert(DatabaseTables.customerLedger, {
            'customer_id': customerId,
            'transaction_date': saleDate,
            'transaction_type': 'PAYMENT_RECEIVED',
            'reference_id': saleId,
            'reference_number': invoiceNum,
            'description':
                'Payment Received ($paymentMethod) on Sale #$invoiceNum',
            'debit': 0.0,
            'credit': paidAmount,
            'running_balance': 0.0,
            'created_at': sale['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }
      }

      // Check if reversed sale has reversal entries
      if (isReversed) {
        final existingReversal = await db.query(
          DatabaseTables.customerLedger,
          where:
              "customer_id = ? AND reference_number = ? AND transaction_type = 'SALE_REVERSAL'",
          whereArgs: [customerId, invoiceNum],
        );
        if (existingReversal.isEmpty) {
          await db.insert(DatabaseTables.customerLedger, {
            'customer_id': customerId,
            'transaction_date': saleDate,
            'transaction_type': 'SALE_REVERSAL',
            'reference_id': saleId,
            'reference_number': invoiceNum,
            'description': 'Reversal of Sales Invoice #$invoiceNum',
            'debit': 0.0,
            'credit': grandTotal,
            'running_balance': 0.0,
            'created_at': DateTime.now().toIso8601String(),
          });
          if (paidAmount > 0) {
            await db.insert(DatabaseTables.customerLedger, {
              'customer_id': customerId,
              'transaction_date': saleDate,
              'transaction_type': 'SALE_REVERSAL_REFUND',
              'reference_id': saleId,
              'reference_number': invoiceNum,
              'description': 'Refund against Reversal of Sale #$invoiceNum',
              'debit': paidAmount,
              'credit': 0.0,
              'running_balance': 0.0,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }
    }

    // 3. Reconcile standalone payments recorded in payments table
    final payments = await db.query(
      DatabaseTables.payments,
      where: "party_id = ? AND party_type = 'Customer'",
      whereArgs: [customerId],
    );
    for (final pay in payments) {
      final payId = pay['id'] as int;
      final refNum = pay['reference_number'] as String?;
      final amount = (pay['amount'] as num?)?.toDouble() ?? 0.0;
      final payDate = pay['payment_date'] as String;
      final payMethod = pay['payment_method'] as String? ?? 'Cash';
      final notes = pay['notes'] as String? ?? '';

      final existing = await db.query(
        DatabaseTables.customerLedger,
        where:
            "customer_id = ? AND (reference_id = ? OR (reference_number = ? AND reference_number IS NOT NULL AND transaction_type = 'PAYMENT_RECEIVED'))",
        whereArgs: [customerId, payId, refNum],
      );
      if (existing.isEmpty) {
        await db.insert(DatabaseTables.customerLedger, {
          'customer_id': customerId,
          'transaction_date': payDate,
          'transaction_type': 'PAYMENT_RECEIVED',
          'reference_id': payId,
          'reference_number': refNum,
          'description':
              'Payment Received ($payMethod)${notes.isNotEmpty ? ' - $notes' : ''}',
          'debit': 0.0,
          'credit': amount,
          'running_balance': 0.0,
          'created_at': pay['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }
    }

    // 4. Reconcile sales returns from returns table
    final returns = await db.query(
      DatabaseTables.returns,
      where: "party_id = ? AND return_type = 'SALE_RETURN'",
      whereArgs: [customerId],
    );
    for (final ret in returns) {
      final retId = ret['id'] as int;
      final invNum = ret['original_invoice_number'] as String?;
      final retDate = ret['return_date'] as String;
      final totalAmount = (ret['total_amount'] as num?)?.toDouble() ?? 0.0;
      final prodName = ret['product_name'] as String? ?? '';
      final qty = (ret['quantity'] as num?)?.toDouble() ?? 0.0;

      final existing = await db.query(
        DatabaseTables.customerLedger,
        where:
            "customer_id = ? AND (reference_id = ? OR (reference_number = ? AND transaction_type = 'SALE_RETURN'))",
        whereArgs: [customerId, retId, invNum],
      );
      if (existing.isEmpty) {
        await db.insert(DatabaseTables.customerLedger, {
          'customer_id': customerId,
          'transaction_date': retDate,
          'transaction_type': 'SALE_RETURN',
          'reference_id': retId,
          'reference_number': invNum,
          'description':
              'Sales Return (${qty.toStringAsFixed(0)} x $prodName) from Inv #$invNum',
          'debit': 0.0,
          'credit': totalAmount,
          'running_balance': 0.0,
          'created_at': ret['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }
    }

    // 5. Recompute running balances chronologically
    final allEntries = await db.query(
      DatabaseTables.customerLedger,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy:
          "CASE WHEN transaction_type = 'OPENING_BALANCE' THEN 0 ELSE 1 END, transaction_date ASC, id ASC",
    );

    double runningBal = 0.0;
    for (final entry in allEntries) {
      final entryId = entry['id'] as int;
      final debit = (entry['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (entry['credit'] as num?)?.toDouble() ?? 0.0;
      runningBal = runningBal + debit - credit;

      await db.update(
        DatabaseTables.customerLedger,
        {'running_balance': runningBal},
        where: 'id = ?',
        whereArgs: [entryId],
      );
    }

    // 6. Update customer's current balance
    await db.update(
      DatabaseTables.customers,
      {
        'current_balance': runningBal,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Reconciles all customer ledgers across the database
  static Future<void> reconcileAllCustomerLedgers(DatabaseExecutor db) async {
    final customers = await db.query(DatabaseTables.customers, columns: ['id']);
    for (final c in customers) {
      final id = c['id'] as int;
      await reconcileCustomerLedger(db, id);
    }
  }

  Future<double> getTotalReceivables() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance), 0) as total FROM ${DatabaseTables.customers} WHERE current_balance > 0 AND is_active = 1',
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
