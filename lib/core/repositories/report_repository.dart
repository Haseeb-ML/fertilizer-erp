import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/report_models.dart';

class ReportRepository {
  final DatabaseHelper _dbHelper;
  ReportRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<SalesSummaryReport> getSalesSummaryReport({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final cleanFrom = (fromDate != null && fromDate.trim().isNotEmpty)
        ? (fromDate.trim().length > 10 ? fromDate.trim().substring(0, 10) : fromDate.trim())
        : null;
    final cleanTo = (toDate != null && toDate.trim().isNotEmpty)
        ? (toDate.trim().length > 10 ? toDate.trim().substring(0, 10) : toDate.trim())
        : null;

    final whereClauses = <String>['is_reversed = 0'];
    final whereArgs = <dynamic>[];

    if (cleanFrom != null) {
      whereClauses.add('SUBSTR(sale_date, 1, 10) >= ?');
      whereArgs.add(cleanFrom);
    }
    if (cleanTo != null) {
      whereClauses.add('SUBSTR(sale_date, 1, 10) <= ?');
      whereArgs.add(cleanTo);
    }

    final query =
        '''
      SELECT 
        COALESCE(SUM(subtotal), 0) as total_sales,
        COALESCE(SUM(discount), 0) as total_discount,
        COALESCE(SUM(grand_total), 0) as net_sales,
        COALESCE(SUM(paid_amount), 0) as total_paid,
        COALESCE(SUM(balance_due), 0) as total_balance_due,
        COALESCE(SUM(total_cost), 0) as total_cost,
        COALESCE(SUM(gross_profit), 0) as gross_profit,
        COUNT(id) as invoice_count
      FROM ${DatabaseTables.sales}
      WHERE ${whereClauses.join(' AND ')}
    ''';

    final res = await db.rawQuery(query, whereArgs);
    final row = res.first;

    return SalesSummaryReport(
      totalSales: (row['total_sales'] as num?)?.toDouble() ?? 0.0,
      totalDiscount: (row['total_discount'] as num?)?.toDouble() ?? 0.0,
      netSales: (row['net_sales'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (row['total_paid'] as num?)?.toDouble() ?? 0.0,
      totalBalanceDue: (row['total_balance_due'] as num?)?.toDouble() ?? 0.0,
      totalCost: (row['total_cost'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (row['gross_profit'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: (row['invoice_count'] as int?) ?? 0,
    );
  }

  Future<List<ProductSalesReport>> getProductWiseSalesReport({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final cleanFrom = (fromDate != null && fromDate.trim().isNotEmpty)
        ? (fromDate.trim().length > 10 ? fromDate.trim().substring(0, 10) : fromDate.trim())
        : null;
    final cleanTo = (toDate != null && toDate.trim().isNotEmpty)
        ? (toDate.trim().length > 10 ? toDate.trim().substring(0, 10) : toDate.trim())
        : null;

    final whereClauses = <String>['s.is_reversed = 0'];
    final whereArgs = <dynamic>[];

    if (cleanFrom != null) {
      whereClauses.add('SUBSTR(s.sale_date, 1, 10) >= ?');
      whereArgs.add(cleanFrom);
    }
    if (cleanTo != null) {
      whereClauses.add('SUBSTR(s.sale_date, 1, 10) <= ?');
      whereArgs.add(cleanTo);
    }

    final query =
        '''
      SELECT 
        si.product_id,
        si.product_name,
        COALESCE(p.category, 'General') as category,
        COALESCE(SUM(si.quantity), 0) as total_qty,
        COALESCE(SUM(si.total_price), 0) as total_revenue,
        COALESCE(SUM(si.quantity * CASE WHEN si.unit_cost > 0 THEN si.unit_cost WHEN p.purchase_price > 0 THEN p.purchase_price ELSE 0 END), 0) as total_cost,
        COALESCE(SUM(si.total_price - (si.quantity * CASE WHEN si.unit_cost > 0 THEN si.unit_cost WHEN p.purchase_price > 0 THEN p.purchase_price ELSE 0 END)), 0) as profit
      FROM ${DatabaseTables.saleItems} si
      JOIN ${DatabaseTables.sales} s ON si.sale_id = s.id
      LEFT JOIN ${DatabaseTables.products} p ON si.product_id = p.id
      WHERE ${whereClauses.join(' AND ')}
      GROUP BY si.product_id, si.product_name
      ORDER BY total_revenue DESC
    ''';

    final res = await db.rawQuery(query, whereArgs);
    return res.map((row) {
      return ProductSalesReport(
        productId: row['product_id'] as int? ?? 0,
        productName: row['product_name'] as String? ?? '',
        category: row['category'] as String? ?? 'General',
        totalQuantity: (row['total_qty'] as num?)?.toDouble() ?? 0.0,
        totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
        totalCost: (row['total_cost'] as num?)?.toDouble() ?? 0.0,
        profit: (row['profit'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  Future<InventoryValuationReport> getInventoryValuationReport() async {
    final db = await _dbHelper.database;
    final query =
        '''
      SELECT 
        COUNT(id) as total_products,
        COALESCE(SUM(current_stock), 0) as total_quantity,
        COALESCE(SUM(current_stock * purchase_price), 0) as total_cost_value,
        COALESCE(SUM(current_stock * selling_price), 0) as total_retail_value,
        COALESCE(SUM(current_stock * (selling_price - purchase_price)), 0) as potential_profit,
        (SELECT COUNT(id) FROM ${DatabaseTables.products} WHERE is_active = 1 AND current_stock <= min_stock_alert) as low_stock_count
      FROM ${DatabaseTables.products}
      WHERE is_active = 1
    ''';

    final res = await db.rawQuery(query);
    final row = res.first;

    return InventoryValuationReport(
      totalProducts: (row['total_products'] as int?) ?? 0,
      totalStockQuantity: (row['total_quantity'] as num?)?.toDouble() ?? 0.0,
      totalCostValue: (row['total_cost_value'] as num?)?.toDouble() ?? 0.0,
      totalRetailValue: (row['total_retail_value'] as num?)?.toDouble() ?? 0.0,
      potentialProfit: (row['potential_profit'] as num?)?.toDouble() ?? 0.0,
      lowStockCount: (row['low_stock_count'] as int?) ?? 0,
    );
  }

  Future<ProfitLossReport> getProfitLossReport({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final cleanFrom = (fromDate != null && fromDate.trim().isNotEmpty)
        ? (fromDate.trim().length > 10 ? fromDate.trim().substring(0, 10) : fromDate.trim())
        : null;
    final cleanTo = (toDate != null && toDate.trim().isNotEmpty)
        ? (toDate.trim().length > 10 ? toDate.trim().substring(0, 10) : toDate.trim())
        : null;

    final salesWhere = <String>['s.is_reversed = 0'];
    final salesArgs = <dynamic>[];

    if (cleanFrom != null) {
      salesWhere.add('SUBSTR(s.sale_date, 1, 10) >= ?');
      salesArgs.add(cleanFrom);
    }
    if (cleanTo != null) {
      salesWhere.add('SUBSTR(s.sale_date, 1, 10) <= ?');
      salesArgs.add(cleanTo);
    }

    // 1. Total revenue and invoice count
    final salesRes = await db.rawQuery('''
      SELECT 
        COUNT(s.id) as total_invoices,
        COALESCE(SUM(s.grand_total), 0) as total_revenue,
        COALESCE(SUM(s.total_cost), 0) as stored_cogs,
        COALESCE(SUM(s.gross_profit), 0) as stored_gross_profit
      FROM ${DatabaseTables.sales} s
      WHERE ${salesWhere.join(' AND ')}
    ''', salesArgs);

    final totalInvoices = (salesRes.first['total_invoices'] as int?) ?? 0;
    final grossRevenue =
        (salesRes.first['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final storedCogs =
        (salesRes.first['stored_cogs'] as num?)?.toDouble() ?? 0.0;

    // 2. Dynamic COGS from sale items with fallback to product purchase price
    final cogsRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(
          si.quantity * CASE 
            WHEN si.unit_cost > 0 THEN si.unit_cost 
            WHEN p.purchase_price > 0 THEN p.purchase_price 
            ELSE 0 
          END
        ), 0) as item_cogs
      FROM ${DatabaseTables.saleItems} si
      JOIN ${DatabaseTables.sales} s ON si.sale_id = s.id
      LEFT JOIN ${DatabaseTables.products} p ON si.product_id = p.id
      WHERE ${salesWhere.join(' AND ')}
    ''', salesArgs);

    final itemCogs = (cogsRes.first['item_cogs'] as num?)?.toDouble() ?? 0.0;
    final calculatedCogs = itemCogs > 0 ? itemCogs : storedCogs;

    // 3. Sales Returns deduction
    final returnsWhere = <String>["r.return_type = 'SALE_RETURN'"];
    final returnsArgs = <dynamic>[];
    if (cleanFrom != null) {
      returnsWhere.add('SUBSTR(r.return_date, 1, 10) >= ?');
      returnsArgs.add(cleanFrom);
    }
    if (cleanTo != null) {
      returnsWhere.add('SUBSTR(r.return_date, 1, 10) <= ?');
      returnsArgs.add(cleanTo);
    }

    final returnsRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(r.total_amount), 0) as total_returns,
        COALESCE(SUM(
          r.quantity * CASE 
            WHEN p.purchase_price > 0 THEN p.purchase_price 
            ELSE 0 
          END
        ), 0) as returned_cost
      FROM ${DatabaseTables.returns} r
      LEFT JOIN ${DatabaseTables.products} p ON r.product_id = p.id
      WHERE ${returnsWhere.join(' AND ')}
    ''', returnsArgs);

    final totalReturns =
        (returnsRes.first['total_returns'] as num?)?.toDouble() ?? 0.0;
    final returnedCost =
        (returnsRes.first['returned_cost'] as num?)?.toDouble() ?? 0.0;

    final netRevenue = grossRevenue - totalReturns;
    final effectiveCogs =
        (calculatedCogs - returnedCost).clamp(0.0, double.infinity);
    final grossProfit = netRevenue - effectiveCogs;

    // 4. Operating Expenses & Category Breakdown
    final expWhere = <String>[];
    final expArgs = <dynamic>[];
    if (cleanFrom != null) {
      expWhere.add('SUBSTR(expense_date, 1, 10) >= ?');
      expArgs.add(cleanFrom);
    }
    if (cleanTo != null) {
      expWhere.add('SUBSTR(expense_date, 1, 10) <= ?');
      expArgs.add(cleanTo);
    }

    final expWhereClause =
        expWhere.isNotEmpty ? 'WHERE ${expWhere.join(' AND ')}' : '';
    final expRes = await db.rawQuery('''
      SELECT 
        COALESCE(category, 'General') as category,
        COALESCE(SUM(amount), 0) as category_total
      FROM ${DatabaseTables.expenses}
      $expWhereClause
      GROUP BY category
      ORDER BY category_total DESC
    ''', expArgs);

    double totalExpenses = 0.0;
    final expenseList = <Map<String, dynamic>>[];
    for (final row in expRes) {
      final cat = row['category'] as String? ?? 'General';
      final amt = (row['category_total'] as num?)?.toDouble() ?? 0.0;
      totalExpenses += amt;
      expenseList.add({'category': cat, 'amount': amt});
    }

    final expenseBreakdown = expenseList.map((e) {
      final amt = e['amount'] as double;
      final pct = totalExpenses > 0 ? (amt / totalExpenses * 100) : 0.0;
      return ExpenseCategoryBreakdown(
        category: e['category'] as String,
        amount: amt,
        percentage: pct,
      );
    }).toList();

    // 5. Product-wise Profit Breakdown
    final productProfitRes = await db.rawQuery('''
      SELECT 
        si.product_id,
        si.product_name,
        COALESCE(p.category, 'General') as category,
        COALESCE(SUM(si.quantity), 0) as total_qty,
        COALESCE(SUM(si.total_price), 0) as total_rev,
        COALESCE(SUM(
          si.quantity * CASE 
            WHEN si.unit_cost > 0 THEN si.unit_cost 
            WHEN p.purchase_price > 0 THEN p.purchase_price 
            ELSE 0 
          END
        ), 0) as total_cost
      FROM ${DatabaseTables.saleItems} si
      JOIN ${DatabaseTables.sales} s ON si.sale_id = s.id
      LEFT JOIN ${DatabaseTables.products} p ON si.product_id = p.id
      WHERE ${salesWhere.join(' AND ')}
      GROUP BY si.product_id, si.product_name
      ORDER BY total_rev DESC
    ''', salesArgs);

    final productBreakdown = productProfitRes.map((r) {
      final rev = (r['total_rev'] as num?)?.toDouble() ?? 0.0;
      final cost = (r['total_cost'] as num?)?.toDouble() ?? 0.0;
      final profit = rev - cost;
      final margin = rev > 0 ? (profit / rev * 100) : 0.0;
      return ProductProfitBreakdown(
        productId: r['product_id'] as int? ?? 0,
        productName: r['product_name'] as String? ?? '',
        category: r['category'] as String? ?? 'General',
        quantitySold: (r['total_qty'] as num?)?.toDouble() ?? 0.0,
        totalRevenue: rev,
        totalCost: cost,
        grossProfit: profit,
        marginPercent: margin,
      );
    }).toList();

    final netProfit = grossProfit - totalExpenses;
    final grossMarginPct =
        netRevenue > 0 ? (grossProfit / netRevenue * 100) : 0.0;
    final netMarginPct =
        netRevenue > 0 ? (netProfit / netRevenue * 100) : 0.0;

    return ProfitLossReport(
      totalRevenue: grossRevenue,
      totalReturns: totalReturns,
      netRevenue: netRevenue,
      costOfGoodsSold: effectiveCogs,
      grossProfit: grossProfit,
      grossMarginPercent: grossMarginPct,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      netMarginPercent: netMarginPct,
      totalInvoices: totalInvoices,
      expenseBreakdown: expenseBreakdown,
      productBreakdown: productBreakdown,
    );
  }

  Future<List<PartyBalanceReport>> getCustomerOutstandingReport() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT id, name, phone, village_or_address as address, current_balance as balance
      FROM ${DatabaseTables.customers}
      WHERE current_balance > 0 AND is_active = 1
      ORDER BY current_balance DESC
    ''');

    return res
        .map(
          (r) => PartyBalanceReport(
            id: r['id'] as int,
            name: r['name'] as String? ?? '',
            phone: r['phone'] as String? ?? '',
            address: r['address'] as String? ?? '',
            balance: (r['balance'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<PartyBalanceReport>> getSupplierPayableReport() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT id, name, phone, company_or_address as address, current_balance as balance
      FROM ${DatabaseTables.suppliers}
      WHERE current_balance > 0 AND is_active = 1
      ORDER BY current_balance DESC
    ''');

    return res
        .map(
          (r) => PartyBalanceReport(
            id: r['id'] as int,
            name: r['name'] as String? ?? '',
            phone: r['phone'] as String? ?? '',
            address: r['address'] as String? ?? '',
            balance: (r['balance'] as num).toDouble(),
          ),
        )
        .toList();
  }
}
