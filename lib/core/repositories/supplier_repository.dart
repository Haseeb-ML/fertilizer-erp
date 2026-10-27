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
      }

      entries.add(
        entry.copyWith(
          itemsDetails: itemsDetails,
          structuredItems: structuredItems,
          totalBags: totalBags,
        ),
      );
    }

    return entries;
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

    // 2. Recompute running balance chronologically (credit increases payable, debit decreases payable)
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

  Future<double> getTotalPayables() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance), 0) as total FROM ${DatabaseTables.suppliers} WHERE current_balance > 0 AND is_active = 1',
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
