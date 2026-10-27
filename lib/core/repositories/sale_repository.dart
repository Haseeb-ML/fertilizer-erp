import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../services/accounting_service.dart';
import '../services/fifo_inventory_service.dart';
import 'customer_repository.dart';

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

  Future<Sale?> getSaleByInvoiceNumber(String invoiceNumber) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.sales,
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
    );
    if (maps.isEmpty) return null;
    final items = await getSaleItems(maps.first['id'] as int);
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
        final itemsDetailedSummary = sale.items.map((i) {
          final qty = i.quantity == i.quantity.roundToDouble()
              ? i.quantity.toInt().toString()
              : i.quantity.toString();
          final rate = i.unitPrice == i.unitPrice.roundToDouble()
              ? i.unitPrice.toInt().toString()
              : i.unitPrice.toStringAsFixed(0);
          return '$qty ${i.unit} ${i.productName} @ ₨$rate';
        }).join(', ');

        final transactionType = sale.balanceDue <= 0
            ? 'CASH_SALE'
            : (sale.paidAmount > 0 ? 'PARTIAL_SALE' : 'CREDIT_SALE');

        final typeLabel = sale.balanceDue <= 0
            ? 'Cash Sale'
            : (sale.paidAmount > 0 ? 'Partial Credit Sale' : 'Credit Sale');

        final desc = itemsDetailedSummary.isNotEmpty
            ? '$typeLabel #${sale.invoiceNumber} ($itemsDetailedSummary)'
            : 'Sales Invoice #${sale.invoiceNumber}';

        // 1. Debit the grand total (increases customer receivable)
        await AccountingService.addCustomerLedgerEntry(
          txn,
          customerId: sale.customerId!,
          transactionDate: today,
          transactionType: transactionType,
          referenceId: saleId,
          referenceNumber: sale.invoiceNumber,
          description: desc,
          debit: sale.grandTotal,
          credit: 0.0,
        );

        // 2. If paid amount was received on invoice creation, credit customer ledger & record payment
        if (sale.paidAmount > 0) {
          final paymentId = await txn.insert(DatabaseTables.payments, {
            'payment_type': 'CUSTOMER_PAYMENT',
            'party_type': 'Customer',
            'party_id': sale.customerId!,
            'party_name': sale.customerName,
            'reference_invoice_id': saleId,
            'reference_invoice_number': sale.invoiceNumber,
            'amount': sale.paidAmount,
            'payment_date': today,
            'payment_method': sale.paymentMethod,
            'reference_number': sale.invoiceNumber,
            'notes':
                'Payment received on ${sale.paymentMethod} Sale #${sale.invoiceNumber}',
            'created_at': now,
          });

          await AccountingService.addCustomerLedgerEntry(
            txn,
            customerId: sale.customerId!,
            transactionDate: today,
            transactionType: 'PAYMENT_RECEIVED',
            referenceId: paymentId,
            referenceNumber: sale.invoiceNumber,
            description:
                'Payment Received (${sale.paymentMethod}) on Sale #${sale.invoiceNumber}',
            debit: 0.0,
            credit: sale.paidAmount,
          );
        }
      }

      return saleId;
    });
  }

  /// Edits an existing (non-reversed) sale: items, rates, discount, paid
  /// amount, method, date and notes. Customer & invoice number stay the same.
  Future<void> updateSale(Sale sale) async {
    final saleId = sale.id;
    if (saleId == null) throw Exception('Sale id required');
    if (sale.items.isEmpty) throw Exception('Bill must have at least 1 item');
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final oldRows = await txn.query(
        DatabaseTables.sales,
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (oldRows.isEmpty) throw Exception('Sale not found');
      final old = Sale.fromMap(oldRows.first);
      if (old.isReversed) throw Exception('Reversed bill cannot be edited');

      final invoice = old.invoiceNumber;
      final customerId = old.customerId;
      final now = DateTime.now().toIso8601String();
      final today = sale.saleDate.isNotEmpty
          ? sale.saleDate
          : now.substring(0, 10);

      // 1. Restore old stock
      final oldItems = await txn.query(
        DatabaseTables.saleItems,
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      for (final m in oldItems) {
        final prodId = m['product_id'] as int;
        final qty = (m['quantity'] as num).toDouble();
        final unitCost = (m['unit_cost'] as num?)?.toDouble() ?? 0.0;
        final prodRows = await txn.query(
          DatabaseTables.products,
          where: 'id = ?',
          whereArgs: [prodId],
        );
        if (prodRows.isEmpty) continue;
        final newStock =
            ((prodRows.first['current_stock'] as num?)?.toDouble() ?? 0.0) +
            qty;
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
          'product_name': m['product_name'],
          'movement_type': 'SALE_EDIT_RESTORE',
          'quantity': qty,
          'balance_after': newStock,
          'reference_id': saleId,
          'reference_type': 'SALE',
          'notes': 'Bill edit - stock restored Inv #$invoice',
          'movement_date': today,
          'created_at': now,
        });
      }
      await txn.delete(
        DatabaseTables.saleItems,
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      // 2. Validate & consume new items
      double totalSaleCost = 0.0;
      final processedItems = <SaleItem>[];
      for (final item in sale.items) {
        final prodRows = await txn.query(
          DatabaseTables.products,
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        if (prodRows.isEmpty) {
          throw Exception('Product "${item.productName}" not found');
        }
        final stock =
            (prodRows.first['current_stock'] as num?)?.toDouble() ?? 0.0;
        if (stock < item.quantity) {
          throw Exception(
            'Insufficient stock for "${item.productName}". Available: $stock, Requested: ${item.quantity}',
          );
        }
        final itemCost = await FifoInventoryService.consumeStockFifo(
          txn,
          productId: item.productId,
          quantityToConsume: item.quantity,
        );
        totalSaleCost += itemCost;
        final unitCost = item.quantity > 0 ? (itemCost / item.quantity) : 0.0;
        processedItems.add(item.copyWith(unitCost: unitCost));
        final newStock = stock - item.quantity;
        await txn.update(
          DatabaseTables.products,
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        await txn.insert(DatabaseTables.stockMovements, {
          'product_id': item.productId,
          'product_name': item.productName,
          'movement_type': 'SALE',
          'quantity': -item.quantity,
          'balance_after': newStock,
          'reference_id': saleId,
          'reference_type': 'SALE',
          'notes': 'Sale Inv #$invoice (edited)',
          'movement_date': today,
          'created_at': now,
        });
      }

      // 3. Update sale row
      final saleMap = sale.toMap();
      saleMap.remove('id');
      saleMap['invoice_number'] = invoice;
      saleMap['customer_id'] = old.customerId;
      saleMap['customer_name'] = old.customerName;
      saleMap['sale_date'] = today;
      saleMap['total_cost'] = totalSaleCost;
      saleMap['gross_profit'] = sale.grandTotal - totalSaleCost;
      saleMap['is_reversed'] = 0;
      saleMap['created_at'] = oldRows.first['created_at'];
      await txn.update(
        DatabaseTables.sales,
        saleMap,
        where: 'id = ?',
        whereArgs: [saleId],
      );
      for (final item in processedItems) {
        final itemMap = item.toMap();
        itemMap.remove('id');
        itemMap['sale_id'] = saleId;
        await txn.insert(DatabaseTables.saleItems, itemMap);
      }

      // 4. Rewrite ledger + payment rows
      if (customerId != null && customerId > 0) {
        final payRows = await txn.query(
          DatabaseTables.payments,
          columns: ['id'],
          where: "reference_invoice_id = ? AND payment_type = 'CUSTOMER_PAYMENT'",
          whereArgs: [saleId],
        );
        final payIds = payRows.map((e) => e['id'] as int).toList();
        await txn.delete(
          DatabaseTables.customerLedger,
          where:
              "customer_id = ? AND reference_number = ? AND transaction_type IN ('CASH_SALE','PARTIAL_SALE','CREDIT_SALE','SALE')",
          whereArgs: [customerId, invoice],
        );
        final payIdList = [...payIds, saleId];
        await txn.delete(
          DatabaseTables.customerLedger,
          where:
              "customer_id = ? AND transaction_type = 'PAYMENT_RECEIVED' AND reference_id IN (${payIdList.map((_) => '?').join(',')}) AND reference_number = ?",
          whereArgs: [customerId, ...payIdList, invoice],
        );
        await txn.delete(
          DatabaseTables.payments,
          where: "reference_invoice_id = ? AND payment_type = 'CUSTOMER_PAYMENT'",
          whereArgs: [saleId],
        );

        final summary = sale.items.map((i) {
          final qty = i.quantity == i.quantity.roundToDouble()
              ? i.quantity.toInt().toString()
              : i.quantity.toString();
          final rate = i.unitPrice == i.unitPrice.roundToDouble()
              ? i.unitPrice.toInt().toString()
              : i.unitPrice.toStringAsFixed(0);
          return '$qty ${i.unit} ${i.productName} @ ₨$rate';
        }).join(', ');
        final type = sale.balanceDue <= 0
            ? 'CASH_SALE'
            : (sale.paidAmount > 0 ? 'PARTIAL_SALE' : 'CREDIT_SALE');
        final label = sale.balanceDue <= 0
            ? 'Cash Sale'
            : (sale.paidAmount > 0 ? 'Partial Credit Sale' : 'Credit Sale');
        await AccountingService.addCustomerLedgerEntry(
          txn,
          customerId: customerId,
          transactionDate: today,
          transactionType: type,
          referenceId: saleId,
          referenceNumber: invoice,
          description: '$label #$invoice ($summary)',
          debit: sale.grandTotal,
          credit: 0.0,
        );
        if (sale.paidAmount > 0) {
          final paymentId = await txn.insert(DatabaseTables.payments, {
            'payment_type': 'CUSTOMER_PAYMENT',
            'party_type': 'Customer',
            'party_id': customerId,
            'party_name': old.customerName,
            'reference_invoice_id': saleId,
            'reference_invoice_number': invoice,
            'amount': sale.paidAmount,
            'payment_date': today,
            'payment_method': sale.paymentMethod,
            'reference_number': invoice,
            'notes':
                'Payment received on ${sale.paymentMethod} Sale #$invoice',
            'created_at': now,
          });
          await AccountingService.addCustomerLedgerEntry(
            txn,
            customerId: customerId,
            transactionDate: today,
            transactionType: 'PAYMENT_RECEIVED',
            referenceId: paymentId,
            referenceNumber: invoice,
            description:
                'Payment Received (${sale.paymentMethod}) on Sale #$invoice',
            debit: 0.0,
            credit: sale.paidAmount,
          );
        }
        await CustomerRepository.reconcileCustomerLedger(txn, customerId);
      }
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

  /// Recalculates total_cost and gross_profit for a specific sale
  Future<void> recalculateSaleProfit(int saleId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await recalculateSingleSale(txn, saleId);
    });
  }

  /// Helper to recalculate a single sale's cost and profit
  static Future<void> recalculateSingleSale(
    DatabaseExecutor db,
    int saleId,
  ) async {
    final saleRows = await db.query(
      DatabaseTables.sales,
      where: 'id = ?',
      whereArgs: [saleId],
    );
    if (saleRows.isEmpty) return;
    final saleMap = saleRows.first;
    final grandTotal = (saleMap['grand_total'] as num?)?.toDouble() ?? 0.0;

    final items = await db.query(
      DatabaseTables.saleItems,
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );

    double totalCost = 0.0;
    for (final item in items) {
      final itemId = item['id'] as int;
      final productId = item['product_id'] as int;
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      double unitCost = (item['unit_cost'] as num?)?.toDouble() ?? 0.0;

      final prodRows = await db.query(
        DatabaseTables.products,
        columns: ['purchase_price'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      final productPurchasePrice = prodRows.isNotEmpty
          ? ((prodRows.first['purchase_price'] as num?)?.toDouble() ?? 0.0)
          : 0.0;

      final purchaseCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM ${DatabaseTables.purchaseItems} WHERE product_id = ?',
              [productId],
            ),
          ) ??
          0;

      // If no purchases exist, all stock was from opening stock -> use current purchase_price
      if (purchaseCount == 0 && productPurchasePrice > 0) {
        unitCost = productPurchasePrice;
        await db.update(
          DatabaseTables.saleItems,
          {'unit_cost': unitCost},
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }

      totalCost += qty * unitCost;
    }

    final grossProfit = grandTotal - totalCost;
    await db.update(
      DatabaseTables.sales,
      {'total_cost': totalCost, 'gross_profit': grossProfit},
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }

  /// Helper to recalculate all sales profits across the database
  static Future<void> recalculateAllSalesProfits(DatabaseExecutor db) async {
    final sales = await db.query(DatabaseTables.sales, columns: ['id']);
    for (final s in sales) {
      final saleId = s['id'] as int;
      await recalculateSingleSale(db, saleId);
    }
  }
}
