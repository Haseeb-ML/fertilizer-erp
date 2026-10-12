import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fertilizer/core/database/database_helper.dart';
import 'package:fertilizer/core/models/product.dart';
import 'package:fertilizer/core/models/customer.dart';
import 'package:fertilizer/core/models/supplier.dart';
import 'package:fertilizer/core/repositories/product_repository.dart';
import 'package:fertilizer/core/repositories/customer_repository.dart';
import 'package:fertilizer/core/repositories/supplier_repository.dart';
import '../test_helper.dart';

void main() {
  late Database db;
  late ProductRepository productRepo;
  late CustomerRepository customerRepo;
  late SupplierRepository supplierRepo;

  setUp(() async {
    db = await TestHelper.createInMemoryDatabase();
    productRepo = ProductRepository(DatabaseHelper.instance);
    customerRepo = CustomerRepository(DatabaseHelper.instance);
    supplierRepo = SupplierRepository(DatabaseHelper.instance);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('Database Tests - CRUD & Persistence', () {
    test(
      'Product insertion with opening stock creates product and stock movement',
      () async {
        final now = DateTime.now().toIso8601String();
        final product = Product(
          name: 'Sona Urea (FFC)',
          sku: 'UREA-01',
          category: 'Urea',
          brand: 'FFC',
          bagSize: '50 Kg',
          unit: 'Bag',
          purchasePrice: 4500,
          sellingPrice: 4800,
          openingStock: 100,
          minStockAlert: 20,
          createdAt: now,
          updatedAt: now,
        );

        final id = await productRepo.insertProduct(product);
        expect(id, greaterThan(0));

        final fetched = await productRepo.getProductById(id);
        expect(fetched, isNotNull);
        expect(fetched!.name, 'Sona Urea (FFC)');
        expect(fetched.currentStock, 100.0);
        expect(fetched.inventoryValuation, 450000.0);

        // Verify stock movement
        final movements = await productRepo.getStockMovements(id);
        expect(movements.length, 1);
        expect(movements.first.movementType, 'OPENING_STOCK');
        expect(movements.first.quantity, 100.0);
      },
    );

    test(
      'Stock adjustments (correction/damaged) update current stock correctly',
      () async {
        final now = DateTime.now().toIso8601String();
        final prodId = await productRepo.insertProduct(
          Product(
            name: 'Engro DAP',
            sku: 'DAP-01',
            category: 'DAP (Di-Ammonium Phosphate)',
            brand: 'Engro Fertilizers',
            purchasePrice: 9000,
            sellingPrice: 9500,
            openingStock: 50,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Deduct 2 damaged bags
        await productRepo.adjustStock(
          productId: prodId,
          adjustmentQuantity: -2,
          reason: 'Damaged / Burst Bags',
          notes: 'Burst during unloading',
        );

        final updated = await productRepo.getProductById(prodId);
        expect(updated!.currentStock, 48.0);

        final movements = await productRepo.getStockMovements(prodId);
        expect(movements.length, 2);
        expect(movements.first.movementType, 'ADJUSTMENT_OUT');
        expect(movements.first.quantity, -2.0);
      },
    );

    test(
      'Customer insertion with opening balance records opening ledger entry',
      () async {
        final now = DateTime.now().toIso8601String();
        final custId = await customerRepo.insertCustomer(
          Customer(
            name: 'Chaudhry Rashid',
            phone: '0300-9876543',
            villageOrAddress: 'Chak 15-WB',
            openingBalance: 75000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(custId, greaterThan(0));
        final customer = await customerRepo.getCustomerById(custId);
        expect(customer!.currentBalance, 75000.0);

        final ledger = await customerRepo.getCustomerLedger(custId);
        expect(ledger.length, 1);
        expect(ledger.first.transactionType, 'OPENING_BALANCE');
        expect(ledger.first.runningBalance, 75000.0);
      },
    );

    test(
      'Supplier insertion with opening balance records opening ledger entry',
      () async {
        final now = DateTime.now().toIso8601String();
        final suppId = await supplierRepo.insertSupplier(
          Supplier(
            name: 'Fatima Fertilizer Regional Agency',
            phone: '0301-5555555',
            companyOrAddress: 'Multan Industrial Estate',
            openingBalance: 200000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(suppId, greaterThan(0));
        final supplier = await supplierRepo.getSupplierById(suppId);
        expect(supplier!.currentBalance, 200000.0);

        final ledger = await supplierRepo.getSupplierLedger(suppId);
        expect(ledger.length, 1);
        expect(ledger.first.transactionType, 'OPENING_BALANCE');
        expect(ledger.first.runningBalance, 200000.0);
      },
    );
  });
}
