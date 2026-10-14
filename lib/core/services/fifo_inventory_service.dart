import 'package:sqflite/sqflite.dart';
import '../database/database_tables.dart';
import '../models/stock_cost_layer.dart';

class FifoInventoryService {
  /// Records a new incoming stock layer (from Purchase or Opening Stock)
  static Future<void> addStockLayer(
    DatabaseExecutor db, {
    required int productId,
    int? purchaseId,
    required String purchaseDate,
    required double unitCost,
    required double quantity,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(DatabaseTables.stockCostLayers, {
      'product_id': productId,
      'purchase_id': purchaseId,
      'purchase_date': purchaseDate,
      'unit_cost': unitCost,
      'original_quantity': quantity,
      'remaining_quantity': quantity,
      'created_at': now,
    });
  }

  /// Deducts stock using FIFO and returns the exact Cost of Goods Sold (COGS)
  static Future<double> consumeStockFifo(
    DatabaseExecutor db, {
    required int productId,
    required double quantityToConsume,
  }) async {
    if (quantityToConsume <= 0) return 0.0;

    // Fetch active layers ordered by purchase_date ASC, id ASC (FIFO)
    final layersData = await db.query(
      DatabaseTables.stockCostLayers,
      where: 'product_id = ? AND remaining_quantity > 0',
      whereArgs: [productId],
      orderBy: 'purchase_date ASC, id ASC',
    );

    double needed = quantityToConsume;
    double totalCost = 0.0;

    for (final map in layersData) {
      if (needed <= 0) break;
      final layer = StockCostLayer.fromMap(map);
      final available = layer.remainingQuantity;

      double unitCost = layer.unitCost;
      if (unitCost <= 0) {
        final productMap = await db.query(
          DatabaseTables.products,
          columns: ['purchase_price'],
          where: 'id = ?',
          whereArgs: [productId],
        );
        if (productMap.isNotEmpty) {
          unitCost =
              (productMap.first['purchase_price'] as num?)?.toDouble() ?? 0.0;
        }
      }

      if (available <= needed) {
        // Consume whole layer
        totalCost += available * unitCost;
        needed -= available;
        await db.update(
          DatabaseTables.stockCostLayers,
          {'remaining_quantity': 0.0},
          where: 'id = ?',
          whereArgs: [layer.id],
        );
      } else {
        // Consume partial layer
        totalCost += needed * unitCost;
        final newRemaining = available - needed;
        needed = 0;
        await db.update(
          DatabaseTables.stockCostLayers,
          {'remaining_quantity': newRemaining},
          where: 'id = ?',
          whereArgs: [layer.id],
        );
      }
    }

    // If needed > 0 (e.g. stock deficit or fallback to product's purchase price)
    if (needed > 0) {
      final productMap = await db.query(
        DatabaseTables.products,
        columns: ['purchase_price'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      final fallbackPrice =
          (productMap.first['purchase_price'] as num?)?.toDouble() ?? 0.0;
      totalCost += needed * fallbackPrice;
    }

    return totalCost;
  }

  /// Restores stock layer on sales return
  static Future<void> restoreStockLayer(
    DatabaseExecutor db, {
    required int productId,
    required double quantity,
    required double unitCost,
    required String returnDate,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(DatabaseTables.stockCostLayers, {
      'product_id': productId,
      'purchase_id': null,
      'purchase_date': returnDate,
      'unit_cost': unitCost,
      'original_quantity': quantity,
      'remaining_quantity': quantity,
      'created_at': now,
    });
  }
}
