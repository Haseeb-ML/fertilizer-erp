import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fertilizer/core/models/customer.dart';
import 'package:fertilizer/core/models/product.dart';
import 'package:fertilizer/core/repositories/customer_repository.dart';
import 'package:fertilizer/core/repositories/product_repository.dart';
import 'package:fertilizer/core/repositories/sale_repository.dart';
import 'package:fertilizer/features/sales/screens/sales_pos_screen.dart';
import '../test_helper.dart';

void main() {
  late ProductRepository productRepo;
  late CustomerRepository customerRepo;
  late SaleRepository saleRepo;

  setUp(() async {
    await TestHelper.createInMemoryDatabase();
    productRepo = ProductRepository();
    customerRepo = CustomerRepository();
    saleRepo = SaleRepository();

    final now = DateTime.now().toIso8601String();

    // Insert 2 test products
    await productRepo.insertProduct(Product(
      name: 'Kisaan Dairy Gold (Pellet No. 32)',
      sku: 'KF-32-PELLET',
      category: 'Cattle Feed',
      brand: 'Kissan Feeds',
      bagSize: '40 Kg',
      unit: 'Bag',
      purchasePrice: 3000.0,
      sellingPrice: 4325.0,
      openingStock: 50.0,
      currentStock: 50.0,
      createdAt: now,
      updatedAt: now,
    ));

    await productRepo.insertProduct(Product(
      name: 'Urea Sona',
      sku: 'UREA-SONA',
      category: 'Fertilizer',
      brand: 'FFC',
      bagSize: '50 Kg',
      unit: 'Bag',
      purchasePrice: 4000.0,
      sellingPrice: 4938.0,
      openingStock: 100.0,
      currentStock: 100.0,
      createdAt: now,
      updatedAt: now,
    ));

    await customerRepo.insertCustomer(Customer(
      name: 'Haji Aslam',
      phone: '0300-1234567',
      openingBalance: 0.0,
      currentBalance: 0.0,
      createdAt: now,
      updatedAt: now,
    ));
  });

  testWidgets('POS Screen allows adding multiple products, shows stepper, and calculates totals correctly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SalesPosScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial State: Cart is empty
    expect(find.text('Cart is empty'), findsOneWidget);
    expect(find.text('Add Products to Cart'), findsOneWidget);
    expect(find.text('+ Add Product'), findsWidgets);

    // 2. Tap to open product picker from top button
    await tester.tap(find.text('+ Add Product').first);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Product picker modal is open
    expect(find.text('Select Products for Sale'), findsOneWidget);
    expect(find.text('Kisaan Dairy Gold (Pellet No. 32)'), findsOneWidget);
    expect(find.text('Urea Sona'), findsOneWidget);

    // 3. Tap Product 1: Kisaan Dairy Gold
    await tester.tap(find.text('Kisaan Dairy Gold (Pellet No. 32)'));
    await tester.pumpAndSettle();

    // Modal stays open and shows In Cart: 1 Bag
    expect(find.text('In Cart: 1 Bag'), findsOneWidget);
    expect(find.textContaining('1 product(s) in cart'), findsOneWidget);

    // 4. Tap Product 2: Urea Sona (without having to close and reopen modal!)
    await tester.tap(find.text('Urea Sona'));
    await tester.pumpAndSettle();

    expect(find.text('In Cart: 1 Bag'), findsNWidgets(2));
    expect(find.textContaining('2 product(s) in cart'), findsOneWidget);

    // 5. Tap Done button to return to invoice
    await tester.tap(find.textContaining('Done - Continue with 2 Products'));
    await tester.pumpAndSettle();

    // Now on POS screen with 2 products
    expect(find.text('Cart Items (2)'), findsOneWidget);
    expect(find.text('Kisaan Dairy Gold (Pellet No. 32)'), findsOneWidget);
    expect(find.text('Urea Sona'), findsOneWidget);

    // Both products are listed, and "+ Add Another Product" button is visible
    expect(find.text('+ Add Another Product (دوسرا پراڈکٹ شامل کریں)'), findsOneWidget);

    // Total: 4325 + 4938 = 9263
    expect(find.textContaining('9,263'), findsWidgets);

    // 6. Test quick stepper [+] on Kisaan Dairy Gold to increment bags to 2
    final addButtons = find.byIcon(Icons.add);
    // Tap the first stepper add button
    await tester.tap(addButtons.first);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Kisaan Dairy Gold is now 2 bags @ 4325 = 8650, Urea is 1 bag @ 4938 = 4938
    // Total = 8650 + 4938 = 13588
    expect(find.textContaining('13,588'), findsWidgets);

    // 7. Verify "+ Add Another Product" button opens the picker again
    await tester.tap(find.text('+ Add Another Product (دوسرا پراڈکٹ شامل کریں)'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('Select Products for Sale'), findsOneWidget);
    expect(find.text('In Cart: 2 Bag'), findsOneWidget);
    expect(find.text('In Cart: 1 Bag'), findsOneWidget);

    // Close picker
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Cart Items (2)'), findsOneWidget);
  });
}
