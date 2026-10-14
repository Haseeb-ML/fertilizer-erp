class SalesSummaryReport {
  final double totalSales;
  final double totalDiscount;
  final double netSales;
  final double totalPaid;
  final double totalBalanceDue;
  final int invoiceCount;
  final double totalCost;
  final double grossProfit;

  SalesSummaryReport({
    required this.totalSales,
    required this.totalDiscount,
    required this.netSales,
    required this.totalPaid,
    required this.totalBalanceDue,
    required this.invoiceCount,
    required this.totalCost,
    required this.grossProfit,
  });
}

class ProductSalesReport {
  final int productId;
  final String productName;
  final String category;
  final double totalQuantity;
  final double totalRevenue;
  final double totalCost;
  final double profit;

  ProductSalesReport({
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.totalCost,
    required this.profit,
  });
}

class InventoryValuationReport {
  final int totalProducts;
  final double totalStockQuantity;
  final double totalCostValue;
  final double totalRetailValue;
  final double potentialProfit;
  final int lowStockCount;

  InventoryValuationReport({
    required this.totalProducts,
    required this.totalStockQuantity,
    required this.totalCostValue,
    required this.totalRetailValue,
    required this.potentialProfit,
    required this.lowStockCount,
  });
}

class CashbookSummary {
  final double openingCash;
  final double cashInSales;
  final double cashInCustomerPayments;
  final double totalCashIn;
  final double cashOutPurchases;
  final double cashOutSupplierPayments;
  final double cashOutExpenses;
  final double totalCashOut;
  final double closingCash;

  CashbookSummary({
    required this.openingCash,
    required this.cashInSales,
    required this.cashInCustomerPayments,
    required this.totalCashIn,
    required this.cashOutPurchases,
    required this.cashOutSupplierPayments,
    required this.cashOutExpenses,
    required this.totalCashOut,
    required this.closingCash,
  });
}

class ExpenseCategoryBreakdown {
  final String category;
  final double amount;
  final double percentage;

  ExpenseCategoryBreakdown({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

class ProductProfitBreakdown {
  final int productId;
  final String productName;
  final String category;
  final double quantitySold;
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double marginPercent;

  ProductProfitBreakdown({
    required this.productId,
    required this.productName,
    required this.category,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.marginPercent,
  });
}

class ProfitLossReport {
  final double totalRevenue;
  final double totalReturns;
  final double netRevenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double grossMarginPercent;
  final double totalExpenses;
  final double netProfit;
  final double netMarginPercent;
  final int totalInvoices;
  final List<ExpenseCategoryBreakdown> expenseBreakdown;
  final List<ProductProfitBreakdown> productBreakdown;

  ProfitLossReport({
    required this.totalRevenue,
    this.totalReturns = 0.0,
    double? netRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    double? grossMarginPercent,
    required this.totalExpenses,
    required this.netProfit,
    double? netMarginPercent,
    this.totalInvoices = 0,
    this.expenseBreakdown = const [],
    this.productBreakdown = const [],
  })  : netRevenue = netRevenue ?? (totalRevenue - totalReturns),
        grossMarginPercent = grossMarginPercent ??
            ((netRevenue ?? (totalRevenue - totalReturns)) > 0
                ? (grossProfit / (netRevenue ?? (totalRevenue - totalReturns)) * 100)
                : 0.0),
        netMarginPercent = netMarginPercent ??
            ((netRevenue ?? (totalRevenue - totalReturns)) > 0
                ? (netProfit / (netRevenue ?? (totalRevenue - totalReturns)) * 100)
                : 0.0);
}

class PartyBalanceReport {
  final int id;
  final String name;
  final String phone;
  final String address;
  final double balance;

  PartyBalanceReport({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.balance,
  });
}
