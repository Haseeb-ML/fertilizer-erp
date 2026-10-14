import 'package:flutter_test/flutter_test.dart';
import 'package:fertilizer/core/database/database_tables.dart';
import 'package:fertilizer/core/models/business_settings.dart';
import 'package:fertilizer/core/repositories/report_repository.dart';
import 'package:fertilizer/core/services/pdf_service.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReportRepository reportRepo;

  setUp(() async {
    final db = await TestHelper.createInMemoryDatabase();
    reportRepo = ReportRepository();

    for (final table in [
      DatabaseTables.returns,
      DatabaseTables.saleItems,
      DatabaseTables.sales,
      DatabaseTables.expenses,
      DatabaseTables.customerLedger,
      DatabaseTables.customers,
      DatabaseTables.stockMovements,
      DatabaseTables.stockCostLayers,
      DatabaseTables.products,
    ]) {
      await db.delete(table);
    }

    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    // 1. Insert product: purchase_price: 3000, selling_price: 4325
    final prodId = await db.insert(DatabaseTables.products, {
      'name': 'Kisaan Dairy Gold (Pellet No. 32)',
      'sku': 'KF-32-PELLET',
      'category': 'Cattle Feed / Vanda (وانڈا)',
      'brand': 'Kissan Feeds',
      'bag_size': '40 Kg',
      'unit': 'Bag',
      'purchase_price': 3000.0,
      'selling_price': 4325.0,
      'opening_stock': 100.0,
      'current_stock': 90.0,
      'min_stock_alert': 10.0,
      'notes': '',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // 2. Insert customer
    final custId = await db.insert(DatabaseTables.customers, {
      'name': 'Chaudhry Akram Farmer',
      'phone': '0300-1234567',
      'village_or_address': 'Chak 45/SB',
      'opening_balance': 0.0,
      'current_balance': 43250.0,
      'notes': '',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // 3. Insert sale: 10 bags @ 4325 = 43,250
    final saleId = await db.insert(DatabaseTables.sales, {
      'invoice_number': 'INV-2026-0001',
      'customer_id': custId,
      'customer_name': 'Chaudhry Akram Farmer',
      'sale_date': '$today 14:30:00', // Contains timestamp
      'subtotal': 43250.0,
      'discount': 0.0,
      'grand_total': 43250.0,
      'paid_amount': 0.0,
      'balance_due': 43250.0,
      'total_cost': 0.0, // Stored as 0 to test dynamic fallback
      'gross_profit': 0.0,
      'payment_status': 'UNPAID',
      'payment_method': 'Credit',
      'notes': '',
      'is_reversed': 0,
      'created_at': now,
    });

    // Insert sale item with unit_cost = 0 (tests dynamic fallback to product purchase_price = 3000)
    await db.insert(DatabaseTables.saleItems, {
      'sale_id': saleId,
      'product_id': prodId,
      'product_name': 'Kisaan Dairy Gold (Pellet No. 32)',
      'unit': 'Bag',
      'quantity': 10.0,
      'unit_price': 4325.0,
      'unit_cost': 0.0, // Fallback to product.purchase_price (3000)
      'total_price': 43250.0,
    });

    // 4. Insert sales return: 2 bags returned
    await db.insert(DatabaseTables.returns, {
      'return_type': 'SALE_RETURN',
      'original_invoice_id': saleId,
      'original_invoice_number': 'INV-2026-0001',
      'party_id': custId,
      'party_name': 'Chaudhry Akram Farmer',
      'return_date': today,
      'product_id': prodId,
      'product_name': 'Kisaan Dairy Gold (Pellet No. 32)',
      'quantity': 2.0,
      'unit_price': 4325.0,
      'total_amount': 8650.0, // 2 * 4325
      'refund_type': 'CREDIT_ADJUSTMENT',
      'reason': 'Damaged bags',
      'created_at': now,
    });

    // 5. Insert Operating Expenses
    await db.insert(DatabaseTables.expenses, {
      'category': 'Shop Rent (دکان کا کرایہ)',
      'amount': 2000.0,
      'expense_date': today,
      'payment_method': 'Cash',
      'title': 'Monthly Shop Rent',
      'notes': '',
      'created_at': now,
    });

    await db.insert(DatabaseTables.expenses, {
      'category': 'Electricity (بجلی بل)',
      'amount': 1500.0,
      'expense_date': today,
      'payment_method': 'Cash',
      'title': 'WAPDA Bill',
      'notes': '',
      'created_at': now,
    });
  });

  group('Profit & Loss Report - Calculation & Accuracy Tests', () {
    test('Calculates Dynamic COGS, Sales Returns deduction, and Gross Profit accurately', () async {
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final report = await reportRepo.getProfitLossReport(
        fromDate: now,
        toDate: now,
      );

      // Gross revenue: 43,250
      expect(report.totalRevenue, 43250.0);

      // Returns: 2 bags * 4325 = 8,650
      expect(report.totalReturns, 8650.0);

      // Net revenue: 43,250 - 8,650 = 34,600
      expect(report.netRevenue, 34600.0);

      // COGS: 10 bags * 3000 = 30,000. Returned cost: 2 bags * 3000 = 6,000. Net COGS = 24,000
      expect(report.costOfGoodsSold, 24000.0);

      // Gross Profit: Net Revenue (34,600) - Net COGS (24,000) = 10,600 (8 bags * 1325 profit per bag!)
      expect(report.grossProfit, 10600.0);

      // Total Expenses: 2,000 (Rent) + 1,500 (Electricity) = 3,500
      expect(report.totalExpenses, 3500.0);

      // Net Profit: Gross Profit (10,600) - Total Expenses (3,500) = 7,100
      expect(report.netProfit, 7100.0);

      // Gross Margin %: 10,600 / 34,600 * 100 = ~30.635%
      expect(report.grossMarginPercent, closeTo(30.635, 0.01));

      // Net Margin %: 7,100 / 34,600 * 100 = ~20.52%
      expect(report.netMarginPercent, closeTo(20.52, 0.01));
    });

    test('Includes transactions when date has time component (safe SUBSTR matching)', () async {
      // Testing with exact date strings (e.g. today's date)
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final report = await reportRepo.getProfitLossReport(
        fromDate: today,
        toDate: today,
      );

      expect(report.totalInvoices, 1);
      expect(report.productBreakdown.isNotEmpty, isTrue);
      expect(report.productBreakdown.first.productName, 'Kisaan Dairy Gold (Pellet No. 32)');
    });

    test('Expense breakdown returns categories with correct percentages', () async {
      final report = await reportRepo.getProfitLossReport();

      expect(report.expenseBreakdown.length, 2);
      final rent = report.expenseBreakdown.firstWhere((e) => e.category.contains('Rent'));
      expect(rent.amount, 2000.0);
      expect(rent.percentage, closeTo(57.14, 0.01)); // 2000 / 3500 * 100
    });

    test('Product-wise profit breakdown calculates per-product revenue, cost, profit, and margin', () async {
      final report = await reportRepo.getProfitLossReport();

      expect(report.productBreakdown.length, 1);
      final product = report.productBreakdown.first;
      expect(product.productName, 'Kisaan Dairy Gold (Pellet No. 32)');
      expect(product.quantitySold, 10.0);
      expect(product.totalRevenue, 43250.0);
      expect(product.totalCost, 30000.0);
      expect(product.grossProfit, 13250.0); // 10 * 1325
      expect(product.marginPercent, closeTo(30.635, 0.01));
    });

    test('PdfService builds Profit & Loss document successfully without errors', () async {
      final report = await reportRepo.getProfitLossReport();
      final settings = BusinessSettings(
        businessName: 'Kissan Fertilizer Agency',
        ownerName: 'Muhammad Haseeb',
        phone: '0303-7000020',
        address: 'Mangowal, Gujrat',
        city: 'Gujrat',
        ntnStrn: '',
        invoicePrefix: 'INV-',
        purchasePrefix: 'PUR-',
        currencySymbol: '₨',
        pinCode: '',
        isPinEnabled: false,
        initialCashBalance: 0.0,
        updatedAt: DateTime.now().toIso8601String(),
      );

      final doc = await PdfService.buildProfitLossDocument(
        report: report,
        settings: settings,
        fromDate: '2026-10-01',
        toDate: '2026-10-31',
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000));
    });
  });
}
