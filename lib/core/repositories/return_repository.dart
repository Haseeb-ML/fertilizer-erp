import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/return_record.dart';

class ReturnRepository {
  final DatabaseHelper _dbHelper;

  ReturnRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<ReturnRecord>> getReturns({
    String? returnType, // 'SALE_RETURN' or 'PURCHASE_RETURN'
    String? search,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (returnType != null && returnType.isNotEmpty) {
      whereClauses.add('return_type = ?');
      whereArgs.add(returnType);
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      whereClauses.add(
        '(party_name LIKE ? OR product_name LIKE ? OR original_invoice_number LIKE ? OR reason LIKE ?)',
      );
      whereArgs.addAll([q, q, q, q]);
    }

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('return_date >= ?');
      whereArgs.add(fromDate);
    }

    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('return_date <= ?');
      whereArgs.add(toDate);
    }

    final whereString =
        whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      DatabaseTables.returns,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'id DESC',
    );

    return maps.map((m) => ReturnRecord.fromMap(m)).toList();
  }

  Future<Map<String, double>> getReturnsSummary() async {
    final db = await _dbHelper.database;

    final saleRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0) as total_amount,
        COALESCE(SUM(quantity), 0) as total_qty
      FROM ${DatabaseTables.returns}
      WHERE return_type = 'SALE_RETURN'
    ''');

    final purRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0) as total_amount,
        COALESCE(SUM(quantity), 0) as total_qty
      FROM ${DatabaseTables.returns}
      WHERE return_type = 'PURCHASE_RETURN'
    ''');

    final saleAmount =
        (saleRes.first['total_amount'] as num?)?.toDouble() ?? 0.0;
    final saleQty = (saleRes.first['total_qty'] as num?)?.toDouble() ?? 0.0;

    final purAmount =
        (purRes.first['total_amount'] as num?)?.toDouble() ?? 0.0;
    final purQty = (purRes.first['total_qty'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalCustomerReturns': saleAmount,
      'totalCustomerReturnQty': saleQty,
      'totalSupplierReturns': purAmount,
      'totalSupplierReturnQty': purQty,
    };
  }
}

