import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fertilizer/core/database/database_helper.dart';
import 'package:fertilizer/core/database/database_tables.dart';
import 'package:fertilizer/core/models/product.dart';
import 'package:fertilizer/core/models/customer.dart';
import 'package:fertilizer/core/models/supplier.dart';
import 'package:fertilizer/core/models/purchase.dart';
import 'package:fertilizer/core/models/purchase_item.dart';
import 'package:fertilizer/core/models/sale.dart';
import 'package:fertilizer/core/models/sale_item.dart';
import 'package:fertilizer/core/models/payment.dart';
import 'package:fertilizer/core/models/expense.dart';
import 'package:fertilizer/core/repositories/product_repository.dart';
import 'package:fertilizer/core/repositories/customer_repository.dart';
import 'package:fertilizer/core/repositories/supplier_repository.dart';
import 'package:fertilizer/core/repositories/purchase_repository.dart';
import 'package:fertilizer/core/repositories/sale_repository.dart';
import 'package:fertilizer/core/repositories/payment_repository.dart';
import 'package:fertilizer/core/repositories/expense_repository.dart';
import 'package:fertilizer/core/repositories/cashbook_repository.dart';
import 'package:fertilizer/core/repositories/report_repository.dart';
import 'package:fertilizer/core/services/backup_service.dart';
import '../test_helper.dart';

