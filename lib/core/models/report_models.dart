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

class ProfitLossReport {
  final double totalRevenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;

  ProfitLossReport({
    required this.totalRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
  });
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
