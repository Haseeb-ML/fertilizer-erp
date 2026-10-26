import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../repositories/product_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/cashbook_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/storage_repository.dart';
import '../models/business_settings.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final productRepoProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseHelperProvider));
});

final customerRepoProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(databaseHelperProvider));
});

final supplierRepoProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(databaseHelperProvider));
});

final purchaseRepoProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(databaseHelperProvider));
});

final saleRepoProvider = Provider<SaleRepository>((ref) {
  return SaleRepository(ref.watch(databaseHelperProvider));
});

final paymentRepoProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(databaseHelperProvider));
});

final expenseRepoProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(databaseHelperProvider));
});

final cashbookRepoProvider = Provider<CashbookRepository>((ref) {
  return CashbookRepository(ref.watch(databaseHelperProvider));
});

final reportRepoProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(databaseHelperProvider));
});

final settingsRepoProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseHelperProvider));
});

final storageRepoProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(ref.watch(databaseHelperProvider));
});

// Settings notifier for live updates
final businessSettingsProvider = FutureProvider<BusinessSettings>((ref) async {
  final repo = ref.watch(settingsRepoProvider);
  return await repo.getSettings();
});

/// Reactive signal to notify screens when sales data has changed
final salesUpdateTriggerProvider = StateProvider<int>((ref) => 0);

/// Reactive signal to notify screens when products or stock data has changed
final productsUpdateTriggerProvider = StateProvider<int>((ref) => 0);

/// Reactive signal to notify screens when storage data or transfers have changed
final storagesUpdateTriggerProvider = StateProvider<int>((ref) => 0);

