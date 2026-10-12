import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';

class SupplierLedgerScreen extends ConsumerStatefulWidget {
  final Supplier supplier;

  const SupplierLedgerScreen({super.key, required this.supplier});

  @override
  ConsumerState<SupplierLedgerScreen> createState() =>
      _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends ConsumerState<SupplierLedgerScreen> {
  List<LedgerEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    final repo = ref.read(supplierRepoProvider);
    final list = await repo.getSupplierLedger(widget.supplier.id!);
    setState(() {
      _entries = list;
      _isLoading = false;
    });
  }

  Future<void> _exportPdf() async {
    final settings = await ref.read(settingsRepoProvider).getSettings();
    await PdfService.printLedgerStatement(
      partyName: widget.supplier.name,
      partyType: 'Supplier',
      entries: _entries,
      currentBalance: widget.supplier.currentBalance,
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
        'Debit (Paid PKR)',
        'Credit (Billed PKR)',
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
          'Supplier_Ledger_${widget.supplier.name.replaceAll(' ', '_')}.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.supplier.name} Ledger'),
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
                      widget.supplier.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.supplier.phone.isNotEmpty)
                      Text(
                        'Phone: ${widget.supplier.phone}',
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
                      'Total Payable Balance',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(widget.supplier.currentBalance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: widget.supplier.currentBalance > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                ? const EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Ledger Entries',
                    description:
                        'Purchases and payments made to this supplier will appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = _entries[index];

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
                                      color: AppColors.secondary,
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
                                  if (e.credit > 0)
                                    Text(
                                      'Credit (Purchased): +${CurrencyFormatter.format(e.credit)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (e.debit > 0)
                                    Text(
                                      'Debit (Paid): -${CurrencyFormatter.format(e.debit)}',
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
