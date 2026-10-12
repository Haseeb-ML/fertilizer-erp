import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/sale.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/search_bar_widget.dart';
import '../../../core/widgets/status_badge.dart';
import 'sales_pos_screen.dart';
import 'sale_detail_screen.dart';

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  final _searchController = TextEditingController();
  late Future<List<Sale>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _salesFuture = _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Sale>> _loadSales() async {
    final repo = ref.read(saleRepoProvider);
    return repo.getSales(search: _searchController.text.trim());
  }

  void _refreshSales() {
    setState(() {
      _salesFuture = _loadSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('sales_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: ref.tr('new_sale_pos'),
            onPressed: () async {
              final done = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const SalesPosScreen()),
              );
              if (done == true) _refreshSales();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: SearchBarWidget(
              controller: _searchController,
              hintText: 'Search by invoice # or customer name...',
              onChanged: (_) => _refreshSales(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: _salesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sales = snapshot.data ?? [];
                if (sales.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Sales Invoices Found',
                    description:
                        'Start selling fertilizer bags from the Point of Sale.',
                    buttonLabel: 'Open POS / New Sale',
                    onButtonPressed: () async {
                      final done = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const SalesPosScreen(),
                        ),
                      );
                      if (done == true) setState(() {});
                    },
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = sales[index];

                    return Card(
                      child: ListTile(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SaleDetailScreen(saleId: s.id!),
                            ),
                          );
                          setState(() {});
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.invoiceNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(s.grandTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Customer: ${s.customerName} • Date: ${s.saleDate}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StatusBadge(
                                  label: s.isReversed
                                      ? 'REVERSED'
                                      : s.paymentStatus,
                                  isDanger:
                                      s.isReversed ||
                                      s.paymentStatus == 'UNPAID',
                                  isWarning: s.paymentStatus == 'PARTIAL',
                                  isSuccess:
                                      !s.isReversed &&
                                      s.paymentStatus == 'PAID',
                                ),
                                if (s.balanceDue > 0)
                                  Text(
                                    'Due: ${CurrencyFormatter.format(s.balanceDue)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.danger,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final done = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const SalesPosScreen()),
          );
          if (done == true) setState(() {});
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.point_of_sale, color: Colors.white),
        label: const Text(
          'New Sale',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
