import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/return_record.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/search_bar_widget.dart';
import '../../purchases/screens/purchase_return_screen.dart';
import '../../sales/screens/sale_return_screen.dart';

class ReturnsListScreen extends ConsumerStatefulWidget {
  const ReturnsListScreen({super.key});

  @override
  ConsumerState<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends ConsumerState<ReturnsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  late Future<List<ReturnRecord>> _returnsFuture;
  late Future<Map<String, double>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  void _loadData() {
    final repo = ref.read(returnRepoProvider);
    _returnsFuture = repo.getReturns(search: _searchController.text.trim());
    _summaryFuture = repo.getReturnsSummary();
  }

  void _refresh() {
    setState(() {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(returnsUpdateTriggerProvider, (_, __) {
      _refresh();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ref.tr('mod_returns') != 'mod_returns'
              ? ref.tr('mod_returns')
              : 'Returns Management (واپسی ریکارڈ)',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: ref.tr('refresh'),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'All (تمام)'),
            Tab(text: 'Customer (گاہک)'),
            Tab(text: 'Supplier (سپلائر)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Top Summary Banner
          FutureBuilder<Map<String, double>>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data ?? {};
              final custAmount = summary['totalCustomerReturns'] ?? 0.0;
              final custQty = summary['totalCustomerReturnQty'] ?? 0.0;
              final suppAmount = summary['totalSupplierReturns'] ?? 0.0;
              final suppQty = summary['totalSupplierReturnQty'] ?? 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Customer Returns',
                        urduTitle: 'گاہک سے واپسی',
                        amount: custAmount,
                        qty: custQty,
                        color: const Color(0xFFC62828),
                        icon: Icons.assignment_return_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Supplier Returns',
                        urduTitle: 'سپلائر کو واپسی',
                        amount: suppAmount,
                        qty: suppQty,
                        color: const Color(0xFF00796B),
                        icon: Icons.keyboard_return_rounded,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SearchBarWidget(
              controller: _searchController,
              hintText: 'Search by customer, supplier, product, invoice...',
              onChanged: (_) => _refresh(),
            ),
          ),

          // Main List View
          Expanded(
            child: FutureBuilder<List<ReturnRecord>>(
              future: _returnsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error loading returns: ${snapshot.error}'));
                }

                final allReturns = snapshot.data ?? [];
                final filtered = allReturns.where((r) {
                  if (_tabController.index == 1) {
                    return r.returnType == 'SALE_RETURN';
                  } else if (_tabController.index == 2) {
                    return r.returnType == 'PURCHASE_RETURN';
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.assignment_return_outlined,
                    title: 'No Returns Recorded',
                    description:
                        'Use the buttons below to record customer or supplier returns.',
                    buttonLabel: '+ Record Return (واپسی درج کریں)',
                    onButtonPressed: () => _showReturnChoiceModal(context),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildReturnCard(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const SaleReturnScreen(),
                      ),
                    );
                    if (res == true) _refresh();
                  },
                  icon: const Icon(Icons.assignment_return_outlined, size: 18),
                  label: const Text(
                    'Customer Return',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const PurchaseReturnScreen(),
                      ),
                    );
                    if (res == true) _refresh();
                  },
                  icon: const Icon(Icons.keyboard_return_rounded, size: 18),
                  label: const Text(
                    'Supplier Return',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String urduTitle,
    required double amount,
    required double qty,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '${qty.toStringAsFixed(0)} Bags Returned',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(ReturnRecord r) {
    final isCustomerReturn = r.returnType == 'SALE_RETURN';
    final cardColor = isCustomerReturn ? const Color(0xFFC62828) : const Color(0xFF00796B);
    final badgeLabel = isCustomerReturn ? 'Customer Return (گاہک)' : 'Supplier Return (سپلائر)';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCustomerReturn
                            ? Icons.assignment_return_outlined
                            : Icons.keyboard_return_rounded,
                        size: 13,
                        color: cardColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cardColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormatter.formatDate(DateTime.tryParse(r.returnDate) ?? DateTime.now()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Party Name
            Row(
              children: [
                Icon(
                  isCustomerReturn ? Icons.person : Icons.business,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.partyName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (r.originalInvoiceNumber.isNotEmpty &&
                    r.originalInvoiceNumber != 'DIRECT')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Inv: ${r.originalInvoiceNumber}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: const Text(
                      'Direct Return',
                      style: TextStyle(fontSize: 10, color: Color(0xFFE65100), fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Product Details and Qty
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${r.quantity.toStringAsFixed(0)}x ${r.productName} (@ ${CurrencyFormatter.format(r.unitPrice)})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(r.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cardColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Refund Mode & Reason
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: r.refundType == 'LEDGER_ADJUST'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r.refundType == 'LEDGER_ADJUST'
                        ? 'Ledger Adjusted (کھاتے میں)'
                        : 'Cash Refunded (نقد)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: r.refundType == 'LEDGER_ADJUST'
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                ),
                if (r.reason.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        r.reason,
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnChoiceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Record New Return (نئی واپسی درج کریں)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC62828).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFFC62828)),
                ),
                title: const Text('Customer Sales Return (گاہک سے مال واپسی)'),
                subtitle: const Text('Farmer returns excess or damaged bags'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final res = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const SaleReturnScreen()),
                  );
                  if (res == true) _refresh();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: Color(0xFF00796B)),
                ),
                title: const Text('Supplier Purchase Return (کمپنی کو مال واپسی)'),
                subtitle: const Text('Return stock back to fertilizer company'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final res = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const PurchaseReturnScreen()),
                  );
                  if (res == true) _refresh();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
