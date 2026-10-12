import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/repositories/cashbook_repository.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';

class CashbookScreen extends ConsumerStatefulWidget {
  const CashbookScreen({super.key});

  @override
  ConsumerState<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends ConsumerState<CashbookScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(cashbookRepoProvider);
    final dateStr = DateFormatter.toSqlDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Cashbook (Rokarr)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
        ],
      ),
      body: FutureBuilder<CashbookSummary>(
        future: repo.getDailyCashbookSummary(dateStr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final summary = snapshot.data!;

          return Column(
            children: [
              // Date Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cashbook for ${DateFormatter.formatDate(_selectedDate)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedDate = DateTime.now()),
                      child: const Text('Today'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Summary Card
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _summaryRow(
                          'Opening Cash Balance:',
                          CurrencyFormatter.format(summary.openingCash),
                          isBold: true,
                        ),
                        const Divider(height: 16),
                        _summaryRow(
                          'Cash In (Sales):',
                          '+ ${CurrencyFormatter.format(summary.cashInSales)}',
                          color: AppColors.success,
                        ),
                        _summaryRow(
                          'Cash In (Customer Receipts):',
                          '+ ${CurrencyFormatter.format(summary.cashInCustomerPayments)}',
                          color: AppColors.success,
                        ),
                        _summaryRow(
                          'Total Cash In:',
                          '+ ${CurrencyFormatter.format(summary.totalCashIn)}',
                          isBold: true,
                          color: AppColors.success,
                        ),
                        const Divider(height: 16),
                        _summaryRow(
                          'Cash Out (Purchases):',
                          '- ${CurrencyFormatter.format(summary.cashOutPurchases)}',
                          color: AppColors.danger,
                        ),
                        _summaryRow(
                          'Cash Out (Supplier Payments):',
                          '- ${CurrencyFormatter.format(summary.cashOutSupplierPayments)}',
                          color: AppColors.danger,
                        ),
                        _summaryRow(
                          'Cash Out (Expenses):',
                          '- ${CurrencyFormatter.format(summary.cashOutExpenses)}',
                          color: AppColors.danger,
                        ),
                        _summaryRow(
                          'Total Cash Out:',
                          '- ${CurrencyFormatter.format(summary.totalCashOut)}',
                          isBold: true,
                          color: AppColors.danger,
                        ),
                        const Divider(height: 20, thickness: 1.5),
                        _summaryRow(
                          'Closing Cash Balance:',
                          CurrencyFormatter.format(summary.closingCash),
                          isBold: true,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Itemized Entries Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Today's Cash Transactions",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              // Itemized Entries List
              Expanded(
                child: FutureBuilder<List<CashbookItem>>(
                  future: repo.getDailyCashbookItems(dateStr),
                  builder: (context, itemSnap) {
                    if (itemSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = itemSnap.data ?? [];
                    if (items.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.money_off,
                        title: 'No Cash Transactions',
                        description:
                            'No cash movements were recorded for this date.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        final isIn = item.cashIn > 0;

                        return Card(
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isIn
                                  ? AppColors.successBg
                                  : AppColors.dangerBg,
                              child: Icon(
                                isIn
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isIn
                                    ? AppColors.success
                                    : AppColors.danger,
                                size: 16,
                              ),
                            ),
                            title: Text(
                              item.type,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              item.description,
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              '${isIn ? '+' : '-'}${CurrencyFormatter.format(isIn ? item.cashIn : item.cashOut)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isIn
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
