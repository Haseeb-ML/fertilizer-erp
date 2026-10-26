import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/language_provider.dart';
import '../../core/localization/language_selection_dialog.dart';
import '../purchases/screens/purchase_list_screen.dart';
import '../customers/screens/customer_list_screen.dart';
import '../suppliers/screens/supplier_list_screen.dart';
import '../payments/screens/payment_list_screen.dart';
import '../expenses/screens/expense_list_screen.dart';
import '../expenses/screens/cashbook_screen.dart';
import '../reports/screens/reports_hub_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../settings/screens/backup_restore_screen.dart';

class MoreMenuScreen extends ConsumerWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(languageProvider);
    final isUrdu = currentLang == 'ur';

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('modules_header')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar: Text(
                isUrdu ? '🇵🇰' : '🇬🇧',
                style: const TextStyle(fontSize: 14),
              ),
              label: Text(
                isUrdu ? 'اردو' : 'EN',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: Colors.white,
              onPressed: () => showLanguageSelectionDialog(context, ref),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Official Brand Header
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F3B2E), Color(0xFF1B4332)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.eco, size: 50, color: Colors.amber),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SHEIKH UZAIR & CO',
                        style: TextStyle(
                          color: Color(0xFFF3C623),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUrdu ? 'کھاد بزنس ای آر پی' : 'FERTILIZER BUSINESS ERP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUrdu ? 'زراعت • غذائیت • خوشحالی' : 'Agriculture • Nutrition • Prosperity',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Prominent Language Switcher Tile
          Card(
            color: const Color(0xFFF1F8E9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFAED581)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.g_translate, color: AppColors.primary, size: 24),
              ),
              title: Text(
                ref.tr('mod_language'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  ref.tr('mod_language_sub'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isUrdu ? '🇵🇰 اردو' : '🇬🇧 EN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
              onTap: () => showLanguageSelectionDialog(context, ref),
            ),
          ),
          const SizedBox(height: 10),



          _menuTile(
            context,
            icon: Icons.shopping_cart,
            color: AppColors.secondary,
            title: ref.tr('mod_purchases'),
            subtitle: ref.tr('mod_purchases_sub'),
            destination: const PurchaseListScreen(),
          ),
          const SizedBox(height: 10),

          _menuTile(
            context,
            icon: Icons.people,
            color: const Color(0xFF0288D1),
            title: ref.tr('mod_customers'),
            subtitle: ref.tr('mod_customers_sub'),
            destination: const CustomerListScreen(),
          ),
          const SizedBox(height: 10),

          _menuTile(
            context,
            icon: Icons.factory,
            color: AppColors.warning,
            title: ref.tr('mod_suppliers'),
            subtitle: ref.tr('mod_suppliers_sub'),
            destination: const SupplierListScreen(),
          ),
          const SizedBox(height: 10),

          _menuTile(
            context,
            icon: Icons.payments,
            color: AppColors.success,
            title: ref.tr('mod_payments'),
            subtitle: ref.tr('mod_payments_sub'),
            destination: const PaymentListScreen(),
          ),
          const SizedBox(height: 10),

          _menuTile(
            context,
            icon: Icons.receipt_long,
            color: AppColors.danger,
            title: ref.tr('mod_expenses'),
            subtitle: ref.tr('mod_expenses_sub'),
            destination: const ExpenseListScreen(),
          ),
          const SizedBox(height: 10),

          _menuTile(
            context,
            icon: Icons.account_balance_wallet,
            color: const Color(0xFF5E35B1),
            title: ref.tr('mod_cashbook'),
            subtitle: ref.tr('mod_cashbook_sub'),
            destination: const CashbookScreen(),
          ),
          const SizedBox(height: 10),

          _menuTile(
            context,
            icon: Icons.bar_chart,
            color: AppColors.primary,
            title: ref.tr('mod_reports'),
            subtitle: ref.tr('mod_reports_sub'),
            destination: const ReportsHubScreen(),
          ),
          const SizedBox(height: 10),

          _menuTile(
            context,
            icon: Icons.settings,
            color: const Color(0xFF546E7A),
            title: ref.tr('mod_settings'),
            subtitle: ref.tr('mod_settings_sub'),
            destination: const SettingsScreen(),
          ),
          const SizedBox(height: 10),

          _menuTile(
            context,
            icon: Icons.storage_rounded,
            color: const Color(0xFF00796B),
            title: ref.tr('data_storage'),
            subtitle: ref.tr('data_storage_sub'),
            destination: const BackupRestoreScreen(),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: AppColors.textMuted,
        ),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => destination));
        },
      ),
    );
  }
}
