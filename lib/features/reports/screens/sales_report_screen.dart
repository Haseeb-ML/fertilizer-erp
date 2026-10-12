import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  Future<void> _exportCsv(
    SalesSummaryReport summary,
    List<ProductSalesReport> products,
  ) async {
    final rows = <List<dynamic>>[
      [
        'Sales & Revenue Report',
        'From: ${DateFormatter.formatDate(_fromDate)}',
        'To: ${DateFormatter.formatDate(_toDate)}',
      ],
      ['Total Sales (PKR)', summary.totalSales],
      ['Total Discounts (PKR)', summary.totalDiscount],
      ['Net Sales (PKR)', summary.netSales],
      ['Cash Collected (PKR)', summary.totalPaid],
      ['Receivables Balance (PKR)', summary.totalBalanceDue],
      ['Gross Profit (PKR)', summary.grossProfit],
      [],
      ['Product Wise Sales Breakdown'],
      [
        'Product Name',
        'Category',
        'Quantity Sold',
        'Revenue (PKR)',
        'Cost (PKR)',
        'Profit (PKR)',
      ],
      ...products.map(
        (p) => [
          p.productName,
          p.category,
          p.totalQuantity,
          p.totalRevenue,
          p.totalCost,
          p.profit,
        ],
      ),
    ];

    await CsvService.exportAndShareCsv(
      fileName: 'Sales_Report.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(reportRepoProvider);
    final fromStr = DateFormatter.toSqlDate(_fromDate);
    final toStr = DateFormatter.toSqlDate(_toDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales & Revenue Report')),
      body: FutureBuilder(
        future: Future.wait([
          repo.getSalesSummaryReport(fromDate: fromStr, toDate: toStr),
          repo.getProductWiseSalesReport(fromDate: fromStr, toDate: toStr),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final summary = snapshot.data![0] as SalesSummaryReport;
          final products = snapshot.data![1] as List<ProductSalesReport>;

          return Column(
            children: [
              // Date Range Picker
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _fromDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null)
                            setState(() => _fromDate = picked);
                        },
                        icon: const Icon(Icons.date_range, size: 14),
                        label: Text(
                          'From: ${DateFormatter.formatDate(_fromDate)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _toDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _toDate = picked);
                        },
                        icon: const Icon(Icons.event, size: 14),
                        label: Text(
                          'To: ${DateFormatter.formatDate(_toDate)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.download,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Export CSV',
                      onPressed: () => _exportCsv(summary, products),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Summary Stats Card
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _metricRow(
                          'Total Sales Revenue:',
                          CurrencyFormatter.format(summary.netSales),
                          isBold: true,
                          fontSize: 15,
                        ),
                        const Divider(height: 12),
                        _metricRow(
                          'Paid / Cash Collected:',
                          CurrencyFormatter.format(summary.totalPaid),
                          color: AppColors.success,
                        ),
                        _metricRow(
                          'Outstanding Credit Due:',
                          CurrencyFormatter.format(summary.totalBalanceDue),
                          color: AppColors.danger,
                        ),
                        _metricRow(
                          'Total Invoices Count:',
                          '${summary.invoiceCount} invoices',
                        ),
                        const Divider(height: 12),
                        _metricRow(
                          'Gross Profit (Revenue - COGS):',
                          CurrencyFormatter.format(summary.grossProfit),
                          isBold: true,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Product Breakdown Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Product-Wise Sales (${products.length} Products)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // Products List
              Expanded(
                child: products.isEmpty
                    ? const Center(
                        child: Text(
                          'No product sales recorded in this date range',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, idx) {
                          final p = products[idx];
                          return Card(
                            child: ListTile(
                              dense: true,
                              title: Text(
                                p.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                '${p.totalQuantity.toStringAsFixed(0)} units sold • ${p.category}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(p.totalRevenue),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Profit: ${CurrencyFormatter.format(p.profit)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
