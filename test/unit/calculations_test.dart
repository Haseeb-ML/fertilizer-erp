import 'package:flutter_test/flutter_test.dart';
import 'package:fertilizer/core/utils/currency_formatter.dart';
import 'package:fertilizer/core/utils/validators.dart';

void main() {
  group('Unit Tests - Business Calculations & Financial Logic', () {
    test(
      'Purchase total calculation with line items, discounts, and freight',
      () {
        const double qty1 = 100;
        const double rate1 = 4500;
        const double total1 = qty1 * rate1; // 450,000

        const double qty2 = 50;
        const double rate2 = 9200;
        const double total2 = qty2 * rate2; // 460,000

        const double subtotal = total1 + total2; // 910,000
        const double discount = 10000;
        const double freight = 25000;

        final grandTotal = subtotal - discount + freight;
        expect(grandTotal, 925000.0);

        const double paidAmount = 500000;
        final balanceDue = grandTotal - paidAmount;
        expect(balanceDue, 425000.0);
      },
    );

    test('Sales grand total, discount, and balance due calculations', () {
      const double qty = 20;
      const double rate = 4800; // Urea sold
      const double subtotal = qty * rate; // 96,000

      const double discount = 2000;
      final grandTotal = subtotal - discount; // 94,000
      expect(grandTotal, 94000.0);

      // Partial cash sale
      const double cashPaid = 40000;
      final balanceDue = grandTotal - cashPaid;
      expect(balanceDue, 54000.0);
    });

    test('Gross profit and net profit accounting calculations', () {
      const double revenue = 150000.0;
      const double cogs = 110000.0;
      final grossProfit = revenue - cogs;
      expect(grossProfit, 40000.0);

      const double rentExpense = 15000.0;
      const double laborExpense = 5000.0;
      const double electricityExpense = 4000.0;
      final totalExpenses =
          rentExpense + laborExpense + electricityExpense; // 24,000

      final netProfit = grossProfit - totalExpenses;
      expect(netProfit, 16000.0);
    });

    test(
      'Customer ledger running balance logic (Debit increases, Credit decreases)',
      () {
        double runningBalance = 0.0;

        // 1. Credit sale of 100,000 (Debit)
        runningBalance += 100000.0;
        expect(runningBalance, 100000.0);

        // 2. Customer pays 60,000 (Credit)
        runningBalance -= 60000.0;
        expect(runningBalance, 40000.0);

        // 3. Customer returns 10,000 worth of goods (Credit)
        runningBalance -= 10000.0;
        expect(runningBalance, 30000.0);
      },
    );

    test(
      'Supplier ledger running balance logic (Credit increases, Debit decreases)',
      () {
        double payableBalance = 0.0;

        // 1. Credit purchase of 250,000 (Credit)
        payableBalance += 250000.0;
        expect(payableBalance, 250000.0);

        // 2. Supplier payment of 150,000 (Debit)
        payableBalance -= 150000.0;
        expect(payableBalance, 100000.0);

        // 3. Purchase return of 20,000 (Debit)
        payableBalance -= 20000.0;
        expect(payableBalance, 80000.0);
      },
    );

    test('Cashbook cash in hand equation without double counting', () {
      const double openingCash = 50000.0;
      const double cashSales = 80000.0;
      const double customerCashReceipts = 40000.0;
      final totalCashIn = cashSales + customerCashReceipts; // 120,000

      const double cashPurchases = 60000.0;
      const double supplierCashPayments = 30000.0;
      const double cashExpenses = 15000.0;
      final totalCashOut =
          cashPurchases + supplierCashPayments + cashExpenses; // 105,000

      final closingCash = openingCash + totalCashIn - totalCashOut;
      expect(closingCash, 65000.0);
    });

    test('Currency Formatter formats PKR correctly', () {
      expect(CurrencyFormatter.format(150000), '₨ 1,50,000');
      expect(CurrencyFormatter.format(150000.50), '₨ 1,50,000.5');
      expect(CurrencyFormatter.formatPdf(150000), 'Rs. 1,50,000');
      expect(CurrencyFormatter.formatPdf(57000), 'Rs. 57,000');
      expect(CurrencyFormatter.formatCompact(1500000), '₨ 15.00 Lac');
      expect(CurrencyFormatter.formatCompact(25000000), '₨ 2.50 Cr');
    });

    test('Input validation checks', () {
      expect(Validators.requiredField(null), isNotNull);
      expect(Validators.requiredField(''), isNotNull);
      expect(Validators.requiredField('Valid Text'), isNull);

      expect(Validators.positiveNumber('0'), isNotNull);
      expect(Validators.positiveNumber('-10'), isNotNull);
      expect(Validators.positiveNumber('abc'), isNotNull);
      expect(Validators.positiveNumber('50'), isNull);

      expect(Validators.nonNegativeNumber('-5'), isNotNull);
      expect(Validators.nonNegativeNumber('0'), isNull);
      expect(Validators.nonNegativeNumber('100'), isNull);

      // Phone number validations
      expect(Validators.phoneNumber(null), isNull);
      expect(Validators.phoneNumber(''), isNull);
      expect(Validators.phoneNumber('123'), isNotNull);
      // Valid Pakistani prefixes (0300-0349, 0355)
      expect(Validators.phoneNumber('03001234567'), isNull);
      expect(Validators.phoneNumber('03451234567'), isNull);
      expect(Validators.phoneNumber('+92 312 3456789'), isNull);
      expect(Validators.phoneNumber('03551234567'), isNull);
      // Invalid Pakistani prefixes like 0358
      expect(Validators.phoneNumber('0358 5649289'), isNotNull);
      expect(Validators.phoneNumber('+92 358 5649289'), isNotNull);
      expect(Validators.phoneNumber('03991234567'), isNotNull);
    });
  });
}
