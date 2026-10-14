import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/providers/app_providers.dart';
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
              Text(
                'Supplier Statement PDF (${widget.supplier.name})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final settings =
                      await ref.read(settingsRepoProvider).getSettings();
                  await PdfService.shareLedgerStatement(
                    partyName: widget.supplier.name,
                    partyType: 'Supplier',
                    partyPhone: widget.supplier.phone,
                    partyAddress: widget.supplier.companyOrAddress,
                    entries: _entries,
                    currentBalance: widget.supplier.currentBalance,
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
                  await PdfService.printLedgerStatement(
                    partyName: widget.supplier.name,
                    partyType: 'Supplier',
                    partyPhone: widget.supplier.phone,
                    partyAddress: widget.supplier.companyOrAddress,
                    entries: _entries,
                    currentBalance: widget.supplier.currentBalance,
                    settings: settings,
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('Print / Preview Statement'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.supplier.name} - کھاتہ / Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF کھاتہ کھولیں / شیئر کریں',
            onPressed: _entries.isEmpty ? null : _exportPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.supplier.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.supplier.companyOrAddress.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.business,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.supplier.companyOrAddress,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (widget.supplier.phone.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.supplier.phone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: widget.supplier.currentBalance > 0
                        ? AppColors.warningBg
                        : AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.supplier.currentBalance > 0
                          ? AppColors.warning.withOpacity(0.3)
                          : AppColors.success.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.supplier.currentBalance > 0
                            ? 'قابل ادا بقایا'
                            : 'اکاؤنٹ کلیئر',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: widget.supplier.currentBalance > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(widget.supplier.currentBalance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: widget.supplier.currentBalance > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
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
                : RefreshIndicator(
                    onRefresh: _loadLedger,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                    if (e.totalBags > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary
                                              .withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.inventory_2,
                                              size: 12,
                                              color: AppColors.secondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${e.totalBags.toStringAsFixed(0)} Bags',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.secondary,
                                              ),
                                            ),
                                          ],
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
                                const SizedBox(height: 6),
                                Text(
                                  e.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (e.itemsDetails.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F8FA),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.shopping_bag_outlined,
                                              size: 13,
                                              color: AppColors.secondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Bags Detail (${e.totalBags.toStringAsFixed(0)} Total Bags):',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ...e.itemsDetails.map(
                                          (detail) => Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  '• ',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    detail,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
}
