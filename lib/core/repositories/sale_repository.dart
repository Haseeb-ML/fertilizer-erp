import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../services/accounting_service.dart';
import '../services/fifo_inventory_service.dart';

class SaleRepository {
  final DatabaseHelper _dbHelper;
  SaleRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> generateNextInvoiceNumber() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT id FROM ${DatabaseTables.sales} ORDER BY id DESC LIMIT 1',
    );
    final nextId = res.isEmpty ? 1 : ((res.first['id'] as int) + 1);
    final pad = nextId.toString().padLeft(4, '0');
    final year = DateTime.now().year;
    return 'INV-$year-$pad';
  }

  Future<List<Sale>> getSales({
    String? search,
    int? customerId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (customerId != null) {
      whereClauses.add('customer_id = ?');
      whereArgs.add(customerId);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(invoice_number LIKE ? OR customer_name LIKE ?)');
      final q = '%${search.trim()}%';
      whereArgs.addAll([q, q]);
    }

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('sale_date >= ?');
      whereArgs.add(fromDate);
    }

    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('sale_date <= ?');
      whereArgs.add(toDate);
    }

    final whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;
    final maps = await db.query(
      DatabaseTables.sales,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'id DESC',
    );

    final sales = <Sale>[];
    for (final map in maps) {
      final items = await getSaleItems(map['id'] as int);
      sales.add(Sale.fromMap(map, items: items));
    }
    return sales;
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.sales,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    final items = await getSaleItems(id);
    return Sale.fromMap(maps.first, items: items);
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.saleItems,
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return maps.map((e) => SaleItem.fromMap(e)).toList();
  }

  Future<int> createSale(Sale sale) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final today = sale.saleDate.isNotEmpty
          ? sale.saleDate
          : now.substring(0, 10);

      // Prevent duplicate invoice numbers
      final existing = await txn.query(
        DatabaseTables.sales,
        where: 'invoice_number = ?',
        whereArgs: [sale.invoiceNumber],
      );
      if (existing.isNotEmpty) {
        throw Exception('Invoice number already exists: ${sale.invoiceNumber}');
      }

      // Check stock availability for all items before any writes
      for (final item in sale.items) {
        final prodRows = await txn.query(
          DatabaseTables.products,
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        if (prodRows.isEmpty) {
          throw Exception('Product "${item.productName}" not found');
        }
        final currentStock =
            (prodRows.first['current_stock'] as num?)?.toDouble() ?? 0.0;
        if (currentStock < item.quantity) {
          throw Exception(
            'Insufficient stock for "${item.productName}". Available: $currentStock, Requested: ${item.quantity}',
          );
        }
      }

      // Calculate FIFO Cost of Goods Sold (COGS)
      double totalSaleCost = 0.0;
      final processedItems = <SaleItem>[];

      for (final item in sale.items) {
        final itemCost = await FifoInventoryService.consumeStockFifo(
          txn,
          productId: item.productId,
          quantityToConsume: item.quantity,
        );
        totalSaleCost += itemCost;
        final unitCost = item.quantity > 0 ? (itemCost / item.quantity) : 0.0;
        processedItems.add(item.copyWith(unitCost: unitCost));

        // Deduct stock in products table
        final prodRows = await txn.query(
          DatabaseTables.products,
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        final currentStock = (prodRows.first['current_stock'] as num)
            .toDouble();
        final newStock = currentStock - item.quantity;

        await txn.update(
          DatabaseTables.products,
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        // Record stock movement
        await txn.insert(DatabaseTables.stockMovements, {
          'product_id': item.productId,
          'product_name': item.productName,
          'movement_type': 'SALE',
          'quantity': -item.quantity,
          'balance_after': newStock,
          'reference_id': null, // will update or leave as sale
          'reference_type': 'SALE',
          'notes': 'Sale Inv #${sale.invoiceNumber}',
          'movement_date': today,
          'created_at': now,
        });
      }

      final grossProfit = sale.grandTotal - totalSaleCost;

      final saleMap = sale.toMap();
      saleMap['total_cost'] = totalSaleCost;
      saleMap['gross_profit'] = grossProfit;
      saleMap['created_at'] = now;

      final saleId = await txn.insert(DatabaseTables.sales, saleMap);

      // Insert sale items with unit_cost
      for (final item in processedItems) {
        final itemMap = item.toMap();
        itemMap['sale_id'] = saleId;
        await txn.insert(DatabaseTables.saleItems, itemMap);
      }

      // If customer is selected, update Customer Ledger
      if (sale.customerId != null && sale.customerId! > 0) {
        // 1. Debit the grand total (increases customer receivable)
        await AccountingService.addCustomerLedgerEntry(
          txn,
          customerId: sale.customerId!,
          transactionDate: today,
          transactionType: 'SALE',
          referenceId: saleId,
          referenceNumber: sale.invoiceNumber,
          description: 'Sales Invoice #${sale.invoiceNumber}',
          debit: sale.grandTotal,
          credit: 0.0,
        );

        // 2. If paid amount was received on invoice creation, credit customer ledger
        if (sale.paidAmount > 0) {
          await AccountingService.addCustomerLedgerEntry(
            txn,
            customerId: sale.customerId!,
            transactionDate: today,
            transactionType: 'PAYMENT_RECEIVED',
            referenceId: saleId,
            referenceNumber: sale.invoiceNumber,
            description: 'Cash received on Sale #${sale.invoiceNumber}',
            debit: 0.0,
            credit: sale.paidAmount,
          );
        }
      }

      return saleId;
    });
  }

  Future<void> reverseSale(int saleId, String reason) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final saleRows = await txn.query(
        DatabaseTables.sales,
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (saleRows.isEmpty) throw Exception('Sale not found');
      final sale = Sale.fromMap(saleRows.first);
      if (sale.isReversed) throw Exception('Sale is already reversed');

      final items = await txn.query(
        DatabaseTables.saleItems,
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);

      // Restore stock and FIFO layers
      for (final itemMap in items) {
        final prodId = itemMap['product_id'] as int;
        final qty = (itemMap['quantity'] as num).toDouble();
        final unitCost = (itemMap['unit_cost'] as num?)?.toDouble() ?? 0.0;
        final prodName = itemMap['product_name'] as String;

        final prodRows = await txn.query(
          DatabaseTables.products,
          where: 'id = ?',
          whereArgs: [prodId],
        );
        final currentStock = (prodRows.first['current_stock'] as num)
            .toDouble();
        final newStock = currentStock + qty;

        await txn.update(
          DatabaseTables.products,
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [prodId],
        );

        await FifoInventoryService.restoreStockLayer(
          txn,
          productId: prodId,
          quantity: qty,
          unitCost: unitCost,
          returnDate: today,
        );

        await txn.insert(DatabaseTables.stockMovements, {
          'product_id': prodId,
          'product_name': prodName,
          'movement_type': 'SALE_REVERSAL',
          'quantity': qty,
          'balance_after': newStock,
          'reference_id': saleId,
          'reference_type': 'SALE',
          'notes': 'Reversal of Sale #${sale.invoiceNumber}. Reason: $reason',
          'movement_date': today,
          'created_at': now,
        });
      }

      // Reverse customer ledger entries if customer exists
      if (sale.customerId != null && sale.customerId! > 0) {
        // Credit back the grand total to reduce customer receivable
        await AccountingService.addCustomerLedgerEntry(
          txn,
          customerId: sale.customerId!,
          transactionDate: today,
          transactionType: 'SALE_REVERSAL',
          referenceId: saleId,
          referenceNumber: sale.invoiceNumber,
          description: 'Reversal of Sales Invoice #${sale.invoiceNumber}',
          debit: 0.0,
          credit: sale.grandTotal,
        );

        // If paid amount was recorded, debit it back (or refund)
        if (sale.paidAmount > 0) {
          await AccountingService.addCustomerLedgerEntry(
            txn,
            customerId: sale.customerId!,
            transactionDate: today,
            transactionType: 'SALE_REVERSAL_REFUND',
            referenceId: saleId,
            referenceNumber: sale.invoiceNumber,
            description:
                'Refund against Reversal of Sale #${sale.invoiceNumber}',
            debit: sale.paidAmount,
            credit: 0.0,
          );
        }
      }

      await txn.update(
        DatabaseTables.sales,
        {'is_reversed': 1},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<void> returnSaleItem({
    required int saleId,
    required int productId,
    required double quantity,
    required double unitPrice,
    required double unitCost,
    required String refundType, // LEDGER_ADJUST or CASH_REFUND
    required String reason,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final saleRows = await txn.query(
        DatabaseTables.sales,
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (saleRows.isEmpty) throw Exception('Sale not found');
      final sale = Sale.fromMap(saleRows.first);

      final prodRows = await txn.query(
        DatabaseTables.products,
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (prodRows.isEmpty) throw Exception('Product not found');

      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);
      final prodName = prodRows.first['name'] as String;
      final currentStock = (prodRows.first['current_stock'] as num).toDouble();
      final newStock = currentStock + quantity;

      // Restore product stock
      await txn.update(
        DatabaseTables.products,
        {'current_stock': newStock, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );

      // Restore FIFO layer
      await FifoInventoryService.restoreStockLayer(
        txn,
        productId: productId,
        quantity: quantity,
        unitCost: unitCost,
        returnDate: today,
      );

      // Stock movement
      await txn.insert(DatabaseTables.stockMovements, {
        'product_id': productId,
        'product_name': prodName,
        'movement_type': 'SALE_RETURN',
        'quantity': quantity,
        'balance_after': newStock,
        'reference_id': saleId,
        'reference_type': 'RETURN',
        'notes': 'Sale Return for Inv #${sale.invoiceNumber}: $reason',
        'movement_date': today,
        'created_at': now,
      });

      final totalReturnAmount = quantity * unitPrice;

      await txn.insert(DatabaseTables.returns, {
        'return_type': 'SALE_RETURN',
        'original_invoice_id': saleId,
        'original_invoice_number': sale.invoiceNumber,
        'party_id': sale.customerId ?? 0,
        'party_name': sale.customerName,
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

      // Update customer ledger if customer exists (Credit reduces receivable)
      if (sale.customerId != null && sale.customerId! > 0) {
        await AccountingService.addCustomerLedgerEntry(
          txn,
          customerId: sale.customerId!,
          transactionDate: today,
          transactionType: 'SALE_RETURN',
          referenceId: saleId,
          referenceNumber: sale.invoiceNumber,
          description:
              'Sales Return ($quantity x $prodName) from Inv #${sale.invoiceNumber}',
          debit: 0.0,
          credit: totalReturnAmount,
        );
      }
    });
  }
}
