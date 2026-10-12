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

    return maps.map((e) => LedgerEntry.fromMap(e, isCustomer: false)).toList();
  }

  Future<double> getTotalPayables() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance), 0) as total FROM ${DatabaseTables.suppliers} WHERE current_balance > 0 AND is_active = 1',
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
