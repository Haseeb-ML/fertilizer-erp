import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'sales_report_screen.dart';
import 'profit_loss_report_screen.dart';
import 'inventory_report_screen.dart';
import 'customer_outstanding_screen.dart';
import 'supplier_payable_screen.dart';
import '../../expenses/screens/cashbook_screen.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Reports & Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportTile(
            context,
            icon: Icons.trending_up,
            color: AppColors.primary,
            title: 'Sales & Revenue Report',
            subtitle:
                'Daily, weekly, monthly sales and product-wise revenue analysis',
            destination: const SalesReportScreen(),
          ),
          const SizedBox(height: 12),

          _buildReportTile(
            context,
            icon: Icons.account_balance,
            color: AppColors.success,
            title: 'Profit & Loss Statement',
            subtitle:
                'Gross profit, cost of goods sold (COGS), expenses, and net profit',
            destination: const ProfitLossReportScreen(),
          ),
          const SizedBox(height: 12),

          _buildReportTile(
            context,
            icon: Icons.inventory_2,
            color: AppColors.secondary,
            title: 'Inventory & Valuation Report',
            subtitle:
                'Current stock quantities, FIFO valuation, and low-stock alerts',
            destination: const InventoryReportScreen(),
          ),
          const SizedBox(height: 12),

          _buildReportTile(
            context,
            icon: Icons.people,
            color: AppColors.danger,
            title: 'Customer Receivables (Outstanding)',
            subtitle: 'Credit ledger balances and unpaid dues from farmers',
            destination: const CustomerOutstandingScreen(),
          ),
          const SizedBox(height: 12),

          _buildReportTile(
            context,
            icon: Icons.factory,
            color: AppColors.warning,
            title: 'Supplier Payables Report',
            subtitle:
                'Unpaid liabilities and credit balances owed to fertilizer companies',
            destination: const SupplierPayableScreen(),
          ),
          const SizedBox(height: 12),

          _buildReportTile(
            context,
            icon: Icons.book,
            color: AppColors.info,
            title: 'Cashbook & Cash Flow',
            subtitle:
                'Daily opening/closing cash summary, sales receipts, and cash expenses',
            destination: const CashbookScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
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
          size: 16,
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
