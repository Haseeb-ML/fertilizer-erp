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

class _ReturnSlipGroup {
  final List<ReturnRecord> items;

  _ReturnSlipGroup(this.items);

  ReturnRecord get first => items.first;
  String get returnType => first.returnType;
  String get partyName => first.partyName;
  String get returnDate => first.returnDate;
  String get originalInvoiceNumber => first.originalInvoiceNumber;
  String get refundType => first.refundType;
  String get reason => first.reason;

  double get totalAmount =>
      items.fold<double>(0.0, (sum, r) => sum + r.totalAmount);

  double get totalQty =>
      items.fold<double>(0.0, (sum, r) => sum + r.quantity);
}

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF1B4332),
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(height: 36, text: 'All (تمام)'),
                Tab(height: 36, text: 'Customer (گاہک)'),
                Tab(height: 36, text: 'Supplier (سپلائر)'),
              ],
            ),
          ),
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

                final grouped = _groupReturns(filtered);

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: grouped.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final group = grouped[index];
                    return _buildReturnCard(group);
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

  List<_ReturnSlipGroup> _groupReturns(List<ReturnRecord> records) {
    final List<_ReturnSlipGroup> groups = [];
    for (final r in records) {
      final rTime = DateTime.tryParse(r.createdAt);
      bool addedToExisting = false;
      for (final g in groups) {
        final gFirst = g.first;
        final gTime = DateTime.tryParse(gFirst.createdAt);
        final bool closeInTime = (rTime != null && gTime != null)
            ? rTime.difference(gTime).inSeconds.abs() <= 60
            : r.createdAt == gFirst.createdAt;
        if (gFirst.returnType == r.returnType &&
            gFirst.partyName == r.partyName &&
            gFirst.returnDate == r.returnDate &&
            gFirst.refundType == r.refundType &&
            gFirst.originalInvoiceNumber == r.originalInvoiceNumber &&
            closeInTime) {
          g.items.add(r);
          addedToExisting = true;
          break;
        }
      }
      if (!addedToExisting) {
        groups.add(_ReturnSlipGroup([r]));
      }
    }
    return groups;
  }

  Future<void> _deleteReturnGroup(_ReturnSlipGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Return Slip?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this return slip (${group.items.length} items, ${CurrencyFormatter.format(group.totalAmount)})?\n\nThis will restore product stock inventory and reverse the ledger balance automatically.\n(اس مال واپسی کو ختم کرنے سے اسٹاک دوبارہ بحال ہو جائے گا اور کھاتہ درست ہو جائے گا)',
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
            child: const Text('Delete Permanently (حذف کریں)'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(returnRepoProvider);
    try {
      for (final item in group.items) {
        if (item.id != null) {
          await repo.deleteReturn(item.id!);
        }
      }
      ref.read(productsUpdateTriggerProvider.notifier).state++;
      ref.read(salesUpdateTriggerProvider.notifier).state++;
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return deleted and stock restored successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot delete return: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildReturnCard(_ReturnSlipGroup group) {
    final isCustomerReturn = group.returnType == 'SALE_RETURN';
    final cardColor = isCustomerReturn
        ? const Color(0xFFC62828)
        : const Color(0xFF00796B);
    final badgeLabel = isCustomerReturn
        ? 'Customer Return (گاہک)'
        : 'Supplier Return (سپلائر)';
    final items = group.items;

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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.1),
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
                    if (items.length > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${items.length} Products',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormatter.formatDate(
                          DateTime.tryParse(group.returnDate) ?? DateTime.now()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _deleteReturnGroup(group),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
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
                    group.partyName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (group.originalInvoiceNumber.isNotEmpty &&
                    group.originalInvoiceNumber != 'DIRECT')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Inv: ${group.originalInvoiceNumber}',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: const Text(
                      'Direct Return',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Product Details (All returned products in this slip grouped together)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${items[i].quantity.toStringAsFixed(0)}x ${items[i].productName} (@ ${CurrencyFormatter.format(items[i].unitPrice)})',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(items[i].totalAmount),
                          style: TextStyle(
                            fontWeight: items.length > 1
                                ? FontWeight.w600
                                : FontWeight.bold,
                            fontSize: items.length > 1 ? 13 : 14,
                            color: items.length > 1
                                ? AppColors.textPrimary
                                : cardColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (items.length > 1) ...[
                    const Divider(height: 14, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Return (${items.length} Products, ${group.totalQty.toStringAsFixed(0)} Bags):',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(group.totalAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: cardColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Refund Mode & Reason
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: group.refundType == 'LEDGER_ADJUST'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    group.refundType == 'LEDGER_ADJUST'
                        ? 'Ledger Adjusted (کھاتے میں)'
                        : 'Cash Refunded (نقد)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: group.refundType == 'LEDGER_ADJUST'
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                ),
                if (group.reason.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        group.reason,
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
