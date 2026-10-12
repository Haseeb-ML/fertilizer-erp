import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fertilizer/core/database/database_helper.dart';
import 'package:fertilizer/core/widgets/kpi_card.dart';
import 'package:fertilizer/core/widgets/status_badge.dart';
import 'package:fertilizer/features/dashboard/controllers/dashboard_controller.dart';
import 'package:fertilizer/features/navigation/main_navigation_screen.dart';
import '../test_helper.dart';

import 'package:fertilizer/core/models/business_settings.dart';
import 'package:fertilizer/core/models/product.dart';
import 'package:fertilizer/core/models/sale.dart';
import 'package:fertilizer/core/providers/app_providers.dart';
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
  final sampleSettings = BusinessSettings(
    id: 1,
    businessName: 'Al-Madina Fertilizer Agency',
    ownerName: 'Haji Muhammad Aslam',
    phone: '0300-1234567',
    address: 'Galla Mandi Road',
    city: 'Multan',
    updatedAt: DateTime.now().toIso8601String(),
  );

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

  setUp(() async {
    await TestHelper.createInMemoryDatabase();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.setMockDatabase(null);
  });

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        businessSettingsProvider.overrideWith(
          (ref) => Future.value(sampleSettings),
        ),
        dashboardDataProvider.overrideWith((ref) => Future.value(sampleData)),
        productRepoProvider.overrideWithValue(FakeProductRepository()),
        saleRepoProvider.overrideWithValue(FakeSaleRepository()),
      ],
      child: const MaterialApp(home: MainNavigationScreen()),
    );
  }

  group('Responsive UI & Multi-Screen Tests', () {
    testWidgets(
      'Responsive Dashboard renders without overflow at Small Phone (320x640)',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify Dashboard appears and bottom navigation has 4 items
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.text('Dashboard'), findsWidgets);
        expect(find.text('Sales'), findsWidgets);
        expect(find.text('Inventory'), findsWidgets);
        expect(find.text('More'), findsWidgets);
        expect(find.text('Quick Actions'), findsOneWidget);

        // Verify no overflow errors
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Responsive Dashboard renders correctly at Standard Phone (380x800)',
      (tester) async {
        tester.view.physicalSize = const Size(380 * 2.0, 800 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Quick Actions'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Responsive Dashboard renders in Landscape orientation (800x400)',
      (tester) async {
        tester.view.physicalSize = const Size(800 * 2.0, 400 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Quick Actions'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Navigation bar navigates between Dashboard, Sales, Inventory and More',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap on Sales tab (index 1)
        await tester.tap(find.text('Sales').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Sales & Invoices'), findsOneWidget);

        // Tap on Inventory tab (index 2)
        await tester.tap(find.text('Inventory').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Inventory & Products'), findsOneWidget);

        // Tap on More tab (index 3)
        await tester.tap(find.text('More').last);
        await tester.pump();
        expect(find.text('ERP Business Modules'), findsOneWidget);
        expect(find.text('SHEIKH UZAIR & CO'), findsOneWidget);
        expect(find.text('Purchase Management'), findsOneWidget);
      },
    );

    testWidgets(
      'KpiCard handles long values with FittedBox and does not overflow',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 140,
                height: 120,
                child: KpiCard(
                  title: 'Customer Receivables',
                  value: '₨ 99,999,999',
                  icon: Icons.people,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('₨ 99,999,999'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('StatusBadge displays correct badge colors and labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(label: 'PAID', isSuccess: true),
                StatusBadge(label: 'PARTIAL', isWarning: true),
                StatusBadge(label: 'UNPAID', isDanger: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('PARTIAL'), findsOneWidget);
      expect(find.text('UNPAID'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
