import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fertilizer/app.dart';
import 'package:fertilizer/core/database/database_helper.dart';
import 'package:fertilizer/core/models/business_settings.dart';
import 'package:fertilizer/core/providers/app_providers.dart';
import 'package:fertilizer/features/dashboard/controllers/dashboard_controller.dart';
import 'test_helper.dart';

import 'package:fertilizer/core/models/product.dart';
import 'package:fertilizer/core/models/sale.dart';
import 'package:fertilizer/core/repositories/product_repository.dart';
import 'package:fertilizer/core/repositories/sale_repository.dart';

class FakeProductRepository extends Fake implements ProductRepository {
  @override
  Future<List<Product>> getProducts({
    String? search,
    String? category,
    bool? onlyActive,
    bool? onlyLowStock,
  }) async {
    return [];
  }
}

class FakeSaleRepository extends Fake implements SaleRepository {
  @override
  Future<List<Sale>> getSales({
    String? search,
    int? customerId,
    String? fromDate,
    String? toDate,
  }) async {
    return [];
  }
}

void main() {
  final sampleData = DashboardData(
    todaySales: 150000,
    todayPurchases: 90000,
    todayExpenses: 12000,
    cashBalance: 48000,
    customerReceivables: 320000,
    supplierPayables: 180000,
    totalStockQuantity: 450,
    inventoryValuation: 2025000,
    lowStockProducts: [],
    recentSales: [],
    recentPurchases: [],
    dateFilterLabel: "Today's Overview",
  );

  final sampleSettings = BusinessSettings(
    id: 1,
    businessName: 'Fertilizer Business Agency',
    ownerName: 'Owner',
    phone: '0300-1234567',
    address: 'Mandi Road',
    city: 'Multan',
    updatedAt: DateTime.now().toIso8601String(),
  );

  setUp(() async {
    await TestHelper.createInMemoryDatabase();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.setMockDatabase(null);
  });

  testWidgets('App smoke test launches FertilizerApp successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessSettingsProvider.overrideWith(
            (ref) => Future.value(sampleSettings),
          ),
          dashboardDataProvider.overrideWith((ref) => Future.value(sampleData)),
          productRepoProvider.overrideWithValue(FakeProductRepository()),
          saleRepoProvider.overrideWithValue(FakeSaleRepository()),
        ],
        child: const FertilizerApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify main app launches and shows dashboard
    expect(find.byType(FertilizerApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
