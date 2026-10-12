import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/sale.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import 'sale_return_screen.dart';

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

  Future<void> _reverseSale(Sale sale) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Sales Invoice?'),
        content: Column(
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
                const Text(
                  'Sold Items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      return ListTile(
                        title: Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item.quantity.toStringAsFixed(0)} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)}',
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(item.totalPrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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
                  onPressed: () => _printInvoice(sale),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Print / Share PDF Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
