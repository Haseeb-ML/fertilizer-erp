import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/product.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/kpi_card.dart';

class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  ConsumerState<InventoryReportScreen> createState() =>
      _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen> {
  Future<void> _exportCsv(
    InventoryValuationReport valuation,
    List<Product> products,
  ) async {
    final rows = <List<dynamic>>[
      [
        'Inventory & Valuation Report',
        'Generated: ${DateTime.now().toString().substring(0, 10)}',
      ],
      ['Total Products Count', valuation.totalProducts],
      ['Total Stock Quantity', valuation.totalStockQuantity],
      ['Total Cost Valuation (PKR)', valuation.totalCostValue],
      ['Total Retail Valuation (PKR)', valuation.totalRetailValue],
      ['Potential Profit (PKR)', valuation.potentialProfit],
      [],
      ['Product Breakdown'],
      [
        'Product Name',
        'Category',
        'SKU',
        'Current Stock',
        'Unit',
        'Cost Rate (PKR)',
        'Selling Rate (PKR)',
        'Total Valuation (PKR)',
        'Status',
      ],
      ...products.map(
        (p) => [
          p.name,
          p.category,
          p.sku,
          p.currentStock,
          p.unit,
          p.purchasePrice,
          p.sellingPrice,
          p.inventoryValuation,
          p.isLowStock ? 'LOW STOCK' : 'OK',
        ],
      ),
    ];

    await CsvService.exportAndShareCsv(
      fileName: 'Inventory_Valuation_Report.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportRepo = ref.watch(reportRepoProvider);
    final productRepo = ref.watch(productRepoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Valuation Report')),
      body: FutureBuilder(
        future: Future.wait([
          reportRepo.getInventoryValuationReport(),
          productRepo.getProducts(onlyActive: true),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final val = snapshot.data![0] as InventoryValuationReport;
          final products = snapshot.data![1] as List<Product>;

          return Column(
            children: [
              // Export Header Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${val.totalProducts} Active Products in Stock',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.download,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Export CSV',
                      onPressed: () => _exportCsv(val, products),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // KPI Cards Grid
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: KpiCard(
                            title: 'Total Stock Quantity',
                            value:
                                '${val.totalStockQuantity.toStringAsFixed(0)} bags/units',
                            icon: Icons.inventory,
                            iconColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: KpiCard(
                            title: 'Cost Valuation (FIFO)',
                            value: CurrencyFormatter.format(val.totalCostValue),
                            icon: Icons.account_balance_wallet,
                            iconColor: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: KpiCard(
                            title: 'Retail / Sale Value',
                            value: CurrencyFormatter.format(
                              val.totalRetailValue,
                            ),
                            icon: Icons.store,
                            iconColor: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: KpiCard(
                            title: 'Low Stock Alerts',
                            value: '${val.lowStockCount} items',
                            icon: Icons.warning_amber,
                            iconColor: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Product Table / List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final p = products[idx];
                    return Card(
                      child: ListTile(
                        dense: true,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${p.currentStock.toStringAsFixed(0)} ${p.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: p.isLowStock
                                    ? AppColors.warning
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${p.brand} • ${p.category}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'Valuation: ${CurrencyFormatter.format(p.inventoryValuation)}',
                              style: const TextStyle(
                                fontSize: 11,
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
}
