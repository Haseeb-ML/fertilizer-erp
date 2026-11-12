import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../payments/screens/receive_payment_screen.dart';
import '../../sales/screens/sale_return_screen.dart';
import 'customer_form_screen.dart';
import 'customer_ledger_screen.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  Future<Customer?> _fetchCustomer() async {
    return ref.read(customerRepoProvider).getCustomerById(widget.customerId);
  }

  Future<void> _deleteCustomer(Customer customer, {bool force = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Customer?'),
          ],
        ),
        content: Text(
          force
              ? 'Warning: This will permanently delete customer "${customer.name}" along with all their sales invoices, payments, and ledger history.\n\nAre you sure you want to proceed?'
              : 'Are you sure you want to delete customer "${customer.name}"?\n(کیا آپ واقعی اس گاہک کو ڈیلیٹ کرنا چاہتے ہیں؟)',
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

    final repo = ref.read(customerRepoProvider);
    try {
      await repo.deleteCustomer(customer.id!, force: force);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer "${customer.name}" deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      if (!force && errorStr.contains('sales invoice')) {
        await _deleteCustomer(customer, force: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot delete customer: $e'),
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
        title: const Text('Customer Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Customer (کسٹمر ڈیلیٹ کریں)',
            onPressed: () async {
              final c = await _fetchCustomer();
              if (c != null && mounted) _deleteCustomer(c);
            },
          ),
        ],
      ),
      body: FutureBuilder<Customer?>(
        future: _fetchCustomer(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final customer = snapshot.data;
          if (customer == null) {
            return const Center(child: Text('Customer not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
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
                                customer.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            StatusBadge(
                              label: customer.isActive ? 'Active' : 'Inactive',
                              isSuccess: customer.isActive,
                              isDanger: !customer.isActive,
                            ),
                          ],
                        ),
                        if (customer.phone.isNotEmpty) ...[
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
                                customer.phone,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                        if (customer.villageOrAddress.isNotEmpty) ...[
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
                                customer.villageOrAddress,
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
                                  'Outstanding Receivable',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  CurrencyFormatter.format(
                                    customer.currentBalance,
                                  ),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: customer.currentBalance > 0
                                        ? AppColors.danger
                                        : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            if (customer.creditLimit > 0)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Credit Limit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    CurrencyFormatter.format(
                                      customer.creditLimit,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
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

                // Action Buttons
                ElevatedButton.icon(
                  onPressed: () async {
                    final paid = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ReceivePaymentScreen(
                          preselectedCustomerId: customer.id,
                        ),
                      ),
                    );
                    if (paid == true) setState(() {});
                  },
                  icon: const Icon(Icons.payments),
                  label: const Text('Receive Payment From Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () async {
                    final returned = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => SaleReturnScreen(
                          preselectedCustomer: customer,
                        ),
                      ),
                    );
                    if (returned == true) setState(() {});
                  },
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Return Item from Customer (گاہک واپسی)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
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
                            CustomerLedgerScreen(customer: customer),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book),
                  label: const Text('View Full Customer Ledger & Statement'),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => CustomerFormScreen(customer: customer),
                      ),
                    );
                    if (updated == true) setState(() {});
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Customer Details'),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () => _deleteCustomer(customer),
                  icon: const Icon(Icons.delete_forever, color: AppColors.danger),
                  label: const Text(
                    'Delete Customer (کسٹمر ڈیلیٹ کریں)',
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
