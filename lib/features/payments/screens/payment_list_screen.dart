import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/payment.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import 'receive_payment_screen.dart';
import 'make_payment_screen.dart';

class PaymentListScreen extends ConsumerStatefulWidget {
  const PaymentListScreen({super.key});

  @override
  ConsumerState<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends ConsumerState<PaymentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Payment>> _loadPayments(String? partyType) async {
    final repo = ref.read(paymentRepoProvider);
    return repo.getPayments(partyType: partyType);
  }

  Future<void> _editOrDeletePayment(Payment p) async {
    if (p.id == null) return;
    final payRepo = ref.read(paymentRepoProvider);
    final amountCtrl = TextEditingController(text: p.amount.toStringAsFixed(0));
    final dateCtrl = TextEditingController(text: p.paymentDate);
    final notesCtrl = TextEditingController(text: p.notes);
    String method = p.paymentMethod;
    const methods = ['Cash', 'Bank Transfer', 'Cheque', 'Online'];
    if (!methods.contains(method)) method = 'Cash';

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
            p.paymentType == 'CUSTOMER_IN'
                ? 'Edit Customer Receipt'
                : 'Edit Supplier Payment',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (PKR)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: methods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setD(() => method = v ?? method),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes / Remarks'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              icon: const Icon(Icons.delete_forever, color: AppColors.danger, size: 18),
              label: const Text(
                'Delete',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'update'),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (action == null || action == 'cancel' || !mounted) return;

    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Payment Voucher?'),
          content: Text(
            'Are you sure you want to permanently delete this voucher of ${CurrencyFormatter.format(p.amount)}?\n(یہ واؤچر مکمل ڈیلیٹ ہو جائے گا اور کھاتہ درست ہو جائے گا)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      try {
        if (p.paymentType == 'CUSTOMER_IN') {
          await payRepo.deleteCustomerPayment(p.id!);
        } else {
          await payRepo.deleteSupplierPayment(p.id!);
        }
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment deleted successfully / واؤچر حذف ہو گیا'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot delete: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
      return;
    }

    // Update
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    try {
      if (p.paymentType == 'CUSTOMER_IN') {
        await payRepo.updateCustomerPayment(
          paymentId: p.id!,
          amount: amount,
          paymentDate:
              dateCtrl.text.trim().isEmpty ? p.paymentDate : dateCtrl.text.trim(),
          paymentMethod: method,
          notes: notesCtrl.text.trim(),
        );
      } else {
        await payRepo.updateSupplierPayment(
          paymentId: p.id!,
          amount: amount,
          paymentDate:
              dateCtrl.text.trim().isEmpty ? p.paymentDate : dateCtrl.text.trim(),
          paymentMethod: method,
          notes: notesCtrl.text.trim(),
        );
      }
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment updated successfully / واؤچر اپڈیٹ ہو گیا'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot update: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments & Vouchers'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All Vouchers'),
            Tab(text: 'Customer In'),
            Tab(text: 'Supplier Out'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPaymentList(null),
          _buildPaymentList('CUSTOMER'),
          _buildPaymentList('SUPPLIER'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const ReceivePaymentScreen(),
                      ),
                    );
                    if (res == true) setState(() {});
                  },
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: const Text('Receive Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const MakePaymentScreen(),
                      ),
                    );
                    if (res == true) setState(() {});
                  },
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: const Text('Pay Supplier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentList(String? partyType) {
    return FutureBuilder<List<Payment>>(
      future: _loadPayments(partyType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const EmptyStateView(
            icon: Icons.payments_outlined,
            title: 'No Payment Vouchers Found',
            description:
                'Record customer receipts or supplier payments using the buttons below.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final p = list[index];
            final isCustomerIn = p.paymentType == 'CUSTOMER_IN';

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: isCustomerIn
                      ? AppColors.successBg
                      : AppColors.dangerBg,
                  child: Icon(
                    isCustomerIn ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isCustomerIn ? AppColors.success : AppColors.danger,
                    size: 20,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p.partyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${isCustomerIn ? '+' : '-'}${CurrencyFormatter.format(p.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isCustomerIn
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(
                      '${isCustomerIn ? 'Customer Receipt' : 'Supplier Payment'} • ${p.paymentDate} • ${p.paymentMethod}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (p.notes.isNotEmpty || p.referenceNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${p.referenceNumber.isNotEmpty ? 'Ref: ${p.referenceNumber} • ' : ''}${p.notes}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Edit / Delete Payment',
                  onPressed: () => _editOrDeletePayment(p),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
