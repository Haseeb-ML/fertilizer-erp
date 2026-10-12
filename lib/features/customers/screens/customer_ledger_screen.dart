import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerLedgerScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  List<LedgerEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    final repo = ref.read(customerRepoProvider);
    final list = await repo.getCustomerLedger(widget.customer.id!);
    setState(() {
      _entries = list;
      _isLoading = false;
    });
  }

  Future<void> _exportPdf() async {
    final settings = await ref.read(settingsRepoProvider).getSettings();
    await PdfService.printLedgerStatement(
      partyName: widget.customer.name,
      partyType: 'Customer',
      entries: _entries,
      currentBalance: widget.customer.currentBalance,
      settings: settings,
    );
  }

  Future<void> _exportCsv() async {
    final rows = <List<dynamic>>[
      [
        'Date',
        'Type',
        'Description',
        'Ref',
        'Debit (PKR)',
        'Credit (PKR)',
        'Running Balance (PKR)',
      ],
      ..._entries.map(
        (e) => [
          e.transactionDate,
          e.transactionType,
          e.description,
          e.referenceNumber ?? '',
          e.debit,
          e.credit,
          e.runningBalance,
        ],
      ),
    ];
    await CsvService.exportAndShareCsv(
      fileName:
          'Customer_Ledger_${widget.customer.name.replaceAll(' ', '_')}.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customer.name} Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Statement PDF',
            onPressed: _entries.isEmpty ? null : _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _entries.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Balance Card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.customer.phone.isNotEmpty)
                      Text(
                        'Phone: ${widget.customer.phone}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Outstanding Balance',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(widget.customer.currentBalance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: widget.customer.currentBalance > 0
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Ledger Table / List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                ? const EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Ledger Entries',
                    description:
                        'Sales and payment receipts will generate ledger entries automatically.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = _entries[index];
                      final isDebit = e.debit > 0;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.transactionDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'Bal: ${CurrencyFormatter.format(e.runningBalance)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (e.debit > 0)
                                    Text(
                                      'Debit (Billed): +${CurrencyFormatter.format(e.debit)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (e.credit > 0)
                                    Text(
                                      'Credit (Paid): -${CurrencyFormatter.format(e.credit)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
