import 'package:flutter_test/flutter_test.dart';
import 'package:fertilizer/core/services/pdf_service.dart';
import 'package:fertilizer/core/models/business_settings.dart';
import 'package:fertilizer/core/models/report_models.dart';
import 'package:fertilizer/core/models/product.dart';
import 'package:fertilizer/core/models/ledger_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final settings = BusinessSettings(
    businessName: 'Kissan Fertilizer & Feeds Agency',
    ownerName: 'Muhammad Haseeb',
    phone: '0303-7000020',
    address: 'Kunjah Road, Mangowal Gharbi, Gujrat',
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

  group('PDF Report Document Generation Tests', () {
    test('buildSalesReportDocument generates valid PDF bytes', () async {
      final summary = SalesSummaryReport(
        totalSales: 150000.0,
        totalDiscount: 5000.0,
        netSales: 145000.0,
        totalPaid: 100000.0,
        totalBalanceDue: 45000.0,
        invoiceCount: 12,
        totalCost: 120000.0,
        grossProfit: 25000.0,
      );

      final products = [
        ProductSalesReport(
          productId: 1,
          productName: 'Sona Urea',
          category: 'Fertilizer',
          totalQuantity: 20.0,
          totalRevenue: 90000.0,
          totalCost: 76000.0,
          profit: 14000.0,
        ),
        ProductSalesReport(
          productId: 2,
          productName: 'Kisaan Dairy 32',
          category: 'Feed',
          totalQuantity: 10.0,
          totalRevenue: 60000.0,
          totalCost: 44000.0,
          profit: 16000.0,
        ),
      ];

      final doc = await PdfService.buildSalesReportDocument(
        summary: summary,
        products: products,
        settings: settings,
        fromDate: '2026-10-01',
        toDate: '2026-10-14',
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });

    test('buildInventoryReportDocument generates valid PDF bytes', () async {
      final val = InventoryValuationReport(
        totalProducts: 2,
        totalStockQuantity: 150.0,
        totalCostValue: 450000.0,
        totalRetailValue: 520000.0,
        potentialProfit: 70000.0,
        lowStockCount: 1,
      );

      final products = [
        Product(
          id: 1,
          name: 'Sona Urea',
          sku: 'FER-001',
          category: 'Fertilizer',
          brand: 'FFC',
          purchasePrice: 3800.0,
          sellingPrice: 4200.0,
          currentStock: 100.0,
          minStockAlert: 15.0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
        Product(
          id: 2,
          name: 'DAP Engro',
          sku: 'FER-002',
          category: 'Fertilizer',
          brand: 'Engro',
          purchasePrice: 9500.0,
          sellingPrice: 10200.0,
          currentStock: 5.0,
          minStockAlert: 10.0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      ];

      final doc = await PdfService.buildInventoryReportDocument(
        valuation: val,
        products: products,
        settings: settings,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });

    test('buildPartyBalanceReportDocument generates valid PDF bytes for Receivables and Payables', () async {
      final list = [
        PartyBalanceReport(
          id: 1,
          name: 'Chaudhry Akram',
          phone: '0300-1234567',
          address: 'Chak 42, Mangowal',
          balance: 65000.0,
        ),
        PartyBalanceReport(
          id: 2,
          name: 'Malik Tariq',
          phone: '0321-7654321',
          address: 'Kunjah',
          balance: 35000.0,
        ),
      ];

      final doc = await PdfService.buildPartyBalanceReportDocument(
        reportTitle: 'Customer Receivables Report (کسٹمر واجبات رپورٹ)',
        partyType: 'Customer',
        list: list,
        settings: settings,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });

    test('buildLedgerStatementDocument includes party address and phone in multi-page document', () async {
      final List<LedgerEntry> entries = [
        LedgerEntry(
          id: 1,
          partyId: 1,
          transactionDate: '2026-10-10',
          transactionType: 'INVOICE',
          referenceNumber: 'INV-1001',
          debit: 50000.0,
          credit: 0.0,
          runningBalance: 50000.0,
          description: 'Sales Invoice INV-1001',
          itemsDetails: ['20x Sona Urea @ Rs. 2,500'],
          createdAt: DateTime.now().toIso8601String(),
        ),
        LedgerEntry(
          id: 2,
          partyId: 1,
          transactionDate: '2026-10-12',
          transactionType: 'PAYMENT',
          referenceNumber: 'REC-1001',
          debit: 0.0,
          credit: 25000.0,
          runningBalance: 25000.0,
          description: 'Cash Receipt REC-1001',
          itemsDetails: [],
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];

      final doc = await PdfService.buildLedgerStatementDocument(
        partyName: 'Chaudhry Akram',
        partyType: 'Customer',
        partyPhone: '0300-1234567',
        partyAddress: 'Chak 42, Mangowal',
        entries: entries,
        currentBalance: 25000.0,
        settings: settings,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });
  });
}
