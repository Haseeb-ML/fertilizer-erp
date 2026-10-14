import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../suppliers/screens/supplier_detail_screen.dart';

class SupplierPayableScreen extends ConsumerWidget {
  const SupplierPayableScreen({super.key});

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
                'Supplier Payables PDF Report (سپلائر ادائیگیاں رپورٹ)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total ${list.length} Suppliers with Outstanding Payables',
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
                        'Supplier Payables Report (سپلائر ادائیگیاں رپورٹ)',
                    partyType: 'Supplier',
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
                        'Supplier Payables Report (سپلائر ادائیگیاں رپورٹ)',
                    partyType: 'Supplier',
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
                        Icons.picture_as_pdf,
                        color: AppColors.warning,
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
