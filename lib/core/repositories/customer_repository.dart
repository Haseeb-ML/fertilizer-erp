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
      final structuredItems = <LedgerItemDetail>[];
      String? invoiceNotes;

      if (entry.isReturn) {
        final returnRows = await db.query(
          DatabaseTables.returns,
          where: 'original_invoice_id = ? OR id = ?',
          whereArgs: [entry.referenceId, entry.referenceId],
        );
        if (returnRows.isNotEmpty) {
          for (final ret in returnRows) {
            final qty = (ret['quantity'] as num?)?.toDouble() ?? 0.0;
            totalBags += qty;
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
            structuredItems.add(
              LedgerItemDetail(
                productName: name,
                quantity: qty,
                unit: 'Bag',
                unitPrice: rate,
                totalPrice: total,
                reason: reason.isNotEmpty ? reason : null,
              ),
            );
          }
        } else {
          // Fallback: parse quantity and product name from description
          // e.g. "Sales Return (9 x Sona Urea)" or "Sales Return (Cash Refunded) (9 x Sona Urea)"
          final match = RegExp(r'Sales Return.*?\((\d+(?:\.\d+)?)\s*x\s*([^\)]+)\)',
                  caseSensitive: false)
              .firstMatch(entry.description);
          if (match != null) {
            final qty = double.tryParse(match.group(1)!) ?? 1.0;
            final name = match.group(2)!.trim();
            final total = entry.credit > 0 ? entry.credit : entry.debit;
            final rate = qty > 0 ? total / qty : total;
            totalBags += qty;
            final qtyStr = qty == qty.roundToDouble()
                ? qty.toInt().toString()
                : qty.toString();
            itemsDetails.add(
              'Returned: $qtyStr Bag × $name @ ₨${rate.toStringAsFixed(0)} = ₨${total.toStringAsFixed(0)}',
            );
            structuredItems.add(
              LedgerItemDetail(
                productName: name,
                quantity: qty,
                unit: 'Bag',
                unitPrice: rate,
                totalPrice: total,
              ),
            );
          }
        }
        entries.add(
          entry.copyWith(
            itemsDetails: itemsDetails,
            structuredItems: structuredItems,
            totalBags: totalBags,
          ),
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
          structuredItems.add(
            LedgerItemDetail(
              productName: name,
              quantity: qty,
              unit: unit,
              unitPrice: rate,
              totalPrice: total,
            ),
          );
        }

        entries.add(
          entry.copyWith(
            itemsDetails: itemsDetails,
            structuredItems: structuredItems,
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

    return _groupReturns(entries);
  }

  /// Groups return entries and refund entries on the same date/batch
  /// into a single clean grouped entry so customer statements stay neat and concise,
  /// just like multi-item purchases and sales.
  static List<LedgerEntry> _groupReturns(List<LedgerEntry> list) {
    if (list.length <= 1) return list;

    // Check if there are returns or cash refunds on the same date to group
    final dateGroups = <String, List<int>>{}; // date -> indices of SALE_RETURN / CASH_REFUND
    for (int i = 0; i < list.length; i++) {
      final e = list[i];
      if (e.isReturn || e.transactionType == 'CASH_REFUND') {
        dateGroups.putIfAbsent(e.transactionDate, () => []).add(i);
      }
    }

    final toSkip = <int>{};
    final replacements = <int, List<LedgerEntry>>{}; // index -> replacement entries

    for (final entry in dateGroups.entries) {
      final indices = entry.value;
      final returnIndices = indices.where((idx) => list[idx].isReturn).toList();
      final refundIndices =
          indices.where((idx) => list[idx].transactionType == 'CASH_REFUND').toList();

      // If multiple return entries exist on the same date, merge them into 1 single row
      if (returnIndices.length > 1) {
        double sumBags = 0.0;
        double sumDebit = 0.0;
        double sumCredit = 0.0;
        final allItems = <String>[];
        final allStructured = <LedgerItemDetail>[];
        bool anyCashRefund = false;

        for (final idx in returnIndices) {
          final g = list[idx];
          sumBags += g.totalBags;
          sumDebit += g.debit;
          sumCredit += g.credit;
          allItems.addAll(g.itemsDetails);
          allStructured.addAll(g.parsedItems);
          if (g.description.toLowerCase().contains('cash refund')) {
            anyCashRefund = true;
          }
        }

        final firstReturn = list[returnIndices.first];
        final bagsCountStr = sumBags == sumBags.roundToDouble()
            ? sumBags.toInt().toString()
            : sumBags.toString();
        final refundLabel = anyCashRefund ? ' (Cash Refunded)' : '';

        final mergedReturn = firstReturn.copyWith(
          description: 'Sales Return$refundLabel (Total $bagsCountStr Bags)',
          itemsDetails: allItems,
          structuredItems: allStructured,
          totalBags: sumBags,
          debit: sumDebit,
          credit: sumCredit,
          runningBalance: firstReturn.runningBalance,
        );

        // Mark all other return indices to be skipped
        for (int k = 1; k < returnIndices.length; k++) {
          toSkip.add(returnIndices[k]);
        }

        // Handle CASH_REFUND entries on the same date
        if (refundIndices.isNotEmpty) {
          double sumRefundDebit = 0.0;
          for (final idx in refundIndices) {
            sumRefundDebit += list[idx].debit;
          }
          final firstRefund = list[refundIndices.first];
          final mergedRefund = firstRefund.copyWith(
            description:
                'Cash Refund for Sales Return (Total $bagsCountStr Bags)',
            debit: sumRefundDebit,
            credit: 0.0,
            runningBalance: firstRefund.runningBalance,
          );

          // Skip all refund indices
          toSkip.addAll(refundIndices);

          // Place mergedReturn followed immediately by mergedRefund
          replacements[returnIndices.first] = [mergedReturn, mergedRefund];
        } else {
          replacements[returnIndices.first] = [mergedReturn];
        }
      } else if (refundIndices.length > 1) {
        // Multiple cash refunds without multiple returns
        double sumRefundDebit = 0.0;
        for (final idx in refundIndices) {
          sumRefundDebit += list[idx].debit;
        }
        final firstRefund = list[refundIndices.first];
        final mergedRefund = firstRefund.copyWith(
          description: 'Cash Refund for Returns (${refundIndices.length} items)',
          debit: sumRefundDebit,
          credit: 0.0,
        );
        for (int k = 1; k < refundIndices.length; k++) {
          toSkip.add(refundIndices[k]);
        }
        replacements[refundIndices.first] = [mergedRefund];
      }
    }

    final result = <LedgerEntry>[];
    for (int i = 0; i < list.length; i++) {
      if (toSkip.contains(i)) continue;
      if (replacements.containsKey(i)) {
        result.addAll(replacements[i]!);
      } else {
        result.add(list[i]);
      }
    }

    // Recalculate running balance smoothly from top to bottom
    double running = 0.0;
    final finalResult = <LedgerEntry>[];
    for (final e in result) {
      if (e.isOpeningBalance) {
        running = e.runningBalance;
        finalResult.add(e);
      } else {
        running = running + e.debit - e.credit;
        finalResult.add(e.copyWith(runningBalance: running));
      }
    }

    return finalResult;
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
    final existingReturnEntries = await db.query(
      DatabaseTables.customerLedger,
      where: "customer_id = ? AND transaction_type = 'SALE_RETURN'",
      whereArgs: [customerId],
    );
    // Ledger rows already linked to a return (each can be claimed only once)
    final claimed = <int>{};
    for (final ret in returns) {
      final retId = ret['id'] as int;
      final invNum = ret['original_invoice_number'] as String?;
      final retDate = ret['return_date'] as String;
      final totalAmount = (ret['total_amount'] as num?)?.toDouble() ?? 0.0;
      final prodName = ret['product_name'] as String? ?? '';
      final qty = (ret['quantity'] as num?)?.toDouble() ?? 0.0;

      final isCashRefund = (ret['refund_type'] as String?) == 'CASH_REFUND';

      bool sameAmount(Map<String, Object?> e) =>
          (((e['credit'] as num?)?.toDouble() ?? 0.0) - totalAmount).abs() <
          0.005;
      bool legacyRef(Map<String, Object?> e) {
        final n = e['reference_number'] as String?;
        final isDirect = invNum == null || invNum == 'DIRECT';
        return isDirect ? (n == 'DIRECT' || n == 'DIRECT_RETURN') : n == invNum;
      }

      // Prefer exact link by return id, then fall back to legacy entries
      Map<String, Object?>? match;
      for (final e in existingReturnEntries) {
        final id = e['id'] as int;
        if (!claimed.contains(id) &&
            e['reference_id'] == retId &&
            legacyRef(e) &&
            sameAmount(e)) {
          match = e;
          break;
        }
      }
      match ??= () {
        for (final e in existingReturnEntries) {
          final id = e['id'] as int;
          if (!claimed.contains(id) &&
              legacyRef(e) &&
              sameAmount(e) &&
              e['transaction_date'] == retDate) {
            return e;
          }
        }
        return null;
      }();

      if (match != null) {
        claimed.add(match['id'] as int);
        // Even if the SALE_RETURN entry exists, ensure corresponding CASH_REFUND entry exists if needed
        if (isCashRefund) {
          final existingCashRefund = await db.query(
            DatabaseTables.customerLedger,
            where:
                "customer_id = ? AND reference_id = ? AND transaction_type = 'CASH_REFUND'",
            whereArgs: [customerId, retId],
          );
          if (existingCashRefund.isEmpty) {
            await db.insert(DatabaseTables.customerLedger, {
              'customer_id': customerId,
              'transaction_date': retDate,
              'transaction_type': 'CASH_REFUND',
              'reference_id': retId,
              'reference_number': invNum,
              'description':
                  'Cash Refund for Return (${qty.toStringAsFixed(0)} x $prodName)',
              'debit': totalAmount,
              'credit': 0.0,
              'running_balance': 0.0,
              'created_at': ret['created_at'] ?? DateTime.now().toIso8601String(),
            });
          }
        }
        continue;
      }

      // 1. Record the Return entry in ledger (so bags and items are documented)
      await db.insert(DatabaseTables.customerLedger, {
        'customer_id': customerId,
        'transaction_date': retDate,
        'transaction_type': 'SALE_RETURN',
        'reference_id': retId,
        'reference_number': invNum,
        'description':
            'Sales Return${isCashRefund ? " (Cash Refunded)" : ""} (${qty.toStringAsFixed(0)} x $prodName) from Inv #$invNum',
        'debit': 0.0,
        'credit': totalAmount,
        'running_balance': 0.0,
        'created_at': ret['created_at'] ?? DateTime.now().toIso8601String(),
      });

      // 2. If it was refunded in cash, balance was paid out to customer on the spot
      if (isCashRefund) {
        final existingCashRefund = await db.query(
          DatabaseTables.customerLedger,
          where:
              "customer_id = ? AND reference_id = ? AND transaction_type = 'CASH_REFUND'",
          whereArgs: [customerId, retId],
        );
        if (existingCashRefund.isEmpty) {
          await db.insert(DatabaseTables.customerLedger, {
            'customer_id': customerId,
            'transaction_date': retDate,
            'transaction_type': 'CASH_REFUND',
            'reference_id': retId,
            'reference_number': invNum,
            'description':
                'Cash Refund for Return (${qty.toStringAsFixed(0)} x $prodName)',
            'debit': totalAmount,
            'credit': 0.0,
            'running_balance': 0.0,
            'created_at': ret['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }
      }
    }

    // Remove legacy duplicate direct-return ledger entries that no longer
    // correspond to any return record (caused by the old double-entry bug).
    for (final e in existingReturnEntries) {
      final id = e['id'] as int;
      final n = e['reference_number'] as String?;
      if (!claimed.contains(id) && (n == 'DIRECT_RETURN' || n == 'DIRECT')) {
        await db.delete(
          DatabaseTables.customerLedger,
          where: 'id = ?',
          whereArgs: [id],
        );
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

  /// Delete customer and optionally cascade delete their transactions
  Future<void> deleteCustomer(int customerId, {bool force = false}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final salesCount = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseTables.sales} WHERE customer_id = ?',
        [customerId],
      )) ?? 0;

      if (salesCount > 0 && !force) {
        throw Exception(
          'Customer has $salesCount sales invoice(s). Please delete invoices first or choose force delete.',
        );
      }

      // If force, delete sales items and sales
      if (salesCount > 0) {
        final sales = await txn.query(
          DatabaseTables.sales,
          columns: ['id'],
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
        for (final s in sales) {
          final sId = s['id'] as int;
          await txn.delete(
            DatabaseTables.saleItems,
            where: 'sale_id = ?',
            whereArgs: [sId],
          );
        }
        await txn.delete(
          DatabaseTables.sales,
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
      }

      // Delete payments
      await txn.delete(
        DatabaseTables.payments,
        where: "party_id = ? AND (party_type = 'CUSTOMER' OR payment_type = 'CUSTOMER_IN')",
        whereArgs: [customerId],
      );

      // Delete returns
      await txn.delete(
        DatabaseTables.returns,
        where: "party_id = ? AND return_type = 'SALE_RETURN'",
        whereArgs: [customerId],
      );

      // Delete customer ledger
      await txn.delete(
        DatabaseTables.customerLedger,
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );

      // Delete customer profile
      await txn.delete(
        DatabaseTables.customers,
        where: 'id = ?',
        whereArgs: [customerId],
      );
    });
  }

  Future<double> getTotalReceivables() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance), 0) as total FROM ${DatabaseTables.customers} WHERE current_balance > 0 AND is_active = 1',
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
