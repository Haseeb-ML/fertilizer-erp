import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../services/fifo_inventory_service.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper;
  ProductRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Product>> getProducts({
    String? search,
    String? category,
    bool? onlyActive = true,
    bool? onlyLowStock = false,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (onlyActive != null) {
      whereClauses.add('is_active = ?');
      whereArgs.add(onlyActive ? 1 : 0);
    }

    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR sku LIKE ? OR brand LIKE ?)');
      final query = '%${search.trim()}%';
      whereArgs.addAll([query, query, query]);
    }

    if (onlyLowStock == true) {
      whereClauses.add('current_stock <= min_stock_alert');
    }

    final whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;
    final maps = await db.query(
      DatabaseTables.products,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.products,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<int> insertProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final prodMap = product
          .copyWith(
            currentStock: product.openingStock,
            createdAt: now,
            updatedAt: now,
          )
          .toMap();

      final id = await txn.insert(DatabaseTables.products, prodMap);

      // If opening stock exists, add FIFO layer and Stock Movement
      if (product.openingStock > 0) {
        await FifoInventoryService.addStockLayer(
          txn,
          productId: id,
          purchaseId: null,
          purchaseDate: now.substring(0, 10),
          unitCost: product.purchasePrice,
          quantity: product.openingStock,
        );

        await txn.insert(DatabaseTables.stockMovements, {
          'product_id': id,
          'product_name': product.name,
          'movement_type': 'OPENING_STOCK',
          'quantity': product.openingStock,
          'balance_after': product.openingStock,
          'reference_id': null,
          'reference_type': 'OPENING',
          'notes': 'Initial opening stock',
          'movement_date': now.substring(0, 10),
          'created_at': now,
        });
      }

      return id;
    });
  }

  Future<int> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final map = product.copyWith(updatedAt: now).toMap();
    return await db.update(
      DatabaseTables.products,
      map,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> adjustStock({
    required int productId,
    required double adjustmentQuantity, // can be positive or negative
    required String reason,
    String notes = '',
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final productMap = await txn.query(
        DatabaseTables.products,
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (productMap.isEmpty) throw Exception('Product not found');

      final current =
          (productMap.first['current_stock'] as num?)?.toDouble() ?? 0.0;
      final newStock = current + adjustmentQuantity;
      if (newStock < 0) {
        throw Exception('Stock cannot be reduced below zero');
      }

      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);
      final prodName = productMap.first['name'] as String;
      final purchasePrice =
          (productMap.first['purchase_price'] as num?)?.toDouble() ?? 0.0;

      await txn.update(
        DatabaseTables.products,
        {'current_stock': newStock, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );

      final movementType = adjustmentQuantity >= 0
          ? 'ADJUSTMENT_IN'
          : 'ADJUSTMENT_OUT';

      if (adjustmentQuantity > 0) {
        await FifoInventoryService.addStockLayer(
          txn,
          productId: productId,
          purchaseId: null,
          purchaseDate: today,
          unitCost: purchasePrice,
          quantity: adjustmentQuantity,
        );
      } else if (adjustmentQuantity < 0) {
        await FifoInventoryService.consumeStockFifo(
          txn,
          productId: productId,
          quantityToConsume: adjustmentQuantity.abs(),
        );
      }

      await txn.insert(DatabaseTables.stockMovements, {
        'product_id': productId,
        'product_name': prodName,
        'movement_type': movementType,
        'quantity': adjustmentQuantity,
        'balance_after': newStock,
        'reference_id': null,
        'reference_type': 'ADJUSTMENT',
        'notes': 'Reason: $reason. $notes',
        'movement_date': today,
        'created_at': now,
      });
    });
  }

  Future<void> deactivateProduct(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.products,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> activateProduct(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseTables.products,
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<StockMovement>> getStockMovements(int productId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.stockMovements,
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'id DESC',
    );
    return maps.map((e) => StockMovement.fromMap(e)).toList();
  }

  Future<double> getTotalStockQuantity() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(current_stock), 0) as total FROM ${DatabaseTables.products} WHERE is_active = 1',
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getInventoryValuation() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(current_stock * purchase_price), 0) as valuation FROM ${DatabaseTables.products} WHERE is_active = 1',
    );
    return (res.first['valuation'] as num?)?.toDouble() ?? 0.0;
  }
}
