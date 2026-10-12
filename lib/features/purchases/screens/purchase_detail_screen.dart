import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/purchase.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import 'purchase_return_screen.dart';

class PurchaseDetailScreen extends ConsumerStatefulWidget {
  final int purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  ConsumerState<PurchaseDetailScreen> createState() =>
      _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  Future<Purchase?> _fetchPurchase() async {
    return ref.read(purchaseRepoProvider).getPurchaseById(widget.purchaseId);
  }

  Future<void> _reverseInvoice(Purchase purchase) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Purchase Invoice?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reversing this purchase will deduct the stock added and reverse all ledger entries.',
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
            .read(purchaseRepoProvider)
            .reversePurchase(purchase.id!, reasonController.text.trim());
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase invoice reversed successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot reverse purchase: $e'),
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
      appBar: AppBar(title: const Text('Purchase Invoice Details')),
      body: FutureBuilder<Purchase?>(
        future: _fetchPurchase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snapshot.data;
          if (p == null) {
            return const Center(child: Text('Purchase invoice not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Card
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
                              p.invoiceNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            StatusBadge(
                              label: p.isReversed
                                  ? 'REVERSED'
                                  : p.paymentStatus,
                              isDanger:
                                  p.isReversed || p.paymentStatus == 'UNPAID',
                              isWarning: p.paymentStatus == 'PARTIAL',
                              isSuccess:
                                  !p.isReversed && p.paymentStatus == 'PAID',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Supplier: ${p.supplierName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Date: ${p.purchaseDate}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (p.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Notes: ${p.notes}',
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

                // Line items
                const Text(
                  'Purchased Products',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: p.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = p.items[idx];
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
                        _row('Subtotal:', CurrencyFormatter.format(p.subtotal)),
                        if (p.discount > 0)
                          _row(
                            'Discount:',
                            '- ${CurrencyFormatter.format(p.discount)}',
                            color: AppColors.success,
                          ),
                        if (p.freightCharges > 0)
                          _row(
                            'Freight / Transport:',
                            '+ ${CurrencyFormatter.format(p.freightCharges)}',
                          ),
                        const Divider(height: 20),
                        _row(
                          'Grand Total:',
                          CurrencyFormatter.format(p.grandTotal),
                          isBold: true,
                          fontSize: 16,
                        ),
                        _row(
                          'Amount Paid:',
                          CurrencyFormatter.format(p.paidAmount),
                          color: AppColors.success,
                        ),
                        _row(
                          'Balance Due:',
                          CurrencyFormatter.format(p.balanceDue),
                          isBold: true,
                          color: p.balanceDue > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (!p.isReversed) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      final returned = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => PurchaseReturnScreen(purchase: p),
                        ),
                      );
                      if (returned == true) setState(() {});
                    },
                    icon: const Icon(Icons.assignment_return),
                    label: const Text('Process Purchase Return'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: () => _reverseInvoice(p),
                    icon: const Icon(Icons.undo, color: AppColors.danger),
                    label: const Text('Reverse Purchase Invoice'),
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
