import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/return_record.dart';
import 'customer_repository.dart';
import 'supplier_repository.dart';

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

  /// Delete a return record, restore inventory stock, and reconcile ledgers
  Future<void> deleteReturn(int returnId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        DatabaseTables.returns,
        where: 'id = ?',
        whereArgs: [returnId],
      );
      if (rows.isEmpty) throw Exception('Return record not found');
      final r = rows.first;
      final returnType = r['return_type'] as String;
      final productId = r['product_id'] as int;
      final quantity = (r['quantity'] as num).toDouble();
      final partyId = (r['party_id'] as int?) ?? 0;

      // 1. Stock Adjustment
      final prodRows = await txn.query(
        DatabaseTables.products,
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (prodRows.isNotEmpty) {
        final currentStock = (prodRows.first['current_stock'] as num).toDouble();
        final newStock = returnType == 'SALE_RETURN'
            ? currentStock - quantity
            : currentStock + quantity;
        await txn.update(
          DatabaseTables.products,
          {
            'current_stock': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      // 2. Ledger Cleanup & Reconcile
      if (returnType == 'SALE_RETURN') {
        await txn.delete(
          DatabaseTables.customerLedger,
          where: 'reference_id = ? AND (transaction_type = ? OR transaction_type = ?)',
          whereArgs: [returnId, 'SALE_RETURN', 'CASH_REFUND'],
        );
        if (partyId > 0) {
          await CustomerRepository.reconcileCustomerLedger(txn, partyId);
        }
      } else {
        await txn.delete(
          DatabaseTables.supplierLedger,
          where: 'reference_id = ? AND (transaction_type = ? OR transaction_type = ?)',
          whereArgs: [returnId, 'PURCHASE_RETURN', 'CASH_REFUND'],
        );
        if (partyId > 0) {
          await SupplierRepository.reconcileSupplierLedger(txn, partyId);
        }
      }

      // 3. Delete Stock movement
      await txn.delete(
        DatabaseTables.stockMovements,
        where: 'reference_id = ? AND reference_type = ?',
        whereArgs: [returnId, 'RETURN'],
      );

      // 4. Delete the return record
      await txn.delete(
        DatabaseTables.returns,
        where: 'id = ?',
        whereArgs: [returnId],
      );
    });
  }
}

