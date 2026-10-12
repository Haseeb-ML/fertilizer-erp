import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/expense.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final Expense? expense;

  const ExpenseFormScreen({super.key, this.expense});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _selectedCategory;
  DateTime _expenseDate = DateTime.now();
  String _paymentMethod = 'Cash';
  bool _isLoading = false;

  bool get isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: e?.notes ?? '');
    _selectedCategory = e?.category ?? AppConstants.expenseCategories.first;
    _paymentMethod = e?.paymentMethod ?? 'Cash';
    if (e != null && e.expenseDate.isNotEmpty) {
      _expenseDate = DateFormatter.parseSqlDate(e.expenseDate);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isLoading = true);

    final repo = ref.read(expenseRepoProvider);
    final now = DateTime.now().toIso8601String();

    try {
      if (isEditing) {
        final updated = widget.expense!.copyWith(
          title: _titleController.text.trim(),
          category: _selectedCategory,
          amount: amount,
          expenseDate: DateFormatter.toSqlDate(_expenseDate),
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim(),
        );
        await repo.updateExpense(updated);
      } else {
        final newExp = Expense(
          title: _titleController.text.trim(),
          category: _selectedCategory,
          amount: amount,
          expenseDate: DateFormatter.toSqlDate(_expenseDate),
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim(),
          createdAt: now,
        );
        await repo.insertExpense(newExp);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Expense updated successfully'
                  : 'Expense recorded successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
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
        title: Text(isEditing ? 'Edit Expense' : 'Add Daily Expense'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Expense Category *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: AppConstants.expenseCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Expense Description / Payee *',
                    hintText: 'e.g. Loading 200 bags DAP from railway station',
                    prefixIcon: Icon(Icons.description),
                  ),
                  validator: (v) =>
                      Validators.requiredField(v, 'Enter expense description'),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (PKR) *',
                    hintText: 'e.g. 3500',
                    prefixIcon: Icon(Icons.payments),
                  ),
                  validator: (v) => Validators.positiveNumber(
                    v,
                    'Enter valid expense amount',
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Paid Via',
                        ),
                        items: ['Cash', 'Bank Transfer', 'Other']
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentMethod = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expenseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null)
                            setState(() => _expenseDate = picked);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormatter.formatDate(_expenseDate)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Voucher / Receipt Details (Optional)',
                    hintText: 'e.g. Hammali paid to Mazdoor union',
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(isEditing ? 'Save Changes' : 'Record Expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