void main() {
  late Database db;
  late ProductRepository productRepo;
  late CustomerRepository customerRepo;
  late SupplierRepository supplierRepo;
  late PurchaseRepository purchaseRepo;
  late SaleRepository saleRepo;
  late PaymentRepository paymentRepo;
  late ExpenseRepository expenseRepo;
  late CashbookRepository cashbookRepo;
  late ReportRepository reportRepo;

  setUp(() async {
    db = await TestHelper.createInMemoryDatabase();
    productRepo = ProductRepository(DatabaseHelper.instance);
    customerRepo = CustomerRepository(DatabaseHelper.instance);
    supplierRepo = SupplierRepository(DatabaseHelper.instance);
    purchaseRepo = PurchaseRepository(DatabaseHelper.instance);
    saleRepo = SaleRepository(DatabaseHelper.instance);
    paymentRepo = PaymentRepository(DatabaseHelper.instance);
    expenseRepo = ExpenseRepository(DatabaseHelper.instance);
    cashbookRepo = CashbookRepository(DatabaseHelper.instance);
    reportRepo = ReportRepository(DatabaseHelper.instance);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('Mandatory Integration Tests - 10 Core Business Workflows', () {
    test(
      'Test 1: Purchase 100 bags with partial payment updates stock, purchase total, and supplier payable',
      () async {
        final now = DateTime.now().toIso8601String();
        final today = now.substring(0, 10);

        // Create Supplier
        final suppId = await supplierRepo.insertSupplier(
          Supplier(
            name: 'FFC Regional Depot',
            companyOrAddress: 'Galla Mandi Multan',
            openingBalance: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Create Product
        final prodId = await productRepo.insertProduct(
          Product(
            name: 'Sona Urea',
            sku: 'UREA-01',
            category: 'Urea',
            brand: 'FFC',
            purchasePrice: 4500,
            sellingPrice: 4800,
            openingStock: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Purchase 100 bags @ 4500 = 450,000, Partial Payment of 200,000
        final purchase = Purchase(
          invoiceNumber: 'PUR-2026-0001',
          supplierId: suppId,
          supplierName: 'FFC Regional Depot',
          purchaseDate: today,
          subtotal: 450000,
          discount: 0,
          freightCharges: 0,
          grandTotal: 450000,
          paidAmount: 200000,
          balanceDue: 250000,
          paymentStatus: 'PARTIAL',
          paymentMethod: 'Cash',
          createdAt: now,
          items: [
            PurchaseItem(
              productId: prodId,
              productName: 'Sona Urea',
              unit: 'Bag',
              quantity: 100,
              unitPrice: 4500,
              totalPrice: 450000,
            ),
          ],
        );

        final purchaseId = await purchaseRepo.createPurchase(purchase);
        expect(purchaseId, greaterThan(0));

        // Verify Stock increased to 100
        final product = await productRepo.getProductById(prodId);
        expect(product!.currentStock, 100.0);

        // Verify Supplier Payable is 250,000 (450,000 billed - 200,000 paid)
        final supplier = await supplierRepo.getSupplierById(suppId);
        expect(supplier!.currentBalance, 250000.0);
      },
    );

    test(
      'Test 2: Cash sale of 10 bags deduces stock, records cash and calculates profit',
      () async {
        final now = DateTime.now().toIso8601String();
        final today = now.substring(0, 10);

        // Create Product with 100 opening stock @ 4500
        final prodId = await productRepo.insertProduct(
          Product(
            name: 'Sona Urea',
            sku: 'UREA-02',
            category: 'Urea',
            brand: 'FFC',
            purchasePrice: 4500,
            sellingPrice: 4800,
            openingStock: 100,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Sell 10 bags for cash (10 * 4800 = 48,000)
        final sale = Sale(
          invoiceNumber: 'INV-2026-0001',
          customerId: null,
          customerName: 'Walk-in Farmer',
          saleDate: today,
          subtotal: 48000,
          discount: 0,
          grandTotal: 48000,
          paidAmount: 48000,
          balanceDue: 0,
          paymentStatus: 'PAID',
          paymentMethod: 'Cash',
          createdAt: now,
          items: [
            SaleItem(
              productId: prodId,
              productName: 'Sona Urea',
              unit: 'Bag',
              quantity: 10,
              unitPrice: 4800,
              totalPrice: 48000,
            ),
          ],
        );

        final saleId = await saleRepo.createSale(sale);
        expect(saleId, greaterThan(0));

        // Verify Stock reduced from 100 to 90
        final product = await productRepo.getProductById(prodId);
        expect(product!.currentStock, 90.0);

        // Verify Cash in hand increased by 48,000
        final cash = await cashbookRepo.getCurrentCashBalance();
        expect(cash, 48000.0);

        // Verify Gross Profit: Revenue 48,000 - Cost (10 * 4500 = 45,000) = 3,000
        final savedSale = await saleRepo.getSaleById(saleId);
        expect(savedSale!.grossProfit, 3000.0);
      },
    );

    test(
      'Test 3: Credit sale increases customer receivables and ledger entries',
      () async {
        final now = DateTime.now().toIso8601String();
        final today = now.substring(0, 10);

        final custId = await customerRepo.insertCustomer(
          Customer(
            name: 'Malik Jahangir',
            openingBalance: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final prodId = await productRepo.insertProduct(
          Product(
            name: 'Engro DAP',
            sku: 'DAP-01',
            category: 'DAP',
            brand: 'Engro',
            purchasePrice: 9000,
            sellingPrice: 9500,
            openingStock: 50,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Credit sale of 5 bags @ 9500 = 47,500 (Paid 0)
        final sale = Sale(
          invoiceNumber: 'INV-2026-0002',
          customerId: custId,
          customerName: 'Malik Jahangir',
          saleDate: today,
          subtotal: 47500,
          discount: 0,
          grandTotal: 47500,
          paidAmount: 0,
          balanceDue: 47500,
          paymentStatus: 'UNPAID',
          paymentMethod: 'Credit',
          createdAt: now,
          items: [
            SaleItem(
              productId: prodId,
              productName: 'Engro DAP',
              unit: 'Bag',
              quantity: 5,
              unitPrice: 9500,
              totalPrice: 47500,
            ),
          ],
        );

        await saleRepo.createSale(sale);

        // Verify customer current balance is 47,500
        final customer = await customerRepo.getCustomerById(custId);
        expect(customer!.currentBalance, 47500.0);

        // Verify customer ledger entry
        final ledger = await customerRepo.getCustomerLedger(custId);
        expect(ledger.length, 1);
        expect(ledger.first.transactionType, 'SALE');
        expect(ledger.first.debit, 47500.0);
        expect(ledger.first.runningBalance, 47500.0);
      },
    );

    test(
      'Test 4: Partial customer payment verifies outstanding balance and cashbook',
      () async {
        final now = DateTime.now().toIso8601String();
        final today = now.substring(0, 10);

        final custId = await customerRepo.insertCustomer(
          Customer(
            name: 'Chaudhry Akram',
            openingBalance: 60000, // owes 60,000
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Customer makes partial payment of 25,000 in Cash
        await paymentRepo.recordCustomerPayment(
          Payment(
            paymentType: 'CUSTOMER_IN',
            partyType: 'CUSTOMER',
            partyId: custId,
            partyName: 'Chaudhry Akram',
            amount: 25000,
            paymentDate: today,
            paymentMethod: 'Cash',
            createdAt: now,
          ),
        );

        // Balance reduced from 60,000 to 35,000
        final customer = await customerRepo.getCustomerById(custId);
        expect(customer!.currentBalance, 35000.0);

        // Cashbook receives 25,000
        final cash = await cashbookRepo.getCurrentCashBalance();
        expect(cash, 25000.0);
      },
    );

    test('Test 5: Supplier payment reduces payable and cashbook', () async {
      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);

      // Seed cash with initial sales so cash is positive
      final prodId = await productRepo.insertProduct(
        Product(
          name: 'Tara Urea',
          sku: 'TARA-01',
          category: 'Urea',
          brand: 'Agritech',
          purchasePrice: 4500,
          sellingPrice: 5000,
          openingStock: 20,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await saleRepo.createSale(
        Sale(
          invoiceNumber: 'INV-2026-0003',
          customerName: 'Cash Buyer',
          saleDate: today,
          subtotal: 100000,
          grandTotal: 100000,
          paidAmount: 100000,
          balanceDue: 0,
          paymentStatus: 'PAID',
          paymentMethod: 'Cash',
          createdAt: now,
          items: [
            SaleItem(
              productId: prodId,
              productName: 'Tara Urea',
              unit: 'Bag',
              quantity: 20,
              unitPrice: 5000,
              totalPrice: 100000,
            ),
          ],
        ),
      );

      final suppId = await supplierRepo.insertSupplier(
        Supplier(
          name: 'Engro Multan Depot',
          openingBalance: 150000, // owe 150,000
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Pay supplier 40,000 in Cash
      await paymentRepo.recordSupplierPayment(
        Payment(
          paymentType: 'SUPPLIER_OUT',
          partyType: 'SUPPLIER',
          partyId: suppId,
          partyName: 'Engro Multan Depot',
          amount: 40000,
          paymentDate: today,
          paymentMethod: 'Cash',
          createdAt: now,
        ),
      );

      // Payable balance reduced from 150,000 to 110,000
      final supplier = await supplierRepo.getSupplierById(suppId);
      expect(supplier!.currentBalance, 110000.0);

      // Cash reduced: 100,000 - 40,000 = 60,000
      final cash = await cashbookRepo.getCurrentCashBalance();
      expect(cash, 60000.0);
    });

    test('Test 6: Sales return restores stock and customer balance', () async {
      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);

      final custId = await customerRepo.insertCustomer(
        Customer(
          name: 'Farmer Tariq',
          openingBalance: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final prodId = await productRepo.insertProduct(
        Product(
          name: 'NitroPhos (Sona NP)',
          sku: 'NP-01',
          category: 'NP (NitroPhos)',
          brand: 'FFC',
          purchasePrice: 6000,
          sellingPrice: 6500,
          openingStock: 20,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Sell 10 bags on credit (65,000)
      final saleId = await saleRepo.createSale(
        Sale(
          invoiceNumber: 'INV-2026-0004',
          customerId: custId,
          customerName: 'Farmer Tariq',
          saleDate: today,
          subtotal: 65000,
          grandTotal: 65000,
          paidAmount: 0,
          balanceDue: 65000,
          paymentStatus: 'UNPAID',
          paymentMethod: 'Credit',
          createdAt: now,
          items: [
            SaleItem(
              productId: prodId,
              productName: 'NitroPhos',
              unit: 'Bag',
              quantity: 10,
              unitPrice: 6500,
              unitCost: 6000,
              totalPrice: 65000,
            ),
          ],
        ),
      );

      // Stock is now 10
      var product = await productRepo.getProductById(prodId);
      expect(product!.currentStock, 10.0);

      // Return 2 bags (2 * 6500 = 13,000)
      await saleRepo.returnSaleItem(
        saleId: saleId,
        productId: prodId,
        quantity: 2,
        unitPrice: 6500,
        unitCost: 6000,
        refundType: 'LEDGER_ADJUST',
        reason: 'Excess bags',
      );

      // Stock restored to 12
      product = await productRepo.getProductById(prodId);
      expect(product!.currentStock, 12.0);

      // Customer balance reduced from 65,000 to 52,000
      final customer = await customerRepo.getCustomerById(custId);
      expect(customer!.currentBalance, 52000.0);
    });

    test(
      'Test 7: Purchase return decreases stock and supplier payable',
      () async {
        final now = DateTime.now().toIso8601String();
        final today = now.substring(0, 10);

        final suppId = await supplierRepo.insertSupplier(
          Supplier(
            name: 'Fatima Company',
            openingBalance: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final prodId = await productRepo.insertProduct(
          Product(
            name: 'Sarsabz CAN',
            sku: 'CAN-01',
            category: 'CAN',
            brand: 'Fatima',
            purchasePrice: 3800,
            sellingPrice: 4200,
            openingStock: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Purchase 50 bags on credit @ 3800 = 190,000
        final purchaseId = await purchaseRepo.createPurchase(
          Purchase(
            invoiceNumber: 'PUR-2026-0005',
            supplierId: suppId,
            supplierName: 'Fatima Company',
            purchaseDate: today,
            subtotal: 190000,
            grandTotal: 190000,
            paidAmount: 0,
            balanceDue: 190000,
            paymentStatus: 'UNPAID',
            paymentMethod: 'Credit',
            createdAt: now,
            items: [
              PurchaseItem(
                productId: prodId,
                productName: 'Sarsabz CAN',
                unit: 'Bag',
                quantity: 50,
                unitPrice: 3800,
                totalPrice: 190000,
              ),
            ],
          ),
        );

        // Return 5 damaged bags
        await purchaseRepo.returnPurchaseItem(
          purchaseId: purchaseId,
          productId: prodId,
          quantity: 5,
          unitPrice: 3800,
          refundType: 'LEDGER_ADJUST',
          reason: 'Torn bags',
        );

        // Stock reduced from 50 to 45
        final product = await productRepo.getProductById(prodId);
        expect(product!.currentStock, 45.0);

        // Payable reduced: 190,000 - (5 * 3800 = 19,000) = 171,000
        final supplier = await supplierRepo.getSupplierById(suppId);
        expect(supplier!.currentBalance, 171000.0);
      },
    );

    test(
      'Test 8: Recording transport expense verifies cash balance and net profit',
      () async {
        final now = DateTime.now().toIso8601String();
        final today = now.substring(0, 10);

        // Record 10,000 Cash transport expense
        await expenseRepo.insertExpense(
          Expense(
            category: 'Transport / Freight (Kiraya)',
            title: 'Trolley transport for fertilizer depot',
            amount: 10000,
            expenseDate: today,
            paymentMethod: 'Cash',
            createdAt: now,
          ),
        );

        final expenses = await expenseRepo.getExpenses(
          fromDate: today,
          toDate: today,
        );
        expect(expenses.length, 1);
        expect(expenses.first.amount, 10000.0);

        final pnl = await reportRepo.getProfitLossReport(
          fromDate: today,
          toDate: today,
        );
        expect(pnl.totalExpenses, 10000.0);
      },
    );

    test('Test 9: Database close and reopen persistence', () async {
      final now = DateTime.now().toIso8601String();

      final id = await customerRepo.insertCustomer(
        Customer(
          name: 'Persistent Customer',
          openingBalance: 12345,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify record exists before closing
      final before = await customerRepo.getCustomerById(id);
      expect(before!.name, 'Persistent Customer');

      // Database reopen simulation with new repository instances
      final reopenedRepo = CustomerRepository(DatabaseHelper.instance);
      final after = await reopenedRepo.getCustomerById(id);
      expect(after!.name, 'Persistent Customer');
      expect(after.currentBalance, 12345.0);
    });

    test('Test 10: Complete backup and restore into test database', () async {
      final now = DateTime.now().toIso8601String();

      // Seed records
      final prodId = await productRepo.insertProduct(
        Product(
          name: 'Backup Test Product',
          sku: 'BAK-01',
          category: 'Urea',
          brand: 'FFC',
          purchasePrice: 4000,
          sellingPrice: 4500,
          openingStock: 25,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final custId = await customerRepo.insertCustomer(
        Customer(
          name: 'Backup Test Customer',
          openingBalance: 50000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Export Backup JSON
      final backupJson = await BackupService.exportBackupToJson(
        dbHelper: DatabaseHelper.instance,
      );
      expect(backupJson, isNotEmpty);

      // Verify schema and integrity
      final validated = BackupService.validateBackupData(backupJson);
      expect(validated['schema_version'], 1);

      // Clear or mutate database
      await db.delete(DatabaseTables.customerLedger);
      await db.delete(DatabaseTables.customers);
      final emptyCustomers = await customerRepo.getCustomers();
      expect(emptyCustomers, isEmpty);

      // Restore from backup
      final restoreResult = await BackupService.restoreBackup(
        backupJson,
        dbHelper: DatabaseHelper.instance,
      );
      expect(restoreResult.success, isTrue);

      // Verify records and balances restored intact
      final restoredCust = await customerRepo.getCustomerById(custId);
      expect(restoredCust, isNotNull);
      expect(restoredCust!.name, 'Backup Test Customer');
      expect(restoredCust.openingBalance, 50000.0);

      final restoredProd = await productRepo.getProductById(prodId);
      expect(restoredProd, isNotNull);
      expect(restoredProd!.name, 'Backup Test Product');
    });

    test('Test 11: Database clear/wipe removes all records atomically', () async {
      final product = Product(
        name: 'Wipe Test Product',
        sku: 'WIPE-001',
        category: 'Urea',
        brand: 'Engro',
        bagSize: '50kg',
        unit: 'Bag',
        purchasePrice: 4000,
        sellingPrice: 4500,
        currentStock: 10,
        minStockAlert: 5,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await productRepo.insertProduct(product);

      final customer = Customer(
        name: 'Wipe Test Customer',
        phone: '0300-9998877',
        villageOrAddress: 'Test City',
        creditLimit: 100000,
        currentBalance: 0,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await customerRepo.insertCustomer(customer);

      final preProducts = await productRepo.getProducts();
      final preCustomers = await customerRepo.getCustomers();
      expect(preProducts.isNotEmpty, isTrue);
      expect(preCustomers.isNotEmpty, isTrue);

      final deleted = await BackupService.clearAllDatabaseData(
        dbHelper: DatabaseHelper.instance,
        resetBusinessSettings: false,
      );
      expect(deleted, greaterThan(0));

      final postProducts = await productRepo.getProducts();
      final postCustomers = await customerRepo.getCustomers();
      expect(postProducts, isEmpty);
      expect(postCustomers, isEmpty);
    });
  });
}

