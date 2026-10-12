import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../services/accounting_service.dart';
import '../services/fifo_inventory_service.dart';

class PurchaseRepository {
  final DatabaseHelper _dbHelper;
  PurchaseRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> generateNextPurchaseNumber() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT id FROM ${DatabaseTables.purchases} ORDER BY id DESC LIMIT 1',
    );
    final nextId = res.isEmpty ? 1 : ((res.first['id'] as int) + 1);
    final pad = nextId.toString().padLeft(4, '0');
    final year = DateTime.now().year;
    return 'PUR-$year-$pad';
  }

  Future<List<Purchase>> getPurchases({
    String? search,
    int? supplierId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (supplierId != null) {
      whereClauses.add('supplier_id = ?');
      whereArgs.add(supplierId);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(invoice_number LIKE ? OR supplier_name LIKE ?)');
      final q = '%${search.trim()}%';
      whereArgs.addAll([q, q]);
    }

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('purchase_date >= ?');
      whereArgs.add(fromDate);
    }

    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('purchase_date <= ?');
      whereArgs.add(toDate);
    }

    final whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;
    final maps = await db.query(
      DatabaseTables.purchases,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'id DESC',
    );

    final purchases = <Purchase>[];
    for (final map in maps) {
      final items = await getPurchaseItems(map['id'] as int);
      purchases.add(Purchase.fromMap(map, items: items));
    }
    return purchases;
  }

  Future<Purchase?> getPurchaseById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.purchases,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    final items = await getPurchaseItems(id);
    return Purchase.fromMap(maps.first, items: items);
  }

  Future<List<PurchaseItem>> getPurchaseItems(int purchaseId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.purchaseItems,
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
    return maps.map((e) => PurchaseItem.fromMap(e)).toList();
  }

  Future<int> createPurchase(Purchase purchase) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final today = purchase.purchaseDate.isNotEmpty
          ? purchase.purchaseDate
          : now.substring(0, 10);

      // Check unique invoice number
      final existing = await txn.query(
        DatabaseTables.purchases,
        where: 'invoice_number = ?',
        whereArgs: [purchase.invoiceNumber],
      );
      if (existing.isNotEmpty) {
        throw Exception(
          'Purchase invoice number already exists: ${purchase.invoiceNumber}',
        );
      }

      final purchaseMap = purchase.toMap();
      purchaseMap['created_at'] = now;
      final purchaseId = await txn.insert(
        DatabaseTables.purchases,
        purchaseMap,
      );

      // Insert purchase items, increment stock, add FIFO layers, and stock movements
      for (final item in purchase.items) {
        final itemMap = item.toMap();
        itemMap['purchase_id'] = purchaseId;
        await txn.insert(DatabaseTables.purchaseItems, itemMap);

        // Fetch current product stock
        final prodRows = await txn.query(
          DatabaseTables.products,
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        if (prodRows.isEmpty)
          throw Exception('Product with id ${item.productId} not found');

        final currentStock =
            (prodRows.first['current_stock'] as num?)?.toDouble() ?? 0.0;
        final newStock = currentStock + item.quantity;

        // Update product stock and optionally update purchase price
        await txn.update(
          DatabaseTables.products,
          {
            'current_stock': newStock,
            'purchase_price': item.unitPrice,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        // Add FIFO cost layer
        await FifoInventoryService.addStockLayer(
          txn,
          productId: item.productId,
          purchaseId: purchaseId,
          purchaseDate: today,
          unitCost: item.unitPrice,
          quantity: item.quantity,
        );

        // Record stock movement
        await txn.insert(DatabaseTables.stockMovements, {
          'product_id': item.productId,
          'product_name': item.productName,
          'movement_type': 'PURCHASE',
          'quantity': item.quantity,
          'balance_after': newStock,
          'reference_id': purchaseId,
          'reference_type': 'PURCHASE',
          'notes': 'Purchase Inv #${purchase.invoiceNumber}',
          'movement_date': today,
          'created_at': now,
        });
      }

      // Update Supplier Ledger:
      // 1. Credit the grand total (increases supplier payable)
      await AccountingService.addSupplierLedgerEntry(
        txn,
        supplierId: purchase.supplierId,
        transactionDate: today,
        transactionType: 'PURCHASE',
        referenceId: purchaseId,
        referenceNumber: purchase.invoiceNumber,
        description: 'Purchase Invoice #${purchase.invoiceNumber}',
        debit: 0.0,
        credit: purchase.grandTotal,
      );

      // 2. If immediate payment was made, debit the supplier ledger
      if (purchase.paidAmount > 0) {
        await AccountingService.addSupplierLedgerEntry(
          txn,
          supplierId: purchase.supplierId,
          transactionDate: today,
          transactionType: 'PAYMENT_PAID',
          referenceId: purchaseId,
          referenceNumber: purchase.invoiceNumber,
          description: 'Payment against Purchase #${purchase.invoiceNumber}',
          debit: purchase.paidAmount,
          credit: 0.0,
        );
      }

      return purchaseId;
    });
  }

  Future<void> reversePurchase(int purchaseId, String reason) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final purchaseRows = await txn.query(
        DatabaseTables.purchases,
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
      if (purchaseRows.isEmpty) throw Exception('Purchase not found');

      final purchase = Purchase.fromMap(purchaseRows.first);
      if (purchase.isReversed) throw Exception('Purchase is already reversed');

      final items = await txn.query(
        DatabaseTables.purchaseItems,
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );

      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);

      // Check stock sufficiency and deduct
      for (final itemMap in items) {
        final prodId = itemMap['product_id'] as int;
        final qty = (itemMap['quantity'] as num).toDouble();
        final prodName = itemMap['product_name'] as String;

        final prodRows = await txn.query(
          DatabaseTables.products,
          where: 'id = ?',
          whereArgs: [prodId],
        );
        final currentStock = (prodRows.first['current_stock'] as num)
            .toDouble();
        if (currentStock < qty) {
          throw Exception(
            'Cannot reverse purchase: Available stock for $prodName is only $currentStock, but $qty is being reversed.',
          );
        }

        final newStock = currentStock - qty;
        await txn.update(
          DatabaseTables.products,
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [prodId],
        );

        // Deduct FIFO layer
        await FifoInventoryService.consumeStockFifo(
          txn,
          productId: prodId,
          quantityToConsume: qty,
        );

        // Record stock movement
        await txn.insert(DatabaseTables.stockMovements, {
          'product_id': prodId,
          'product_name': prodName,
          'movement_type': 'PURCHASE_REVERSAL',
          'quantity': -qty,
          'balance_after': newStock,
          'reference_id': purchaseId,
          'reference_type': 'PURCHASE',
          'notes':
              'Reversal of Inv #${purchase.invoiceNumber}. Reason: $reason',
          'movement_date': today,
          'created_at': now,
        });
      }

      // Reverse Supplier Ledger effect:
      // If purchase credited grandTotal, debit it back
      await AccountingService.addSupplierLedgerEntry(
        txn,
        supplierId: purchase.supplierId,
        transactionDate: today,
        transactionType: 'PURCHASE_REVERSAL',
        referenceId: purchaseId,
        referenceNumber: purchase.invoiceNumber,
        description: 'Reversal of Purchase #${purchase.invoiceNumber}',
        debit: purchase.grandTotal,
        credit: 0.0,
      );

      // If paid amount was debited, credit it back
      if (purchase.paidAmount > 0) {
        await AccountingService.addSupplierLedgerEntry(
          txn,
          supplierId: purchase.supplierId,
          transactionDate: today,
          transactionType: 'PURCHASE_REVERSAL_REFUND',
          referenceId: purchaseId,
          referenceNumber: purchase.invoiceNumber,
          description:
              'Reversal refund for Purchase #${purchase.invoiceNumber}',
          debit: 0.0,
          credit: purchase.paidAmount,
        );
      }

      await txn.update(
        DatabaseTables.purchases,
        {'is_reversed': 1},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
    });
  }

  Future<void> returnPurchaseItem({
    required int purchaseId,
    required int productId,
    required double quantity,
    required double unitPrice,
    required String refundType, // LEDGER_ADJUST or CASH_REFUND
    required String reason,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final purchaseRows = await txn.query(
        DatabaseTables.purchases,
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
      if (purchaseRows.isEmpty) throw Exception('Purchase not found');
      final purchase = Purchase.fromMap(purchaseRows.first);

      final prodRows = await txn.query(
        DatabaseTables.products,
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (prodRows.isEmpty) throw Exception('Product not found');
      final currentStock = (prodRows.first['current_stock'] as num).toDouble();
      if (currentStock < quantity) {
        throw Exception(
          'Not enough stock to return ($currentStock available, $quantity requested)',
        );
      }

      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);
      final prodName = prodRows.first['name'] as String;
      final newStock = currentStock - quantity;

      await txn.update(
        DatabaseTables.products,
        {'current_stock': newStock, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await FifoInventoryService.consumeStockFifo(
        txn,
        productId: productId,
        quantityToConsume: quantity,
      );

      await txn.insert(DatabaseTables.stockMovements, {
        'product_id': productId,
        'product_name': prodName,
        'movement_type': 'PURCHASE_RETURN',
        'quantity': -quantity,
        'balance_after': newStock,
        'reference_id': purchaseId,
        'reference_type': 'RETURN',
        'notes': 'Purchase Return for Inv #${purchase.invoiceNumber}: $reason',
        'movement_date': today,
        'created_at': now,
      });

      final totalReturnAmount = quantity * unitPrice;

      await txn.insert(DatabaseTables.returns, {
        'return_type': 'PURCHASE_RETURN',
        'original_invoice_id': purchaseId,
        'original_invoice_number': purchase.invoiceNumber,
        'party_id': purchase.supplierId,
        'party_name': purchase.supplierName,
        'return_date': today,
        'product_id': productId,
        'product_name': prodName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_amount': totalReturnAmount,
        'refund_type': refundType,
        'reason': reason,
        'created_at': now,
      });

      // Update supplier ledger (Debit reduces what we owe the supplier)
      await AccountingService.addSupplierLedgerEntry(
        txn,
        supplierId: purchase.supplierId,
        transactionDate: today,
        transactionType: 'PURCHASE_RETURN',
        referenceId: purchaseId,
        referenceNumber: purchase.invoiceNumber,
        description:
            'Purchase Return ($quantity x $prodName) from Inv #${purchase.invoiceNumber}',
        debit: totalReturnAmount,
        credit: 0.0,
      );
    });
  }
}
