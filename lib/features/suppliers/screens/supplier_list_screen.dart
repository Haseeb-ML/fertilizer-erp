import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/supplier.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/search_bar_widget.dart';
import 'supplier_form_screen.dart';
import 'supplier_detail_screen.dart';
import 'supplier_ledger_screen.dart';

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Supplier>> _loadSuppliers() async {
    final repo = ref.read(supplierRepoProvider);
    return repo.getSuppliers(search: _searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers & Companies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Add Supplier',
            onPressed: () async {
              final added = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
              );
              if (added == true) setState(() {});
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
              hintText: 'Search by supplier or company name...',
              onChanged: (val) => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Supplier>>(
              future: _loadSuppliers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final suppliers = snapshot.data ?? [];
                if (suppliers.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.65,
                          child: EmptyStateView(
                            icon: Icons.factory_outlined,
                            title: 'No Suppliers Found',
                            description:
                                'Add fertilizer manufacturers & distributors to record purchases.',
                            buttonLabel: 'Add First Supplier',
                            onButtonPressed: () async {
                              final added =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => const SupplierFormScreen(),
                                ),
                              );
                              if (added == true) setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: suppliers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = suppliers[index];

                      return Card(
                        child: ListTile(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SupplierDetailScreen(supplierId: s.id!),
                              ),
                            );
                            setState(() {});
                          },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondary.withOpacity(
                            0.12,
                          ),
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(s.currentBalance),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: s.currentBalance > 0
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.phone.isNotEmpty
                                  ? s.phone
                                  : (s.companyOrAddress.isNotEmpty
                                        ? s.companyOrAddress
                                        : 'No phone'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              s.currentBalance > 0
                                  ? 'Payable'
                                  : (s.currentBalance < 0
                                        ? 'Advance Paid'
                                        : 'Settled'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: s.currentBalance > 0
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.menu_book,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                          tooltip: 'Ledger',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SupplierLedgerScreen(supplier: s),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
          );
          if (added == true) setState(() {});
        },
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add_business, color: Colors.white),
      ),
    );
  }
}
