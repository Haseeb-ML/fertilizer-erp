import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

class ProfitLossReportScreen extends ConsumerStatefulWidget {
  const ProfitLossReportScreen({super.key});

  @override
  ConsumerState<ProfitLossReportScreen> createState() =>
      _ProfitLossReportScreenState();
}

class _ProfitLossReportScreenState
    extends ConsumerState<ProfitLossReportScreen> {
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  Future<void> _exportCsv(ProfitLossReport report) async {
    final rows = <List<dynamic>>[
      [
        'Profit & Loss Statement',
        'From: ${DateFormatter.formatDate(_fromDate)}',
        'To: ${DateFormatter.formatDate(_toDate)}',
      ],
      [],
      ['Total Sales Revenue (PKR)', report.totalRevenue],
      ['Less: Cost of Goods Sold (FIFO COGS) (PKR)', report.costOfGoodsSold],
      ['Gross Profit (PKR)', report.grossProfit],
      ['Less: Operational Expenses (PKR)', report.totalExpenses],
      ['Estimated Net Profit (PKR)', report.netProfit],
    ];

    await CsvService.exportAndShareCsv(
      fileName: 'Profit_and_Loss_Statement.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(reportRepoProvider);
    final fromStr = DateFormatter.toSqlDate(_fromDate);
    final toStr = DateFormatter.toSqlDate(_toDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Profit & Loss Statement')),
      body: FutureBuilder<ProfitLossReport>(
        future: repo.getProfitLossReport(fromDate: fromStr, toDate: toStr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final report = snapshot.data!;
          final isNetProfitPositive = report.netProfit >= 0;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Date Range Bar
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
                            if (picked != null)
                              setState(() => _toDate = picked);
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
                        onPressed: () => _exportCsv(report),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Net Profit Big Banner Card
                      Card(
                        color: isNetProfitPositive
                            ? AppColors.successBg
                            : AppColors.dangerBg,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                isNetProfitPositive
                                    ? 'Estimated Net Profit'
                                    : 'Net Loss',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isNetProfitPositive
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.format(
                                  report.netProfit.abs(),
                                ),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isNetProfitPositive
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Itemized Breakdown Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Trading Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _row(
                                'Sales Revenue',
                                CurrencyFormatter.format(report.totalRevenue),
                              ),
                              _row(
                                'Cost of Goods Sold (COGS - FIFO)',
                                '- ${CurrencyFormatter.format(report.costOfGoodsSold)}',
                              ),
                              const Divider(height: 20),
                              _row(
                                'Gross Profit',
                                CurrencyFormatter.format(report.grossProfit),
                                isBold: true,
                                fontSize: 15,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Operating Expenses',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _row(
                                'Total Operating Expenses',
                                '- ${CurrencyFormatter.format(report.totalExpenses)}',
                                color: AppColors.danger,
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              _row(
                                'Net Profit / (Loss)',
                                CurrencyFormatter.format(report.netProfit),
                                isBold: true,
                                fontSize: 17,
                                color: isNetProfitPositive
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
