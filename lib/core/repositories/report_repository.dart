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
    final whereClauses = <String>['is_reversed = 0'];
    final whereArgs = <dynamic>[];

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('sale_date >= ?');
      whereArgs.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('sale_date <= ?');
      whereArgs.add(toDate);
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
    final whereClauses = <String>['s.is_reversed = 0'];
    final whereArgs = <dynamic>[];

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('s.sale_date >= ?');
      whereArgs.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('s.sale_date <= ?');
      whereArgs.add(toDate);
    }

    final query =
        '''
      SELECT 
        si.product_id,
        si.product_name,
        COALESCE(p.category, 'General') as category,
        COALESCE(SUM(si.quantity), 0) as total_qty,
        COALESCE(SUM(si.total_price), 0) as total_revenue,
        COALESCE(SUM(si.quantity * si.unit_cost), 0) as total_cost,
        COALESCE(SUM(si.total_price - (si.quantity * si.unit_cost)), 0) as profit
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
    final salesWhere = <String>['is_reversed = 0'];
    final expWhere = <String>[];
    final salesArgs = <dynamic>[];
    final expArgs = <dynamic>[];

    if (fromDate != null && fromDate.isNotEmpty) {
      salesWhere.add('sale_date >= ?');
      salesArgs.add(fromDate);
      expWhere.add('expense_date >= ?');
      expArgs.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      salesWhere.add('sale_date <= ?');
      salesArgs.add(toDate);
      expWhere.add('expense_date <= ?');
      expArgs.add(toDate);
    }

    final salesRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(grand_total), 0) as revenue,
        COALESCE(SUM(total_cost), 0) as cogs,
        COALESCE(SUM(gross_profit), 0) as gross_profit
      FROM ${DatabaseTables.sales}
      WHERE ${salesWhere.join(' AND ')}
    ''', salesArgs);

    final expQuery = expWhere.isNotEmpty
        ? 'WHERE ${expWhere.join(' AND ')}'
        : '';
    final expRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total_expenses
      FROM ${DatabaseTables.expenses}
      $expQuery
    ''', expArgs);

    final revenue = (salesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
    final cogs = (salesRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
    final grossProfit =
        (salesRes.first['gross_profit'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (expRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final netProfit = grossProfit - totalExpenses;

    return ProfitLossReport(
      totalRevenue: revenue,
      costOfGoodsSold: cogs,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
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
