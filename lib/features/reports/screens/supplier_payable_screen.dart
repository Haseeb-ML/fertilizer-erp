import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../suppliers/screens/supplier_detail_screen.dart';

class SupplierPayableScreen extends ConsumerWidget {
  const SupplierPayableScreen({super.key});

  Future<void> _exportCsv(List<PartyBalanceReport> list) async {
    final rows = <List<dynamic>>[
      [
        'Supplier Payables Report',
        'Generated: ${DateTime.now().toString().substring(0, 10)}',
      ],
      ['Supplier / Company Name', 'Phone', 'Address', 'Payable Balance (PKR)'],
      ...list.map((s) => [s.name, s.phone, s.address, s.balance]),
    ];
    await CsvService.exportAndShareCsv(
      fileName: 'Supplier_Payables_Report.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(reportRepoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Payables Report')),
      body: FutureBuilder<List<PartyBalanceReport>>(
        future: repo.getSupplierPayableReport(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const EmptyStateView(
              icon: Icons.check_circle_outline,
              title: 'No Supplier Liabilities',
              description:
                  'All supplier and fertilizer company accounts are settled!',
            );
          }

          final total = list.fold(0.0, (acc, s) => acc + s.balance);

          return Column(
            children: [
              Container(
                color: AppColors.warningBg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Supplier Liabilities:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.download,
                        color: AppColors.warning,
                      ),
                      tooltip: 'Export CSV',
                      onPressed: () => _exportCsv(list),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final s = list[idx];
                    return Card(
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SupplierDetailScreen(supplierId: s.id),
                            ),
                          );
                        },
                        title: Text(
                          s.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          s.phone.isNotEmpty
                              ? s.phone
                              : (s.address.isNotEmpty ? s.address : 'Supplier'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(s.balance),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.warning,
                          ),
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
