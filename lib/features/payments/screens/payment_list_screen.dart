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
              ),
            );
          },
        );
      },
    );
  }
}
