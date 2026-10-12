import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/supplier.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../payments/screens/make_payment_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Profile')),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
