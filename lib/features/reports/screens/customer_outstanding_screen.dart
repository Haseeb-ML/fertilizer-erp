import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../customers/screens/customer_detail_screen.dart';

class CustomerOutstandingScreen extends ConsumerWidget {
  const CustomerOutstandingScreen({super.key});

  Future<void> _showPdfOptions(
    BuildContext context,
    WidgetRef ref,
    List<PartyBalanceReport> list,
  ) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Customer Receivables PDF Report (کسٹمر واجبات رپورٹ)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total ${list.length} Customers with Outstanding Dues',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final settings =
                      await ref.read(settingsRepoProvider).getSettings();
                  await PdfService.sharePartyBalanceReport(
                    reportTitle:
                        'Customer Receivables Report (کسٹمر واجبات رپورٹ)',
                    partyType: 'Customer',
                    list: list,
                    settings: settings,
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share PDF (واٹس ایپ پر شیئر کریں)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final settings =
                      await ref.read(settingsRepoProvider).getSettings();
                  await PdfService.printPartyBalanceReport(
                    reportTitle:
                        'Customer Receivables Report (کسٹمر واجبات رپورٹ)',
                    partyType: 'Customer',
                    list: list,
                    settings: settings,
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text(
                  'Print / Preview PDF (پی ڈی ایف کھولیں / پرنٹ کریں)',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
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
                      icon: const Icon(
                        Icons.picture_as_pdf,
                        color: AppColors.danger,
                      ),
                      tooltip: 'PDF رپورٹ کھولیں / شیئر کریں',
                      onPressed: () => _showPdfOptions(context, ref, list),
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
