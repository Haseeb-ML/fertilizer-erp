import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/language_selection_dialog.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../inventory/screens/product_detail_screen.dart';
import '../../inventory/screens/product_form_screen.dart';
import '../../inventory/screens/stock_adjustment_dialog.dart';
import '../../customers/screens/customer_form_screen.dart';
import '../../purchases/screens/purchase_detail_screen.dart';
import '../../purchases/screens/purchase_form_screen.dart';
import '../../sales/screens/sales_pos_screen.dart';
import '../../sales/screens/sale_detail_screen.dart';
import '../../payments/screens/receive_payment_screen.dart';
import '../../payments/screens/make_payment_screen.dart';
import '../../expenses/screens/expense_form_screen.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/quick_action_button.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final currentFilter = ref.watch(dashboardFilterProvider);
    final settingsAsync = ref.watch(businessSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              'assets/images/app_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.eco, color: Colors.white),
            ),
          ),
        ),
        leadingWidth: 48,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settingsAsync.value?.businessName ??
                  'Sheikh Uzair & Co - Fertilizer',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${settingsAsync.value?.city ?? 'Pakistan'} • ${DateFormatter.formatDate(DateTime.now())}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: ActionChip(
              avatar: Text(
                ref.watch(languageProvider) == 'ur' ? '🇵🇰' : '🇬🇧',
                style: const TextStyle(fontSize: 14),
              ),
              label: Text(
                ref.watch(languageProvider) == 'ur' ? 'اردو' : 'EN',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: Colors.white,
              onPressed: () {
                ref.read(languageProvider.notifier).toggleLanguage();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: ref.tr('refresh'),
            onPressed: () {
              ref.invalidate(dashboardDataProvider);
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 12),
                Text(
                  'Error loading dashboard: $err',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dashboardDataProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final columns = ResponsiveHelper.getDashboardColumns(context);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardDataProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getHorizontalPadding(context),
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text(ref.tr('today')),
                          selected: currentFilter == DashboardFilter.today,
                          selectedColor: AppColors.accentLight,
                          onSelected: (_) =>
                              ref.read(dashboardFilterProvider.notifier).state =
                                  DashboardFilter.today,
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: Text(ref.tr('this_week')),
                          selected: currentFilter == DashboardFilter.thisWeek,
                          selectedColor: AppColors.accentLight,
                          onSelected: (_) =>
                              ref.read(dashboardFilterProvider.notifier).state =
                                  DashboardFilter.thisWeek,
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: Text(ref.tr('this_month')),
                          selected: currentFilter == DashboardFilter.thisMonth,
                          selectedColor: AppColors.accentLight,
                          onSelected: (_) =>
                              ref.read(dashboardFilterProvider.notifier).state =
                                  DashboardFilter.thisMonth,
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: Text(ref.tr('all')),
                          selected: currentFilter == DashboardFilter.allTime,
                          selectedColor: AppColors.accentLight,
                          onSelected: (_) =>
                              ref.read(dashboardFilterProvider.notifier).state =
                                  DashboardFilter.allTime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick Actions Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              ref.tr('quick_actions'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                QuickActionButton(
                                  icon: Icons.point_of_sale,
                                  label: ref.tr('action_new_sale'),
                                  color: AppColors.primary,
                                  onTap: () async {
                                    final res = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SalesPosScreen(),
                                          ),
                                        );
                                    if (res == true)
                                      ref.invalidate(dashboardDataProvider);
                                  },
                                ),
                                QuickActionButton(
                                  icon: Icons.shopping_bag_outlined,
                                  label: ref.tr('action_purchase'),
                                  color: AppColors.secondary,
                                  onTap: () async {
                                    final res = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const PurchaseFormScreen(),
                                          ),
                                        );
                                    if (res == true)
                                      ref.invalidate(dashboardDataProvider);
                                  },
                                ),
                                QuickActionButton(
                                  icon: Icons.add_circle_outline,
                                  label: ref.tr('action_add_item'),
                                  color: AppColors.accent,
                                  onTap: () async {
                                    final res = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ProductFormScreen(),
                                          ),
                                        );
                                    if (res == true)
                                      ref.invalidate(dashboardDataProvider);
                                  },
                                ),
                                QuickActionButton(
                                  icon: Icons.person_add_outlined,
                                  label: ref.tr('action_new_customer'),
                                  color: const Color(0xFF0288D1),
                                  onTap: () async {
                                    final res = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const CustomerFormScreen(),
                                          ),
                                        );
                                    if (res == true)
                                      ref.invalidate(dashboardDataProvider);
                                  },
                                ),
                                QuickActionButton(
                                  icon: Icons.arrow_downward,
                                  label: ref.tr('action_receive_cash'),
                                  color: AppColors.success,
                                  onTap: () async {
                                    final res = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ReceivePaymentScreen(),
                                          ),
                                        );
                                    if (res == true)
                                      ref.invalidate(dashboardDataProvider);
                                  },
                                ),
                                QuickActionButton(
                                  icon: Icons.arrow_upward,
                                  label: ref.tr('action_pay_supplier'),
                                  color: AppColors.warning,
                                  onTap: () async {
                                    final res = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const MakePaymentScreen(),
                                          ),
                                        );
                                    if (res == true)
                                      ref.invalidate(dashboardDataProvider);
                                  },
                                ),
                                QuickActionButton(
                                  icon: Icons.receipt_long,
                                  label: ref.tr('action_add_expense'),
                                  color: AppColors.danger,
                                  onTap: () async {
                                    final res = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ExpenseFormScreen(),
                                          ),
                                        );
                                    if (res == true)
                                      ref.invalidate(dashboardDataProvider);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section Title
                  Text(
                    data.dateFilterLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Financial KPI Responsive Grid
                  GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: columns == 1 ? 2.8 : 1.35,
                    children: [
                      KpiCard(
                        title: ref.tr('todays_sales'),
                        value: CurrencyFormatter.format(data.todaySales),
                        subtitle: 'Period Revenue',
                        icon: Icons.trending_up,
                        iconColor: AppColors.primary,
                      ),
                      KpiCard(
                        title: ref.tr('todays_purchases'),
                        value: CurrencyFormatter.format(data.todayPurchases),
                        subtitle: 'Period Stock In',
                        icon: Icons.shopping_cart,
                        iconColor: AppColors.secondary,
                      ),
                      KpiCard(
                        title: ref.tr('expenses'),
                        value: CurrencyFormatter.format(data.todayExpenses),
                        subtitle: 'Operational Costs',
                        icon: Icons.receipt_outlined,
                        iconColor: AppColors.danger,
                      ),
                      KpiCard(
                        title: ref.tr('cash_in_hand'),
                        value: CurrencyFormatter.format(data.cashBalance),
                        subtitle: 'Cash in Hand',
                        icon: Icons.account_balance_wallet,
                        iconColor: AppColors.success,
                      ),
                      KpiCard(
                        title: ref.tr('customer_receivables'),
                        value: CurrencyFormatter.format(
                          data.customerReceivables,
                        ),
                        subtitle: 'Market Credit Due',
                        icon: Icons.people_outline,
                        iconColor: AppColors.danger,
                      ),
                      KpiCard(
                        title: ref.tr('supplier_payables'),
                        value: CurrencyFormatter.format(data.supplierPayables),
                        subtitle: 'Company Liabilities',
                        icon: Icons.factory_outlined,
                        iconColor: AppColors.warning,
                      ),
                      KpiCard(
                        title: ref.tr('inventory_title'),
                        value:
                            '${data.totalStockQuantity.toStringAsFixed(0)} units',
                        subtitle: 'Bags / Liters',
                        icon: Icons.inventory_2_outlined,
                        iconColor: const Color(0xFF0288D1),
                      ),
                      KpiCard(
                        title: ref.tr('stock_value'),
                        value: CurrencyFormatter.format(
                          data.inventoryValuation,
                        ),
                        subtitle: 'FIFO Cost Basis',
                        icon: Icons.attach_money,
                        iconColor: AppColors.primaryLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Low-Stock Warning Section
                  if (data.lowStockProducts.isNotEmpty) ...[
                    Card(
                      color: AppColors.warningBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                          color: AppColors.warning,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${ref.tr('low_stock_alerts')} (${data.lowStockProducts.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...data.lowStockProducts
                                .take(3)
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${p.name} (${p.brand})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${p.currentStock.toStringAsFixed(0)} ${p.unit}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.tune,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                              tooltip: ref.tr('action_adjust_stock'),
                                              onPressed: () async {
                                                final res =
                                                    await StockAdjustmentDialog.show(
                                                      context,
                                                      p,
                                                    );
                                                if (res == true)
                                                  ref.invalidate(
                                                    dashboardDataProvider,
                                                  );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Recent Transactions Section
                  Text(
                    ref.tr('recent_sales'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  if (data.recentSales.isEmpty && data.recentPurchases.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No transactions yet. Start by recording a sale or purchase.',
                          ),
                        ),
                      ),
                    )
                  else ...[
                    ...data.recentSales.map(
                      (s) => Card(
                        child: ListTile(
                          dense: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SaleDetailScreen(saleId: s.id!),
                              ),
                            );
                          },
                          leading: const CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.successBg,
                            child: Icon(
                              Icons.arrow_downward,
                              color: AppColors.success,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            'Sale: ${s.invoiceNumber} (${s.customerName})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Date: ${s.saleDate} • ${s.paymentMethod}',
                          ),
                          trailing: Text(
                            CurrencyFormatter.format(s.grandTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...data.recentPurchases.map(
                      (p) => Card(
                        child: ListTile(
                          dense: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PurchaseDetailScreen(purchaseId: p.id!),
                              ),
                            );
                          },
                          leading: const CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.warningBg,
                            child: Icon(
                              Icons.shopping_cart,
                              color: AppColors.warning,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            'Purchase: ${p.invoiceNumber} (${p.supplierName})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Date: ${p.purchaseDate} • ${p.paymentStatus}',
                          ),
                          trailing: Text(
                            CurrencyFormatter.format(p.grandTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
