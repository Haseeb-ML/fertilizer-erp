import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../sales/screens/sale_detail_screen.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerLedgerScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  late Customer _customer;
  List<LedgerEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    final repo = ref.read(customerRepoProvider);
    final db = await DatabaseHelper.instance.database;
    await CustomerRepository.reconcileCustomerLedger(db, widget.customer.id!);
    final updatedCust = await repo.getCustomerById(widget.customer.id!);
    final list = await repo.getCustomerLedger(widget.customer.id!);
    if (!mounted) return;
    setState(() {
      if (updatedCust != null) _customer = updatedCust;
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
                'Customer Statement PDF (${_customer.name})',
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
                    partyName: _customer.name,
                    partyType: 'Customer',
                    partyPhone: _customer.phone,
                    partyAddress: _customer.villageOrAddress,
                    entries: _entries,
                    currentBalance: _customer.currentBalance,
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
                    partyName: _customer.name,
                    partyType: 'Customer',
                    partyPhone: _customer.phone,
                    partyAddress: _customer.villageOrAddress,
                    entries: _entries,
                    currentBalance: _customer.currentBalance,
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


  Widget _buildTypeBadge(LedgerEntry e) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (e.transactionType) {
      case 'CASH_SALE':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'Cash Sale';
        icon = Icons.payments_outlined;
        break;
      case 'CREDIT_SALE':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        label = 'Credit Sale';
        icon = Icons.credit_card;
        break;
      case 'PARTIAL_SALE':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'Partial Credit Sale';
        icon = Icons.timelapse;
        break;
      case 'SALE':
        bg = const Color(0xFFEDE7F6);
        fg = const Color(0xFF512DA8);
        label = 'Sales Invoice';
        icon = Icons.receipt_long;
        break;
      case 'PAYMENT_RECEIVED':
        bg = const Color(0xFFE0F2F1);
        fg = const Color(0xFF00695C);
        label = 'Payment Received';
        icon = Icons.download_done;
        break;
      case 'SALE_RETURN':
        bg = const Color(0xFFFBE9E7);
        fg = const Color(0xFFD84315);
        label = 'Sales Return';
        icon = Icons.assignment_return;
        break;
      case 'SALE_REVERSAL':
      case 'SALE_REVERSAL_REFUND':
        bg = const Color(0xFFFFCDD2);
        fg = const Color(0xFFB71C1C);
        label = 'Invoice Reversed';
        icon = Icons.undo;
        break;
      case 'OPENING_BALANCE':
        bg = const Color(0xFFE1F5FE);
        fg = const Color(0xFF0277BD);
        label = 'Opening Balance';
        icon = Icons.account_balance_wallet;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = e.transactionType.replaceAll('_', ' ');
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_customer.name} - کھاتہ / Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Reconcile Ledger',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _loadLedger();
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Customer ledger reconciled successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF کھاتہ کھولیں / شیئر کریں',
            onPressed: _entries.isEmpty ? null : _exportPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // Customer Profile Banner (Name, Address, Phone & Balance)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _customer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _customer.villageOrAddress.trim().isNotEmpty
                                      ? _customer.villageOrAddress.trim()
                                      : 'پتہ درج نہیں (No Address)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _customer.villageOrAddress
                                            .trim()
                                            .isNotEmpty
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_customer.phone.isNotEmpty) ...[
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
                                  _customer.phone,
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
                        color: _customer.currentBalance > 0
                            ? AppColors.dangerBg
                            : AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _customer.currentBalance > 0
                              ? AppColors.danger.withOpacity(0.3)
                              : AppColors.success.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _customer.currentBalance > 0
                                ? 'واجب الادا بقایا'
                                : 'اکاؤنٹ کلیئر',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _customer.currentBalance > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(_customer.currentBalance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _customer.currentBalance > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ),
                        ],
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
                : RefreshIndicator(
                    onRefresh: _loadLedger,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final e = _entries[index];

                        return Card(
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: e.isSale
                                  ? AppColors.primary.withOpacity(0.2)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              int? saleId = e.referenceId;
                              if (saleId == null &&
                                  e.referenceNumber != null &&
                                  e.referenceNumber!.isNotEmpty) {
                                final s = await ref
                                    .read(saleRepoProvider)
                                    .getSaleByInvoiceNumber(e.referenceNumber!);
                                saleId = s?.id;
                              }
                              if (!context.mounted) return;
                              if (saleId != null &&
                                  (e.isSale ||
                                      e.transactionType == 'SALE_RETURN')) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SaleDetailScreen(saleId: saleId!),
                                  ),
                                );
                                if (!mounted) return;
                                _loadLedger();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Type Badge, Invoice Badge, Date
                                  Row(
                                    children: [
                                      _buildTypeBadge(e),
                                      const SizedBox(width: 8),
                                      if (e.referenceNumber != null &&
                                          e.referenceNumber!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.tag,
                                                size: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                              Text(
                                                e.referenceNumber!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const Spacer(),
                                      Text(
                                        e.transactionDate,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Description
                                  Text(
                                    e.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),

                                  // Sold Product Details (Requirement 1 & 3)
                                  if (e.itemsDetails.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.inventory_2_outlined,
                                                    size: 13,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Sold Product Details:',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (e.totalBags > 0)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      4,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${e.totalBags.toStringAsFixed(0)} Bags Total',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const Divider(
                                            height: 10,
                                            thickness: 0.5,
                                          ),
                                          ...e.itemsDetails.map(
                                            (detail) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 2,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    '• ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      detail,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: AppColors
                                                            .textPrimary,
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

                                  // Financial Breakdown for Sales (Invoice Total, Paid, Balance Due)
                                  if (e.isSale &&
                                      (e.invoicePaidAmount != null ||
                                          e.invoiceBalanceDue != null)) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Invoice: ${CurrencyFormatter.format(e.debit)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Paid: ${CurrencyFormatter.format(e.invoicePaidAmount ?? 0)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.success,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Due: ${CurrencyFormatter.format(e.invoiceBalanceDue ?? (e.debit - (e.invoicePaidAmount ?? 0)))}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  (e.invoiceBalanceDue ?? 0) > 0
                                                      ? AppColors.danger
                                                      : AppColors.success,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),

                                  // Balance Progression: Previous -> New & Debit/Credit
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Prev Bal: ${CurrencyFormatter.format(e.previousBalance)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.arrow_forward,
                                                size: 10,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                'New Bal: ${CurrencyFormatter.format(e.runningBalance)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: e.runningBalance > 0
                                                      ? AppColors.danger
                                                      : AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (e.debit > 0)
                                            Text(
                                              'Billed (+): ${CurrencyFormatter.format(e.debit)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.danger,
                                              ),
                                            ),
                                          if (e.credit > 0)
                                            Text(
                                              'Paid (-): ${CurrencyFormatter.format(e.credit)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.success,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Tap hint to view full sales invoice details
                                  if (e.isSale ||
                                      e.transactionType == 'SALE_RETURN') ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withOpacity(0.06),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            size: 13,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tap to view complete Sales Invoice details',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 10,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
