import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fertilizer/core/database/database_helper.dart';
import 'package:fertilizer/core/models/product.dart';
import 'package:fertilizer/core/models/sale.dart';
import 'package:fertilizer/core/models/sale_item.dart';
import 'package:fertilizer/core/repositories/product_repository.dart';
import 'package:fertilizer/core/repositories/sale_repository.dart';
import 'package:fertilizer/core/services/backup_service.dart';
import '../test_helper.dart';

void main() {
  late Database db;
  late ProductRepository productRepo;
  late SaleRepository saleRepo;

  setUp(() async {
    db = await TestHelper.createInMemoryDatabase();
    productRepo = ProductRepository(DatabaseHelper.instance);
    saleRepo = SaleRepository(DatabaseHelper.instance);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('Failure & Edge Case Tests', () {
    test(
      'Sale quantity exceeding available stock throws exception and protects stock',
      () async {
        final now = DateTime.now().toIso8601String();
        final prodId = await productRepo.insertProduct(
          Product(
            name: 'Limited Stock Urea',
            sku: 'LTD-01',
            category: 'Urea',
            brand: 'FFC',
            purchasePrice: 4500,
            sellingPrice: 4800,
            openingStock: 10, // only 10 available
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Attempt to sell 15 bags (exceeds 10)
        final sale = Sale(
          invoiceNumber: 'INV-OVER-001',
          customerName: 'Test Buyer',
          saleDate: now.substring(0, 10),
          subtotal: 72000,
          grandTotal: 72000,
          paidAmount: 72000,
          balanceDue: 0,
          paymentStatus: 'PAID',
          paymentMethod: 'Cash',
          createdAt: now,
          items: [
            SaleItem(
              productId: prodId,
              productName: 'Limited Stock Urea',
              unit: 'Bag',
              quantity: 15,
              unitPrice: 4800,
              totalPrice: 72000,
            ),
          ],
        );

        expect(() => saleRepo.createSale(sale), throwsException);

        // Verify stock remained unchanged at 10
        final prod = await productRepo.getProductById(prodId);
        expect(prod!.currentStock, 10.0);
      },
    );

    test(
      'Duplicate sales invoice number is prevented by database constraint',
      () async {
        final now = DateTime.now().toIso8601String();
        final prodId = await productRepo.insertProduct(
          Product(
            name: 'Test Product',
            sku: 'DUP-01',
            category: 'Urea',
            brand: 'FFC',
            purchasePrice: 4500,
            sellingPrice: 4800,
            openingStock: 50,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final sale1 = Sale(
          invoiceNumber: 'INV-SAME-001',
          customerName: 'Buyer 1',
          saleDate: now.substring(0, 10),
          subtotal: 4800,
          grandTotal: 4800,
          paidAmount: 4800,
          balanceDue: 0,
          paymentStatus: 'PAID',
          paymentMethod: 'Cash',
          createdAt: now,
          items: [
            SaleItem(
              productId: prodId,
              productName: 'Test Product',
              unit: 'Bag',
              quantity: 1,
              unitPrice: 4800,
              totalPrice: 4800,
            ),
          ],
        );
        await saleRepo.createSale(sale1);

        // Attempt same invoice number
        final sale2 = Sale(
          invoiceNumber: 'INV-SAME-001', // duplicate!
          customerName: 'Buyer 2',
          saleDate: now.substring(0, 10),
          subtotal: 4800,
          grandTotal: 4800,
          paidAmount: 4800,
          balanceDue: 0,
          paymentStatus: 'PAID',
          paymentMethod: 'Cash',
          createdAt: now,
          items: [
            SaleItem(
              productId: prodId,
              productName: 'Test Product',
              unit: 'Bag',
              quantity: 1,
              unitPrice: 4800,
              totalPrice: 4800,
            ),
          ],
        );

        expect(() => saleRepo.createSale(sale2), throwsException);
      },
    );

    test('Corrupt backup JSON is rejected with meaningful error', () {
      const corruptJson = '{"schema_version": 1, "corrupted_incomplete": ...';
      expect(
        () => BackupService.validateBackupData(corruptJson),
        throwsException,
      );

      const invalidSchemaJson = '{"schema_version": 999, "tables": {}}';
      expect(
        () => BackupService.validateBackupData(invalidSchemaJson),
        throwsException,
      );
    });
  });
}
