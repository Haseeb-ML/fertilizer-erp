import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/sale.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import 'sale_return_screen.dart';
import 'sales_pos_screen.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  final int saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  Future<Sale?> _fetchSale() async {
    return ref.read(saleRepoProvider).getSaleById(widget.saleId);
  }

  Future<void> _printInvoice(Sale sale) async {
    final settings = await ref.read(settingsRepoProvider).getSettings();
    await PdfService.printSaleInvoice(sale: sale, settings: settings);
  }

  Future<void> _shareInvoice(Sale sale) async {
    final settings = await ref.read(settingsRepoProvider).getSettings();
    await PdfService.shareSaleInvoice(sale: sale, settings: settings);
  }

  Future<void> _reverseSale(Sale sale) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Reverse Sales Invoice?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reversing this sale will restore the stock deducted and reverse all customer ledger effects.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Reversal *',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Confirm Reversal'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(saleRepoProvider)
            .reverseSale(sale.id!, reasonController.text.trim());

        ref.read(salesUpdateTriggerProvider.notifier).state++;
        ref.read(productsUpdateTriggerProvider.notifier).state++;
        ref.invalidate(dashboardDataProvider);

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale reversed and stock restored'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reversing sale: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Invoice Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Bill',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final sale = await _fetchSale();
              if (sale == null || !mounted) return;
              if (sale.isReversed) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Reversed bill edit nahi ho sakta'),
                  ),
                );
                return;
              }
              await navigator.push(
                MaterialPageRoute(
                  builder: (_) => SalesPosScreen(editSale: sale),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Recalculate Profit',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref
                  .read(saleRepoProvider)
                  .recalculateSaleProfit(widget.saleId);
              if (!mounted) return;
              setState(() {});
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Gross profit recalculated using current rates',
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF Invoice',
            onPressed: () async {
              final sale = await _fetchSale();
              if (sale != null) _shareInvoice(sale);
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Invoice',
            onPressed: () async {
              final sale = await _fetchSale();
              if (sale != null) _printInvoice(sale);
            },
          ),
        ],
      ),
      body: FutureBuilder<Sale?>(
        future: _fetchSale(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sale = snapshot.data;
          if (sale == null) {
            return const Center(child: Text('Sale invoice not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sale.invoiceNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            StatusBadge(
                              label: sale.isReversed
                                  ? 'REVERSED'
                                  : sale.paymentStatus,
                              isDanger:
                                  sale.isReversed ||
                                  sale.paymentStatus == 'UNPAID',
                              isWarning: sale.paymentStatus == 'PARTIAL',
                              isSuccess:
                                  !sale.isReversed &&
                                  sale.paymentStatus == 'PAID',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Customer: ${sale.customerName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Date: ${sale.saleDate} • Payment Mode: ${sale.paymentMethod}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (sale.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Notes: ${sale.notes}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Items Table
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sold Items',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Total Sold: ${sale.items.fold<double>(0.0, (acc, item) => acc + item.quantity).toStringAsFixed(0)} Bags',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sale.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = sale.items[idx];
                      final itemCostTotal = item.quantity * item.unitCost;
                      final itemProfit = item.totalPrice - itemCostTotal;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.quantity == item.quantity.roundToDouble()
                                    ? item.quantity.toInt().toString()
                                    : item.quantity.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                item.unit,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Rate: ${CurrencyFormatter.format(item.unitPrice)} / ${item.unit}'
                          '${item.unitCost > 0 ? ' • Cost: ${CurrencyFormatter.format(item.unitCost)}' : ''}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(item.totalPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (item.unitCost > 0)
                              Text(
                                'Profit: ${CurrencyFormatter.format(itemProfit)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Financial Breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row(
                          'Subtotal:',
                          CurrencyFormatter.format(sale.subtotal),
                        ),
                        if (sale.discount > 0)
                          _row(
                            'Discount:',
                            '- ${CurrencyFormatter.format(sale.discount)}',
                            color: AppColors.success,
                          ),
                        const Divider(height: 20),
                        _row(
                          'Grand Total:',
                          CurrencyFormatter.format(sale.grandTotal),
                          isBold: true,
                          fontSize: 16,
                        ),
                        _row(
                          'Amount Paid:',
                          CurrencyFormatter.format(sale.paidAmount),
                          color: AppColors.success,
                        ),
                        _row(
                          'Balance Due:',
                          CurrencyFormatter.format(sale.balanceDue),
                          isBold: true,
                          color: sale.balanceDue > 0
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                        const Divider(height: 20),
                        if (sale.totalCost > 0)
                          _row(
                            'Total Cost (COGS):',
                            CurrencyFormatter.format(sale.totalCost),
                            color: AppColors.textSecondary,
                          ),
                        _row(
                          'Gross Profit (Management View):',
                          CurrencyFormatter.format(sale.grossProfit),
                          color: AppColors.primary,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                ElevatedButton.icon(
                  onPressed: () => _shareInvoice(sale),
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF (واٹس ایپ پر شیئر کریں)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () => _printInvoice(sale),
                  icon: const Icon(Icons.print),
                  label: const Text('Print Invoice'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
                const SizedBox(height: 10),

                if (!sale.isReversed) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      final returned = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SaleReturnScreen(sale: sale),
                        ),
                      );
                      if (returned == true) setState(() {});
                    },
                    icon: const Icon(Icons.assignment_return),
                    label: const Text('Process Sales Return'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: () => _reverseSale(sale),
                    icon: const Icon(Icons.undo, color: AppColors.danger),
                    label: const Text('Reverse Sales Invoice'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(vertical: 2),
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
