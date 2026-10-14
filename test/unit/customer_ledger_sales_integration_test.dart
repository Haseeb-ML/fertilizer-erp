import 'package:flutter_test/flutter_test.dart';
import 'package:fertilizer/core/database/database_tables.dart';
import 'package:fertilizer/core/models/customer.dart';
import 'package:fertilizer/core/models/product.dart';
import 'package:fertilizer/core/models/sale.dart';
import 'package:fertilizer/core/models/sale_item.dart';
import 'package:fertilizer/core/models/payment.dart';
import 'package:fertilizer/core/repositories/customer_repository.dart';
import 'package:fertilizer/core/repositories/product_repository.dart';
import 'package:fertilizer/core/repositories/sale_repository.dart';
import 'package:fertilizer/core/repositories/payment_repository.dart';
import '../test_helper.dart';

void main() {
  late CustomerRepository customerRepo;
  late ProductRepository productRepo;
  late SaleRepository saleRepo;
  late PaymentRepository paymentRepo;

  setUp(() async {
    final db = await TestHelper.createInMemoryDatabase();
    customerRepo = CustomerRepository();
    productRepo = ProductRepository();
    saleRepo = SaleRepository();
    paymentRepo = PaymentRepository();
  });

  test('1. Credit Sale (Amount Paid: 0) increases customer balance and creates ledger entry with full details', () async {
    final db = await TestHelper.createInMemoryDatabase();

    // 1. Insert product
    final prodId = await productRepo.insertProduct(Product(
      name: 'Kisaan Dairy Gold (Pellet No. 32)',
      sku: 'KF-32-PELLET',
      category: 'Cattle Feed',
      brand: 'Kissan Feeds',
      bagSize: '40 Kg',
      unit: 'Bag',
      purchasePrice: 3000.0,
      sellingPrice: 4325.0,
      openingStock: 100.0,
      currentStock: 100.0,
      minStockAlert: 10.0,
      createdAt: '2026-10-14T10:00:00',
      updatedAt: '2026-10-14T10:00:00',
    ));

    // 2. Insert customer
    final custId = await customerRepo.insertCustomer(Customer(
      name: 'Haji Aslam',
      phone: '0300-9876543',
      villageOrAddress: 'Chak 45',
      openingBalance: 0.0,
      currentBalance: 0.0,
      createdAt: '2026-10-14T10:00:00',
      updatedAt: '2026-10-14T10:00:00',
    ));

    // 3. Create Credit Sale: 2 bags @ 4325 = 8650, paid = 0
    final sale = Sale(
      invoiceNumber: 'INV-2026-0001',
      customerId: custId,
      customerName: 'Haji Aslam',
      saleDate: '2026-10-14',
      subtotal: 8650.0,
      discount: 0.0,
      grandTotal: 8650.0,
      paidAmount: 0.0,
      balanceDue: 8650.0,
      paymentStatus: 'UNPAID',
      paymentMethod: 'Credit',
      items: [
        SaleItem(
          productId: prodId,
          productName: 'Kisaan Dairy Gold (Pellet No. 32)',
          unit: 'Bag',
          quantity: 2.0,
          unitPrice: 4325.0,
          totalPrice: 8650.0,
        ),
      ],
      createdAt: '2026-10-14T10:30:00',
    );

    final saleId = await saleRepo.createSale(sale);
    expect(saleId, greaterThan(0));

    // Verify Customer balance updated to 8650
    final updatedCust = await customerRepo.getCustomerById(custId);
    expect(updatedCust!.currentBalance, 8650.0);

    // Verify Customer Ledger has the entry with items details
    final ledger = await customerRepo.getCustomerLedger(custId);
    expect(ledger.length, 1);
    final entry = ledger.first;
    expect(entry.transactionType, 'CREDIT_SALE');
    expect(entry.referenceNumber, 'INV-2026-0001');
    expect(entry.referenceId, saleId);
    expect(entry.debit, 8650.0);
    expect(entry.credit, 0.0);
    expect(entry.runningBalance, 8650.0);
    expect(entry.previousBalance, 0.0);
    expect(entry.totalBags, 2.0);
    expect(entry.itemsDetails.length, 1);
    expect(entry.itemsDetails.first, contains('2 Bag × Kisaan Dairy Gold (Pellet No. 32) @ ₨4325 = ₨8650'));
  });

  test('2. Partial Payment Sale (e.g. Total: 123,450, Paid: 50,000 -> Balance: 73,450)', () async {
    final prodId = await productRepo.insertProduct(Product(
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
      createdAt: '2026-10-14T10:00:00',
      updatedAt: '2026-10-14T10:00:00',
    ));

    final custId = await customerRepo.insertCustomer(Customer(
      name: 'Chaudhry Akram',
      phone: '0301-1122334',
      villageOrAddress: 'Kot Radha Kishan',
      openingBalance: 0.0,
      currentBalance: 0.0,
      createdAt: '2026-10-14T10:00:00',
      updatedAt: '2026-10-14T10:00:00',
    ));

    // Total: 123,450, Paid: 50,000, Balance Due: 73,450
    final sale = Sale(
      invoiceNumber: 'INV-2026-0002',
      customerId: custId,
      customerName: 'Chaudhry Akram',
      saleDate: '2026-10-14',
      subtotal: 123450.0,
      grandTotal: 123450.0,
      paidAmount: 50000.0,
      balanceDue: 73450.0,
      paymentStatus: 'PARTIAL',
      paymentMethod: 'Cash',
      items: [
        SaleItem(
          productId: prodId,
          productName: 'Urea Sona',
          unit: 'Bag',
          quantity: 25.0,
          unitPrice: 4938.0,
          totalPrice: 123450.0,
        ),
      ],
      createdAt: '2026-10-14T11:00:00',
    );

    final saleId = await saleRepo.createSale(sale);
    expect(saleId, greaterThan(0));

    // Customer balance must be exactly 73,450
    final cust = await customerRepo.getCustomerById(custId);
    expect(cust!.currentBalance, 73450.0);

    // Ledger must have 2 entries: 1 Debit for Sale (123,450), 1 Credit for Payment (50,000)
    final ledger = await customerRepo.getCustomerLedger(custId);
    expect(ledger.length, 2);

    final saleEntry = ledger[0];
    expect(saleEntry.transactionType, 'PARTIAL_SALE');
    expect(saleEntry.debit, 123450.0);
    expect(saleEntry.credit, 0.0);
    expect(saleEntry.runningBalance, 123450.0);

    final payEntry = ledger[1];
    expect(payEntry.transactionType, 'PAYMENT_RECEIVED');
    expect(payEntry.debit, 0.0);
    expect(payEntry.credit, 50000.0);
    expect(payEntry.runningBalance, 73450.0);

    // Now record remaining payment of 73,450
    await paymentRepo.recordCustomerPayment(Payment(
      paymentType: 'CUSTOMER_PAYMENT',
      partyType: 'Customer',
      partyId: custId,
      partyName: 'Chaudhry Akram',
      amount: 73450.0,
      paymentDate: '2026-10-15',
      paymentMethod: 'Cash',
      notes: 'Final settlement',
      createdAt: '2026-10-15T12:00:00',
    ));

    final custAfter = await customerRepo.getCustomerById(custId);
    expect(custAfter!.currentBalance, 0.0);

    final finalLedger = await customerRepo.getCustomerLedger(custId);
    expect(finalLedger.length, 3);
    expect(finalLedger.last.runningBalance, 0.0);
  });

  test('3. Full Cash Sale (Paid: 100%) leaves customer balance at 0 with both invoice and receipt recorded', () async {
    final prodId = await productRepo.insertProduct(Product(
      name: 'DAP Fauji',
      sku: 'DAP-FAUJI',
      category: 'Fertilizer',
      brand: 'FFC',
      bagSize: '50 Kg',
      unit: 'Bag',
      purchasePrice: 9000.0,
      sellingPrice: 10000.0,
      openingStock: 50.0,
      currentStock: 50.0,
      createdAt: '2026-10-14T10:00:00',
      updatedAt: '2026-10-14T10:00:00',
    ));

    final custId = await customerRepo.insertCustomer(Customer(
      name: 'Malik Tariq',
      phone: '0321-4455667',
      villageOrAddress: 'Vehari',
      openingBalance: 0.0,
      currentBalance: 0.0,
      createdAt: '2026-10-14T10:00:00',
      updatedAt: '2026-10-14T10:00:00',
    ));

    // Full payment sale: 10 bags @ 10,000 = 100,000, Paid: 100,000
    await saleRepo.createSale(Sale(
      invoiceNumber: 'INV-2026-0003',
      customerId: custId,
      customerName: 'Malik Tariq',
      saleDate: '2026-10-14',
      subtotal: 100000.0,
      grandTotal: 100000.0,
      paidAmount: 100000.0,
      balanceDue: 0.0,
      paymentStatus: 'PAID',
      paymentMethod: 'Cash',
      items: [
        SaleItem(
          productId: prodId,
          productName: 'DAP Fauji',
          unit: 'Bag',
          quantity: 10.0,
          unitPrice: 10000.0,
          totalPrice: 100000.0,
        ),
      ],
      createdAt: '2026-10-14T11:30:00',
    ));

    final cust = await customerRepo.getCustomerById(custId);
    expect(cust!.currentBalance, 0.0);

    final ledger = await customerRepo.getCustomerLedger(custId);
    expect(ledger.length, 2);
    expect(ledger[0].transactionType, 'CASH_SALE');
    expect(ledger[0].debit, 100000.0);
    expect(ledger[0].runningBalance, 100000.0);
    expect(ledger[1].transactionType, 'PAYMENT_RECEIVED');
    expect(ledger[1].credit, 100000.0);
    expect(ledger[1].runningBalance, 0.0);
  });

  test('4. Sales Return adjusts customer ledger and balance correctly', () async {
    final prodId = await productRepo.insertProduct(Product(
      name: 'Kisaan Pro Milk (Pellet No. 24)',
      sku: 'KF-24-PELLET',
      category: 'Cattle Feed',
      brand: 'Kissan Feeds',
      bagSize: '40 Kg',
      unit: 'Bag',
      purchasePrice: 3000.0,
      sellingPrice: 3715.0,
      openingStock: 50.0,
      currentStock: 50.0,
      createdAt: '2026-10-14T10:00:00',
      updatedAt: '2026-10-14T10:00:00',
    ));

    final custId = await customerRepo.insertCustomer(Customer(
      name: 'Rana Zahid',
      phone: '0345-7788990',
      villageOrAddress: 'Faisalabad',
      openingBalance: 0.0,
      currentBalance: 0.0,
      createdAt: '2026-10-14T10:00:00',
      updatedAt: '2026-10-14T10:00:00',
    ));

    // Credit sale of 4 bags @ 3715 = 14,860
    final saleId = await saleRepo.createSale(Sale(
      invoiceNumber: 'INV-2026-0004',
      customerId: custId,
      customerName: 'Rana Zahid',
      saleDate: '2026-10-14',
      subtotal: 14860.0,
      grandTotal: 14860.0,
      paidAmount: 0.0,
      balanceDue: 14860.0,
      paymentStatus: 'UNPAID',
      paymentMethod: 'Credit',
      items: [
        SaleItem(
          productId: prodId,
          productName: 'Kisaan Pro Milk (Pellet No. 24)',
          unit: 'Bag',
          quantity: 4.0,
          unitPrice: 3715.0,
          totalPrice: 14860.0,
        ),
      ],
      createdAt: '2026-10-14T12:00:00',
    ));

    expect((await customerRepo.getCustomerById(custId))!.currentBalance, 14860.0);

    // Customer returns 1 bag (value 3715)
    await saleRepo.returnSaleItem(
      saleId: saleId,
      productId: prodId,
      quantity: 1.0,
      unitPrice: 3715.0,
      unitCost: 3000.0,
      refundType: 'LEDGER_ADJUST',
      reason: 'Damaged bag packaging',
    );

    // Outstanding balance must be reduced by 3715: 14860 - 3715 = 11145
    final custAfterReturn = await customerRepo.getCustomerById(custId);
    expect(custAfterReturn!.currentBalance, 11145.0);

    final ledger = await customerRepo.getCustomerLedger(custId);
    expect(ledger.length, 2);
    expect(ledger.last.transactionType, 'SALE_RETURN');
    expect(ledger.last.credit, 3715.0);
    expect(ledger.last.runningBalance, 11145.0);
    expect(ledger.last.itemsDetails.first, contains('Returned: 1 Bag'));
  });

  test('5. Reconciliation of old / unlinked sales invoices and duplicate prevention', () async {
    final db = await TestHelper.createInMemoryDatabase();

    final custId = await customerRepo.insertCustomer(Customer(
      name: 'Sheikh Bilal',
      phone: '0300-5555555',
      villageOrAddress: 'Lahore',
      openingBalance: 1000.0, // Opening balance of 1,000
      currentBalance: 1000.0,
      createdAt: '2026-10-01T10:00:00',
      updatedAt: '2026-10-01T10:00:00',
    ));

    // Manually insert an old sale invoice without ledger entries
    final saleId = await db.insert(DatabaseTables.sales, {
      'invoice_number': 'INV-OLD-999',
      'customer_id': custId,
      'customer_name': 'Sheikh Bilal',
      'sale_date': '2026-10-05',
      'subtotal': 20000.0,
      'discount': 0.0,
      'grand_total': 20000.0,
      'paid_amount': 5000.0,
      'balance_due': 15000.0,
      'total_cost': 16000.0,
      'gross_profit': 4000.0,
      'payment_status': 'PARTIAL',
      'payment_method': 'Cash',
      'notes': 'Old offline invoice',
      'is_reversed': 0,
      'created_at': '2026-10-05T10:00:00',
    });

    await db.insert(DatabaseTables.saleItems, {
      'sale_id': saleId,
      'product_id': 1,
      'product_name': 'Test Fertilizer',
      'unit': 'Bag',
      'quantity': 5.0,
      'unit_price': 4000.0,
      'unit_cost': 3200.0,
      'total_price': 20000.0,
    });

    // Run reconciliation
    await CustomerRepository.reconcileCustomerLedger(db, custId);

    // Balance should be: Opening 1,000 + Sale 20,000 - Paid 5,000 = 16,000
    final cust = await customerRepo.getCustomerById(custId);
    expect(cust!.currentBalance, 16000.0);

    final ledger1 = await customerRepo.getCustomerLedger(custId);
    // Opening balance (1000) + Sale (20000) + Payment (5000) = 3 entries
    expect(ledger1.length, 3);
    expect(ledger1[0].transactionType, 'OPENING_BALANCE');
    expect(ledger1[1].transactionType, 'PARTIAL_SALE');
    expect(ledger1[2].transactionType, 'PAYMENT_RECEIVED');
    expect(ledger1[2].runningBalance, 16000.0);

    // Run reconciliation AGAIN to ensure NO DUPLICATES are created (Idempotence)
    await CustomerRepository.reconcileCustomerLedger(db, custId);
    final ledger2 = await customerRepo.getCustomerLedger(custId);
    expect(ledger2.length, 3); // Still exactly 3 entries!
    expect((await customerRepo.getCustomerById(custId))!.currentBalance, 16000.0);
  });
}
