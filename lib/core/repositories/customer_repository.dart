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
      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);
      final custMap = customer
          .copyWith(
            currentBalance: customer.openingBalance,
            createdAt: now,
            updatedAt: now,
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
      orderBy: 'transaction_date ASC, id ASC',
    );

    return maps.map((e) => LedgerEntry.fromMap(e, isCustomer: true)).toList();
  }

  Future<double> getTotalReceivables() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(current_balance), 0) as total FROM ${DatabaseTables.customers} WHERE current_balance > 0 AND is_active = 1',
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
