import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/expense.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import 'expense_form_screen.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String _selectedCategory = 'All';

  Future<List<Expense>> _loadExpenses() async {
    final repo = ref.read(expenseRepoProvider);
    return repo.getExpenses(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
    );
  }

  /// PDF of exactly what is currently filtered: 'All Categories' -> everything,
  /// e.g. Transport selected -> only Transport expenses.
  Future<void> _exportPdf() async {
    final expenses = await _loadExpenses();
    if (!mounted) return;
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Is category mein koi expense nahi hai')),
      );
      return;
    }
    final settings = await ref.read(settingsRepoProvider).getSettings();
    await PdfService.shareExpenseReport(
      expenses: expenses,
      settings: settings,
      categoryLabel:
          _selectedCategory == 'All' ? 'All Categories' : _selectedCategory,
    );
  }

  Future<void> _confirmDeleteExpense(Expense e) async {
    if (e.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Expense?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this expense "${e.title}" (Rs. ${e.amount.toStringAsFixed(0)})?\n(کیا آپ واقعی اس خرچے کو ڈیلیٹ کرنا چاہتے ہیں؟)',
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
            child: const Text('Delete (ڈیلیٹ کریں)'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(expenseRepoProvider).deleteExpense(e.id!);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot delete expense: $err'),
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
        title: const Text('Daily Business Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF Download (selected category)',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Expense',
            onPressed: () async {
              final added = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
              );
              if (added == true) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category horizontal scroll
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All Categories'),
                    selected: _selectedCategory == 'All',
                    selectedColor: AppColors.accentLight,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = 'All'),
                  ),
                  const SizedBox(width: 6),
                  ...AppConstants.expenseCategories.map((cat) {
                    final shortName = cat.split('/').first.trim();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(shortName),
                        selected: _selectedCategory == cat,
                        selectedColor: AppColors.accentLight,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: FutureBuilder<List<Expense>>(
              future: _loadExpenses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final expenses = snapshot.data ?? [];
                if (expenses.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.receipt_outlined,
                    title: 'No Expenses Recorded',
                    description:
                        'Track shop rent, electricity, transport, and labor expenses.',
                    buttonLabel: 'Record Expense',
                    onButtonPressed: () async {
                      final added = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const ExpenseFormScreen(),
                        ),
                      );
                      if (added == true) setState(() {});
                    },
                  );
                }

                final totalAmount = expenses.fold(
                  0.0,
                  (acc, e) => acc + e.amount,
                );

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: AppColors.dangerBg,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Expenses Filtered:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(totalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          setState(() {});
                        },
                        child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: expenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final e = expenses[index];

                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.dangerBg,
                                child: const Icon(
                                  Icons.arrow_upward,
                                  color: AppColors.danger,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(e.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    '${e.category} • ${e.expenseDate} (${e.paymentMethod})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (e.notes.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      e.notes,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 19,
                                      color: AppColors.textSecondary,
                                    ),
                                    tooltip: 'Edit Expense',
                                    onPressed: () async {
                                      final edited = await Navigator.of(context)
                                          .push<bool>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ExpenseFormScreen(expense: e),
                                            ),
                                          );
                                      if (edited == true) setState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 19,
                                      color: AppColors.danger,
                                    ),
                                    tooltip: 'Delete Expense',
                                    onPressed: () => _confirmDeleteExpense(e),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
          );
          if (added == true) setState(() {});
        },
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
