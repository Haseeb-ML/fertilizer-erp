import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/supplier.dart';
import '../models/ledger_entry.dart';

class SupplierRepository {
  final DatabaseHelper _dbHelper;
  SupplierRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Supplier>> getSuppliers({
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
        '(name LIKE ? OR phone LIKE ? OR company_or_address LIKE ?)',
      );
      final query = '%${search.trim()}%';
      whereArgs.addAll([query, query, query]);
    }

    final whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;
    final maps = await db.query(
      DatabaseTables.suppliers,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return maps.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.suppliers,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Supplier.fromMap(maps.first);
  }

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);
      final suppMap = supplier
          .copyWith(
            currentBalance: supplier.openingBalance,
            createdAt: now,
            updatedAt: now,
          )
          .toMap();

      final id = await txn.insert(DatabaseTables.suppliers, suppMap);

      if (supplier.openingBalance != 0) {
        await txn.insert(DatabaseTables.supplierLedger, {
          'supplier_id': id,
          'transaction_date': today,
          'transaction_type': 'OPENING_BALANCE',
          'reference_id': null,
          'reference_number': null,
          'description': 'Opening Balance',
          'debit': supplier.openingBalance < 0
              ? supplier.openingBalance.abs()
              : 0.0,
          'credit': supplier.openingBalance > 0 ? supplier.openingBalance : 0.0,
          'running_balance': supplier.openingBalance,
          'created_at': now,
        });
      }

      return id;
    });
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      DatabaseTables.suppliers,
      {
        'name': supplier.name,
        'phone': supplier.phone,
        'company_or_address': supplier.companyOrAddress,
        'notes': supplier.notes,
        'is_active': supplier.isActive ? 1 : 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<void> deactivateSupplier(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.suppliers,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> activateSupplier(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.suppliers,
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LedgerEntry>> getSupplierLedger(
    int supplierId, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;

    // Automatically reconcile supplier ledger so all purchase returns, opening balances
    // and running balances are completely synchronized before query.
    try {
      await reconcileSupplierLedger(db, supplierId);
    } catch (e) {
      // Don't block ledger loading if reconcile has a transient issue
    }

    final whereClauses = <String>['supplier_id = ?'];
    final whereArgs = <dynamic>[supplierId];

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('transaction_date >= ?');
      whereArgs.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('transaction_date <= ?');
      whereArgs.add(toDate);
    }

    final maps = await db.query(
      DatabaseTables.supplierLedger,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'transaction_date ASC, id ASC',
    );

    final entries = <LedgerEntry>[];
    for (final map in maps) {
      final entry = LedgerEntry.fromMap(map, isCustomer: false);
      final itemsDetails = <String>[];
      double totalBags = 0.0;
      final structuredItems = <LedgerItemDetail>[];

      if (entry.transactionType == 'PURCHASE' && entry.referenceId != null) {
        final items = await db.query(
          DatabaseTables.purchaseItems,
          where: 'purchase_id = ?',
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
          itemsDetails.add(
            '$qtyStr $unit × $name @ ₨${rate.toStringAsFixed(0)} = ₨${total.toStringAsFixed(0)}',
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
      } else if (entry.isReturn) {
        // Query return record by id/original_invoice_id or fallback by date & party
        List<Map<String, Object?>> returnRows = const [];
        try {
          if (entry.referenceId != null && entry.referenceId! > 0) {
            returnRows = await db.query(
              DatabaseTables.returns,
              where:
                  'return_type = ? AND (id = ? OR original_invoice_id = ?)',
              whereArgs: [
                'PURCHASE_RETURN',
                entry.referenceId,
                entry.referenceId
              ],
            );
          }
          if (returnRows.isEmpty) {
            returnRows = await db.query(
              DatabaseTables.returns,
              where:
                  'return_type = ? AND party_id = ? AND return_date = ?',
              whereArgs: [
                'PURCHASE_RETURN',
                supplierId,
                entry.transactionDate
              ],
            );
          }
        } catch (_) {
          returnRows = const [];
        }
        if (returnRows.isNotEmpty) {
          for (final ret in returnRows) {
            final qty = (ret['quantity'] as num?)?.toDouble() ?? 0.0;
            totalBags += qty;
            final name = ret['product_name'] as String? ?? '';
            final rate = (ret['unit_price'] as num?)?.toDouble() ?? 0.0;
            final total = (ret['total_amount'] as num?)?.toDouble() ?? 0.0;
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
        } else {
          // Parse quantity and product name from description:
          // e.g. "Purchase Return (1 x Kissan Dairy Gold)" or "Purchase Return (Cash Refunded) (5 x Urea)"
          final match = RegExp(r'\(([0-9.]+)\s*x\s*([^\)]+)\)',
                  caseSensitive: false)
              .firstMatch(entry.description);
          if (match != null) {
            final qty = double.tryParse(match.group(1)!) ?? 1.0;
            final name = match.group(2)!.trim();
            final total = entry.debit > 0 ? entry.debit : entry.credit;
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
          } else {
            // General fallback so return items are never empty
            final total = entry.debit > 0 ? entry.debit : entry.credit;
            structuredItems.add(
              LedgerItemDetail(
                productName: entry.description,
                quantity: 1,
                unit: 'Bag',
                unitPrice: total,
                totalPrice: total,
              ),
            );
          }
        }
      }

      entries.add(
        entry.copyWith(
          itemsDetails: itemsDetails,
          structuredItems: structuredItems,
          totalBags: totalBags,
        ),
      );
    }

    // Group all returns (and cash refunds) on the same date into a single
    // statement row - same behaviour as the customer ledger.
    return _groupReturnsByDate(entries);
  }

  /// Merges every PURCHASE_RETURN row of the same date (even if other rows sit
  /// between them) into ONE row, and merges same-date CASH_REFUND rows into one,
  /// then recomputes the running balance top-to-bottom.
  static List<LedgerEntry> _groupReturnsByDate(List<LedgerEntry> list) {
    if (list.length <= 1) return list;

    final retByDate = <String, List<int>>{};
    final refByDate = <String, List<int>>{};
    for (int i = 0; i < list.length; i++) {
      final e = list[i];
      if (e.isReturn) {
        retByDate.putIfAbsent(e.transactionDate, () => []).add(i);
      } else if (e.transactionType == 'CASH_REFUND') {
        refByDate.putIfAbsent(e.transactionDate, () => []).add(i);
      }
    }

    String fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();

    final skip = <int>{};
    final replace = <int, LedgerEntry>{};

    for (final idxs in retByDate.values) {
      if (idxs.length < 2) continue;
      double bags = 0, debit = 0, credit = 0;
      final items = <String>[];
      final structured = <LedgerItemDetail>[];
      bool cash = false;
      for (final i in idxs) {
        final g = list[i];
        bags += g.totalBags;
        debit += g.debit;
        credit += g.credit;
        items.addAll(g.itemsDetails);
        structured.addAll(g.parsedItems);
        if (g.description.toLowerCase().contains('cash refund')) cash = true;
      }
      replace[idxs.first] = list[idxs.first].copyWith(
        description:
            'Purchase Return${cash ? ' (Cash Refunded)' : ''} (Total ${fmt(bags)} Bags)',
        itemsDetails: items,
        structuredItems: structured,
        totalBags: bags,
        debit: debit,
        credit: credit,
      );
      skip.addAll(idxs.skip(1));
    }

    for (final idxs in refByDate.values) {
      if (idxs.length < 2) continue;
      double credit = 0, debit = 0;
      for (final i in idxs) {
        credit += list[i].credit;
        debit += list[i].debit;
      }
      replace[idxs.first] = list[idxs.first].copyWith(
        description: 'Cash Refund for Purchase Returns (${idxs.length} items)',
        debit: debit,
        credit: credit,
      );
      skip.addAll(idxs.skip(1));
    }

    final result = <LedgerEntry>[];
    for (int i = 0; i < list.length; i++) {
      if (skip.contains(i)) continue;
      result.add(replace[i] ?? list[i]);
    }

    // Recompute running balance (credit increases payable, debit decreases it)
    double running = 0.0;
    final out = <LedgerEntry>[];
    for (final e in result) {
      if (e.isOpeningBalance) {
        running = e.runningBalance;
        out.add(e);
      } else {
        running = running + e.credit - e.debit;
        out.add(e.copyWith(runningBalance: running));
      }
    }
    return out;
  }

  static Future<void> reconcileSupplierLedger(
    DatabaseExecutor db,
    int supplierId,
  ) async {
    final suppRows = await db.query(
      DatabaseTables.suppliers,
      where: 'id = ?',
      whereArgs: [supplierId],
    );
    if (suppRows.isEmpty) return;
    final supp = suppRows.first;
    final openingBalance =
        (supp['opening_balance'] as num?)?.toDouble() ?? 0.0;

    // 1. Ensure opening balance entry exists if openingBalance != 0
    if (openingBalance != 0.0) {
      final existingOpening = await db.query(
        DatabaseTables.supplierLedger,
        where: "supplier_id = ? AND transaction_type = 'OPENING_BALANCE'",
        whereArgs: [supplierId],
      );
      if (existingOpening.isEmpty) {
        final createdAt =
            (supp['created_at'] as String?) ?? DateTime.now().toIso8601String();
        final date = createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : DateTime.now().toIso8601String().substring(0, 10);
        await db.insert(DatabaseTables.supplierLedger, {
          'supplier_id': supplierId,
          'transaction_date': date,
          'transaction_type': 'OPENING_BALANCE',
          'reference_id': null,
          'reference_number': null,
          'description': 'Opening Balance',
          'debit': openingBalance < 0 ? openingBalance.abs() : 0.0,
          'credit': openingBalance > 0 ? openingBalance : 0.0,
          'running_balance': openingBalance,
          'created_at': createdAt,
        });
      }
    }

    // 2. Reconcile purchase returns from returns table
    final returns = await db.query(
      DatabaseTables.returns,
      where: "party_id = ? AND return_type = 'PURCHASE_RETURN'",
      whereArgs: [supplierId],
    );
    final existingReturnEntries = await db.query(
      DatabaseTables.supplierLedger,
      where: "supplier_id = ? AND transaction_type = 'PURCHASE_RETURN'",
      whereArgs: [supplierId],
    );
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
          (((e['debit'] as num?)?.toDouble() ?? 0.0) - totalAmount).abs() < 0.005;
      bool legacyRef(Map<String, Object?> e) {
        final n = e['reference_number'] as String?;
        final isDirect = invNum == null || invNum == 'DIRECT';
        return isDirect
            ? (n == 'DIRECT' || n == 'DIRECT_RETURN' || n == null)
            : n == invNum;
      }

      Map<String, Object?>? match;
      for (final e in existingReturnEntries) {
        final id = e['id'] as int;
        if (!claimed.contains(id) &&
            (e['reference_id'] == retId ||
                (e['reference_id'] == ret['original_invoice_id'] &&
                    ret['original_invoice_id'] != 0)) &&
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
        if (match['reference_id'] == null || match['reference_id'] != retId) {
          await db.update(
            DatabaseTables.supplierLedger,
            {'reference_id': retId},
            where: 'id = ?',
            whereArgs: [match['id']],
          );
        }
        if (isCashRefund) {
          final existingCashRefund = await db.query(
            DatabaseTables.supplierLedger,
            where:
                "supplier_id = ? AND reference_id = ? AND transaction_type = 'CASH_REFUND'",
            whereArgs: [supplierId, retId],
          );
          if (existingCashRefund.isEmpty) {
            await db.insert(DatabaseTables.supplierLedger, {
              'supplier_id': supplierId,
              'transaction_date': retDate,
              'transaction_type': 'CASH_REFUND',
              'reference_id': retId,
              'reference_number': invNum ?? 'DIRECT_RETURN',
              'description':
                  'Cash Refund for Return (${qty.toStringAsFixed(0)} x $prodName)',
              'debit': 0.0,
              'credit': totalAmount,
              'running_balance': 0.0,
              'created_at': ret['created_at'] ?? DateTime.now().toIso8601String(),
            });
          }
        }
        continue;
      }

      // Not found in supplier ledger - insert missing return entry
      await db.insert(DatabaseTables.supplierLedger, {
        'supplier_id': supplierId,
        'transaction_date': retDate,
        'transaction_type': 'PURCHASE_RETURN',
        'reference_id': retId,
        'reference_number': invNum ?? 'DIRECT_RETURN',
        'description':
            'Purchase Return${isCashRefund ? " (Cash Refunded)" : ""} (${qty.toStringAsFixed(0)} x $prodName) ${invNum != null && invNum != "DIRECT" ? "from Inv #$invNum" : ""}'.trim(),
        'debit': totalAmount,
        'credit': 0.0,
        'running_balance': 0.0,
        'created_at': ret['created_at'] ?? DateTime.now().toIso8601String(),
      });

      if (isCashRefund) {
        final existingCashRefund = await db.query(
          DatabaseTables.supplierLedger,
          where:
              "supplier_id = ? AND reference_id = ? AND transaction_type = 'CASH_REFUND'",
          whereArgs: [supplierId, retId],
        );
        if (existingCashRefund.isEmpty) {
          await db.insert(DatabaseTables.supplierLedger, {
            'supplier_id': supplierId,
            'transaction_date': retDate,
            'transaction_type': 'CASH_REFUND',
            'reference_id': retId,
            'reference_number': invNum ?? 'DIRECT_RETURN',
            'description':
                'Cash Refund for Return (${qty.toStringAsFixed(0)} x $prodName)',
            'debit': 0.0,
            'credit': totalAmount,
            'running_balance': 0.0,
            'created_at': ret['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }
      }
    }

    // Remove legacy duplicate direct-return ledger entries if needed
    if (returns.isNotEmpty) {
      for (final e in existingReturnEntries) {
        final id = e['id'] as int;
        final n = e['reference_number'] as String?;
        if (!claimed.contains(id) && (n == 'DIRECT_RETURN' || n == 'DIRECT')) {
          await db.delete(
            DatabaseTables.supplierLedger,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    }

    // 3. Recompute running balance chronologically (credit increases payable, debit decreases payable)
    final allEntries = await db.query(
      DatabaseTables.supplierLedger,
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy:
          "CASE WHEN transaction_type = 'OPENING_BALANCE' THEN 0 ELSE 1 END, transaction_date ASC, id ASC",
    );

    double runningBal = 0.0;
    for (final entry in allEntries) {
      final entryId = entry['id'] as int;
      final debit = (entry['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (entry['credit'] as num?)?.toDouble() ?? 0.0;
      runningBal = runningBal + credit - debit;

      await db.update(
        DatabaseTables.supplierLedger,
        {'running_balance': runningBal},
        where: 'id = ?',
        whereArgs: [entryId],
      );
    }

    // 3. Update supplier's current balance
    await db.update(
      DatabaseTables.suppliers,
      {
        'current_balance': runningBal,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [supplierId],
    );
  }

  /// Delete supplier and optionally cascade delete their transactions
  Future<void> deleteSupplier(int supplierId, {bool force = false}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final purchCount = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseTables.purchases} WHERE supplier_id = ?',
        [supplierId],
      )) ?? 0;

      if (purchCount > 0 && !force) {
        throw Exception(
          'Supplier has $purchCount purchase invoice(s). Please delete invoices first or choose force delete.',
        );
      }

      // If force, delete purchase items and purchases
      if (purchCount > 0) {
        final purchases = await txn.query(
          DatabaseTables.purchases,
          columns: ['id'],
          where: 'supplier_id = ?',
          whereArgs: [supplierId],
        );
        for (final p in purchases) {
          final pId = p['id'] as int;
          await txn.delete(
            DatabaseTables.purchaseItems,
            where: 'purchase_id = ?',
            whereArgs: [pId],
          );
        }
        await txn.delete(
          DatabaseTables.purchases,
          where: 'supplier_id = ?',
          whereArgs: [supplierId],
        );
      }

      // Delete payments
      await txn.delete(
        DatabaseTables.payments,
        where: "party_id = ? AND (party_type = 'SUPPLIER' OR payment_type = 'SUPPLIER_OUT')",
        whereArgs: [supplierId],
      );

      // Delete returns
      await txn.delete(
        DatabaseTables.returns,
        where: "party_id = ? AND return_type = 'PURCHASE_RETURN'",
        whereArgs: [supplierId],
      );

      // Delete supplier ledger
      await txn.delete(
        DatabaseTables.supplierLedger,
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
      );

      // Delete supplier profile
      await txn.delete(
        DatabaseTables.suppliers,
        where: 'id = ?',
        whereArgs: [supplierId],
      );
    });
  }

  Future<double> getTotalPayables() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance), 0) as total FROM ${DatabaseTables.suppliers} WHERE current_balance > 0 AND is_active = 1',
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
