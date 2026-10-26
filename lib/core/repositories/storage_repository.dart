import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/storage.dart';
import '../models/storage_stock.dart';
import '../models/stock_transfer.dart';

class StorageRepository {
  final DatabaseHelper dbHelper;

  StorageRepository(this.dbHelper);

  Future<Database> get _db async => await dbHelper.database;

  /// Retrieve all storages / godowns
  Future<List<Storage>> getStorages({bool onlyActive = false}) async {
    final db = await _db;
    final where = onlyActive ? 'is_active = 1' : null;
    final maps = await db.query(
      DatabaseTables.storages,
      where: where,
      orderBy: 'is_default DESC, name ASC',
    );
    return maps.map((m) => Storage.fromMap(m)).toList();
  }

  /// Get storage by ID
  Future<Storage?> getStorageById(int id) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseTables.storages,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Storage.fromMap(maps.first);
  }

  /// Get the default storage (usually shop floor)
  Future<Storage?> getDefaultStorage() async {
    final db = await _db;
    final maps = await db.query(
      DatabaseTables.storages,
      where: 'is_default = 1 AND is_active = 1',
      limit: 1,
    );
    if (maps.isNotEmpty) return Storage.fromMap(maps.first);
    final fallback = await db.query(
      DatabaseTables.storages,
      orderBy: 'id ASC',
      limit: 1,
    );
    if (fallback.isNotEmpty) return Storage.fromMap(fallback.first);
    return null;
  }

  /// Insert a new storage
  Future<int> insertStorage(Storage storage) async {
    final db = await _db;
    return await db.transaction((txn) async {
      if (storage.isDefault) {
        await txn.update(
          DatabaseTables.storages,
          {'is_default': 0},
        );
      }
      final id = await txn.insert(DatabaseTables.storages, storage.toMap());

      // Initialize zero stock entries for existing products
      final products = await txn.query(DatabaseTables.products);
      final now = DateTime.now().toIso8601String();
      for (final p in products) {
        final pId = p['id'] as int;
        await txn.insert(
          DatabaseTables.storageStocks,
          {
            'storage_id': id,
            'product_id': pId,
            'quantity': 0.0,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      return id;
    });
  }

  /// Update an existing storage
  Future<int> updateStorage(Storage storage) async {
    final db = await _db;
    return await db.transaction((txn) async {
      if (storage.isDefault && storage.id != null) {
        await txn.update(
          DatabaseTables.storages,
          {'is_default': 0},
          where: 'id != ?',
          whereArgs: [storage.id],
        );
      }
      return await txn.update(
        DatabaseTables.storages,
        storage.toMap(),
        where: 'id = ?',
        whereArgs: [storage.id],
      );
    });
  }

  /// Delete a storage (if no non-zero stocks or soft delete)
  Future<int> deleteStorage(int id) async {
    final db = await _db;
    // Check if any product has non-zero stock in this storage
    final totalStock = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT SUM(quantity) FROM ${DatabaseTables.storageStocks} WHERE storage_id = ?',
        [id],
      ),
    );
    if (totalStock != null && totalStock > 0) {
      // Soft-delete to prevent data loss
      return await db.update(
        DatabaseTables.storages,
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return await db.delete(
      DatabaseTables.storages,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get product stocks inside a specific storage with product metadata
  Future<List<StorageStock>> getStorageStocks(int storageId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT 
        ss.id,
        ss.storage_id,
        ss.product_id,
        ss.quantity,
        ss.updated_at,
        p.name AS product_name,
        p.brand,
        p.category,
        p.bag_size,
        p.unit,
        p.purchase_price,
        p.selling_price
      FROM ${DatabaseTables.storageStocks} ss
      INNER JOIN ${DatabaseTables.products} p ON ss.product_id = p.id
      WHERE ss.storage_id = ?
      ORDER BY ss.quantity DESC, p.name ASC
    ''', [storageId]);

    return results.map((m) => StorageStock.fromMap(m)).toList();
  }

  /// Total bags/units in a specific storage
  Future<double> getTotalStorageQuantity(int storageId) async {
    final db = await _db;
    final res = await db.rawQuery(
      'SELECT SUM(quantity) as total FROM ${DatabaseTables.storageStocks} WHERE storage_id = ?',
      [storageId],
    );
    if (res.isEmpty || res.first['total'] == null) return 0.0;
    return (res.first['total'] as num).toDouble();
  }

  /// Valuation of inventory in a specific storage
  Future<double> getStorageValuation(int storageId) async {
    final db = await _db;
    final res = await db.rawQuery('''
      SELECT SUM(ss.quantity * p.purchase_price) as valuation
      FROM ${DatabaseTables.storageStocks} ss
      INNER JOIN ${DatabaseTables.products} p ON ss.product_id = p.id
      WHERE ss.storage_id = ?
    ''', [storageId]);
    if (res.isEmpty || res.first['valuation'] == null) return 0.0;
    return (res.first['valuation'] as num).toDouble();
  }

  /// Total active storages count
  Future<int> getTotalStoragesCount() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseTables.storages} WHERE is_active = 1',
      ),
    );
    return count ?? 0;
  }

  /// Total bags across all storages
  Future<double> getTotalBagsInAllStorages() async {
    final db = await _db;
    final res = await db.rawQuery(
      'SELECT SUM(quantity) as total FROM ${DatabaseTables.storageStocks}',
    );
    if (res.isEmpty || res.first['total'] == null) return 0.0;
    return (res.first['total'] as num).toDouble();
  }

  /// Transfer stock between two storages
  Future<int> transferStock({
    required int fromStorageId,
    required int toStorageId,
    required int productId,
    required double quantity,
    required String transferDate,
    String vehicleNumber = '',
    String driverName = '',
    String notes = '',
  }) async {
    if (fromStorageId == toStorageId) {
      throw ArgumentError('Source and destination storage cannot be identical.');
    }
    if (quantity <= 0) {
      throw ArgumentError('Transfer quantity must be greater than zero.');
    }

    final db = await _db;
    return await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. Check available quantity in source storage
      final sourceRows = await txn.query(
        DatabaseTables.storageStocks,
        where: 'storage_id = ? AND product_id = ?',
        whereArgs: [fromStorageId, productId],
      );

      final currentSourceQty = sourceRows.isEmpty
          ? 0.0
          : (sourceRows.first['quantity'] as num?)?.toDouble() ?? 0.0;

      if (currentSourceQty < quantity) {
        throw StateError(
          'Insufficient stock in source storage! Available: ${currentSourceQty.toStringAsFixed(0)}, Requested: ${quantity.toStringAsFixed(0)}',
        );
      }

      // 2. Deduct from source storage
      final newSourceQty = currentSourceQty - quantity;
      await txn.update(
        DatabaseTables.storageStocks,
        {
          'quantity': newSourceQty,
          'updated_at': now,
        },
        where: 'storage_id = ? AND product_id = ?',
        whereArgs: [fromStorageId, productId],
      );

      // 3. Add to destination storage
      final destRows = await txn.query(
        DatabaseTables.storageStocks,
        where: 'storage_id = ? AND product_id = ?',
        whereArgs: [toStorageId, productId],
      );

      if (destRows.isEmpty) {
        await txn.insert(DatabaseTables.storageStocks, {
          'storage_id': toStorageId,
          'product_id': productId,
          'quantity': quantity,
          'updated_at': now,
        });
      } else {
        final currentDestQty = (destRows.first['quantity'] as num?)?.toDouble() ?? 0.0;
        final newDestQty = currentDestQty + quantity;
        await txn.update(
          DatabaseTables.storageStocks,
          {
            'quantity': newDestQty,
            'updated_at': now,
          },
          where: 'storage_id = ? AND product_id = ?',
          whereArgs: [toStorageId, productId],
        );
      }

      // 4. Generate transfer number
      final dateClean = transferDate.replaceAll('-', '');
      final countResult = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseTables.stockTransfers}',
        ),
      ) ?? 0;
      final transferNumber = 'TRF-$dateClean-${(countResult + 1).toString().padLeft(4, '0')}';

      // 5. Insert transfer log
      final transferId = await txn.insert(DatabaseTables.stockTransfers, {
        'transfer_number': transferNumber,
        'from_storage_id': fromStorageId,
        'to_storage_id': toStorageId,
        'product_id': productId,
        'quantity': quantity,
        'transfer_date': transferDate,
        'vehicle_number': vehicleNumber,
        'driver_name': driverName,
        'notes': notes,
        'created_at': now,
      });

      // 6. Record movement for audit trail
      final productMap = await txn.query(
        DatabaseTables.products,
        where: 'id = ?',
        whereArgs: [productId],
      );
      final prodName = productMap.isNotEmpty ? (productMap.first['name'] as String? ?? 'Product') : 'Product';

      await txn.insert(DatabaseTables.stockMovements, {
        'product_id': productId,
        'product_name': prodName,
        'movement_type': 'INTERNAL_TRANSFER',
        'quantity': quantity,
        'balance_after': currentSourceQty, // reference tracking
        'reference_id': transferId,
        'reference_type': 'TRANSFER',
        'notes': 'Transfer $transferNumber ($vehicleNumber) - $notes',
        'movement_date': transferDate,
        'created_at': now,
      });

      return transferId;
    });
  }

  /// Retrieve stock transfers history
  Future<List<StockTransfer>> getStockTransfers({
    int? storageId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    String query = '''
      SELECT 
        st.id,
        st.transfer_number,
        st.from_storage_id,
        s1.name AS from_storage_name,
        st.to_storage_id,
        s2.name AS to_storage_name,
        st.product_id,
        p.name AS product_name,
        st.quantity,
        st.transfer_date,
        st.vehicle_number,
        st.driver_name,
        st.notes,
        st.created_at
      FROM ${DatabaseTables.stockTransfers} st
      INNER JOIN ${DatabaseTables.storages} s1 ON st.from_storage_id = s1.id
      INNER JOIN ${DatabaseTables.storages} s2 ON st.to_storage_id = s2.id
      INNER JOIN ${DatabaseTables.products} p ON st.product_id = p.id
    ''';

    final List<String> whereClauses = [];
    final List<dynamic> args = [];

    if (storageId != null) {
      whereClauses.add('(st.from_storage_id = ? OR st.to_storage_id = ?)');
      args.addAll([storageId, storageId]);
    }
    if (fromDate != null) {
      whereClauses.add('st.transfer_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      whereClauses.add('st.transfer_date <= ?');
      args.add(toDate);
    }

    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }

    query += ' ORDER BY st.id DESC';

    final results = await db.rawQuery(query, args);
    return results.map((m) => StockTransfer.fromMap(m)).toList();
  }
}
