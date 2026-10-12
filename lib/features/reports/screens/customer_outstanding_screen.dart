import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../customers/screens/customer_detail_screen.dart';

class CustomerOutstandingScreen extends ConsumerWidget {
  const CustomerOutstandingScreen({super.key});

  Future<void> _exportCsv(List<PartyBalanceReport> list) async {
    final rows = <List<dynamic>>[
      [
        'Customer Outstanding Receivables Report',
        'Generated: ${DateTime.now().toString().substring(0, 10)}',
      ],
      [
        'Customer Name',
        'Phone',
        'Address / Village',
        'Outstanding Balance (PKR)',
      ],
      ...list.map((c) => [c.name, c.phone, c.address, c.balance]),
    ];
    await CsvService.exportAndShareCsv(
      fileName: 'Customer_Receivables_Report.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(reportRepoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Receivables Report')),
      body: FutureBuilder<List<PartyBalanceReport>>(
        future: repo.getCustomerOutstandingReport(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const EmptyStateView(
              icon: Icons.check_circle_outline,
              title: 'No Outstanding Receivables',
              description:
                  'All customer farmer accounts are currently settled!',
            );
          }

          final total = list.fold(0.0, (acc, c) => acc + c.balance);

          return Column(
            children: [
              Container(
                color: AppColors.dangerBg,
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
                          'Total Receivables Dues:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, color: AppColors.danger),
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
                    final c = list[idx];
                    return Card(
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerDetailScreen(customerId: c.id),
                            ),
                          );
                        },
                        title: Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          c.phone.isNotEmpty
                              ? c.phone
                              : (c.address.isNotEmpty ? c.address : 'Farmer'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(c.balance),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.danger,
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
