import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/purchase.dart';
import '../../../core/utils/date_formatter.dart';

class DashboardData {
  final double todaySales;
  final double todayPurchases;
  final double todayExpenses;
  final double cashBalance;
  final double customerReceivables;
  final double supplierPayables;
  final double totalStockQuantity;
  final double inventoryValuation;
  final int totalStorages;
  final Map<String, double> storageBagsBreakdown;
  final List<Product> lowStockProducts;
  final List<Sale> recentSales;
  final List<Purchase> recentPurchases;
  final String dateFilterLabel;

  DashboardData({
    required this.todaySales,
    required this.todayPurchases,
    required this.todayExpenses,
    required this.cashBalance,
    required this.customerReceivables,
    required this.supplierPayables,
    required this.totalStockQuantity,
    required this.inventoryValuation,
    this.totalStorages = 0,
    this.storageBagsBreakdown = const {},
    required this.lowStockProducts,
    required this.recentSales,
    required this.recentPurchases,
    required this.dateFilterLabel,
  });
}

enum DashboardFilter { today, thisWeek, thisMonth, allTime }

final dashboardFilterProvider = StateProvider<DashboardFilter>(
  (ref) => DashboardFilter.today,
);

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final filter = ref.watch(dashboardFilterProvider);
  final saleRepo = ref.watch(saleRepoProvider);
  final purchaseRepo = ref.watch(purchaseRepoProvider);
  final expenseRepo = ref.watch(expenseRepoProvider);
  final customerRepo = ref.watch(customerRepoProvider);
  final supplierRepo = ref.watch(supplierRepoProvider);
  final productRepo = ref.watch(productRepoProvider);
  final cashbookRepo = ref.watch(cashbookRepoProvider);

  final now = DateTime.now();
  String? fromDate;
  String? toDate = DateFormatter.toSqlDate(now);
  String label = "Today's Overview";

  switch (filter) {
    case DashboardFilter.today:
      fromDate = DateFormatter.toSqlDate(now);
      label = "Today's Overview";
      break;
    case DashboardFilter.thisWeek:
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      fromDate = DateFormatter.toSqlDate(startOfWeek);
      label = "This Week's Overview";
      break;
    case DashboardFilter.thisMonth:
      final startOfMonth = DateTime(now.year, now.month, 1);
      fromDate = DateFormatter.toSqlDate(startOfMonth);
      label = "This Month's Overview";
      break;
    case DashboardFilter.allTime:
      fromDate = null;
      toDate = null;
      label = "All-Time Overview";
      break;
  }

  // 1. Sales
  final sales = await saleRepo.getSales(fromDate: fromDate, toDate: toDate);
  final double totalSales = sales.fold(
    0.0,
    (acc, s) => acc + (s.isReversed ? 0.0 : s.grandTotal),
  );

  // 2. Purchases
  final purchases = await purchaseRepo.getPurchases(
    fromDate: fromDate,
    toDate: toDate,
  );
  final double totalPurchases = purchases.fold(
    0.0,
    (acc, p) => acc + (p.isReversed ? 0.0 : p.grandTotal),
  );

  // 3. Expenses
  final expenses = await expenseRepo.getExpenses(
    fromDate: fromDate,
    toDate: toDate,
  );
  final double totalExpenses = expenses.fold(0.0, (acc, e) => acc + e.amount);

  // 4. Receivables & Payables & Cash & Stock
  final customerReceivables = await customerRepo.getTotalReceivables();
  final supplierPayables = await supplierRepo.getTotalPayables();
  final cashBalance = await cashbookRepo.getCurrentCashBalance();
  final totalStockQty = await productRepo.getTotalStockQuantity();
  final inventoryValuation = await productRepo.getInventoryValuation();

  // 4b. Storages
  final storageRepo = ref.watch(storageRepoProvider);
  final storages = await storageRepo.getStorages(onlyActive: true);
  final totalStorages = storages.length;
  final Map<String, double> storageBreakdown = {};
  for (final s in storages) {
    if (s.id != null) {
      final qty = await storageRepo.getTotalStorageQuantity(s.id!);
      storageBreakdown[s.name] = qty;
    }
  }

  // 5. Low stock alerts
  final lowStockProducts = await productRepo.getProducts(
    onlyActive: true,
    onlyLowStock: true,
  );

  // 6. Recent sales & purchases (latest 5)
  final allSales = await saleRepo.getSales();
  final recentSales = allSales.take(5).toList();

  final allPurchases = await purchaseRepo.getPurchases();
  final recentPurchases = allPurchases.take(5).toList();

  return DashboardData(
    todaySales: totalSales,
    todayPurchases: totalPurchases,
    todayExpenses: totalExpenses,
    cashBalance: cashBalance,
    customerReceivables: customerReceivables,
    supplierPayables: supplierPayables,
    totalStockQuantity: totalStockQty,
    inventoryValuation: inventoryValuation,
    totalStorages: totalStorages,
    storageBagsBreakdown: storageBreakdown,
    lowStockProducts: lowStockProducts,
    recentSales: recentSales,
    recentPurchases: recentPurchases,
    dateFilterLabel: label,
  );
});
