import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/supplier.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../payments/screens/make_payment_screen.dart';
import '../../purchases/screens/purchase_return_screen.dart';
import 'supplier_form_screen.dart';
import 'supplier_ledger_screen.dart';

class SupplierDetailScreen extends ConsumerStatefulWidget {
  final int supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
  Future<Supplier?> _fetchSupplier() async {
    return ref.read(supplierRepoProvider).getSupplierById(widget.supplierId);
  }

  Future<void> _deleteSupplier(Supplier supplier, {bool force = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Supplier?'),
          ],
        ),
        content: Text(
          force
              ? 'Warning: This will permanently delete supplier "${supplier.name}" along with all their purchase invoices, payments, and ledger history.\n\nAre you sure you want to proceed?'
              : 'Are you sure you want to delete supplier "${supplier.name}"?\n(کیا آپ واقعی اس سپلائر کو ڈیلیٹ کرنا چاہتے ہیں؟)',
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
            child: Text(force ? 'Force Delete All' : 'Delete (ڈیلیٹ کریں)'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(supplierRepoProvider);
    try {
      await repo.deleteSupplier(supplier.id!, force: force);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier "${supplier.name}" deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      if (!force && errorStr.contains('purchase invoice')) {
        await _deleteSupplier(supplier, force: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot delete supplier: $e'),
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
        title: const Text('Supplier Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Supplier (سپلائر ڈیلیٹ کریں)',
            onPressed: () async {
              final s = await _fetchSupplier();
              if (s != null && mounted) _deleteSupplier(s);
            },
          ),
        ],
      ),
      body: FutureBuilder<Supplier?>(
        future: _fetchSupplier(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final supplier = snapshot.data;
          if (supplier == null) {
            return const Center(child: Text('Supplier not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                supplier.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            StatusBadge(
                              label: supplier.isActive ? 'Active' : 'Inactive',
                              isSuccess: supplier.isActive,
                              isDanger: !supplier.isActive,
                            ),
                          ],
                        ),
                        if (supplier.phone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                supplier.phone,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                        if (supplier.companyOrAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                supplier.companyOrAddress,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Payable to Supplier',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  CurrencyFormatter.format(
                                    supplier.currentBalance,
                                  ),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: supplier.currentBalance > 0
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: () async {
                    final paid = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => MakePaymentScreen(
                          preselectedSupplierId: supplier.id,
                        ),
                      ),
                    );
                    if (paid == true) setState(() {});
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Make Payment to Supplier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () async {
                    final returned = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => PurchaseReturnScreen(
                          preselectedSupplier: supplier,
                        ),
                      ),
                    );
                    if (returned == true) setState(() {});
                  },
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Return Stock to Supplier (سپلائر واپسی)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SupplierLedgerScreen(supplier: supplier),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book),
                  label: const Text('View Full Supplier Ledger & Statement'),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => SupplierFormScreen(supplier: supplier),
                      ),
                    );
                    if (updated == true) setState(() {});
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Supplier Details'),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () => _deleteSupplier(supplier),
                  icon: const Icon(Icons.delete_forever, color: AppColors.danger),
                  label: const Text(
                    'Delete Supplier (سپلائر ڈیلیٹ کریں)',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
