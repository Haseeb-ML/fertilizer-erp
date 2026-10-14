import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/payment.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';

class MakePaymentScreen extends ConsumerStatefulWidget {
  final int? preselectedSupplierId;

  const MakePaymentScreen({super.key, this.preselectedSupplierId});

  @override
  ConsumerState<MakePaymentScreen> createState() => _MakePaymentScreenState();
}

class _MakePaymentScreenState extends ConsumerState<MakePaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  Supplier? _selectedSupplier;
  DateTime _paymentDate = DateTime.now();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'Cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSupplier();
  }

  Future<void> _loadInitialSupplier() async {
    if (widget.preselectedSupplierId != null) {
      final supp = await ref
          .read(supplierRepoProvider)
          .getSupplierById(widget.preselectedSupplierId!);
      if (mounted) setState(() => _selectedSupplier = supp);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a supplier')));
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isLoading = true);

    final payment = Payment(
      paymentType: 'SUPPLIER_OUT',
      partyType: 'SUPPLIER',
      partyId: _selectedSupplier!.id!,
      partyName: _selectedSupplier!.name,
      amount: amount,
      paymentDate: DateFormatter.toSqlDate(_paymentDate),
      paymentMethod: _paymentMethod,
      referenceNumber: _refController.text.trim(),
      notes: _notesController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      final repo = ref.read(paymentRepoProvider);
      await repo.recordSupplierPayment(payment);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${CurrencyFormatter.format(amount)} to ${_selectedSupplier!.name} recorded!',
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
            content: Text('Error making payment: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make Supplier Payment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<List<Supplier>>(
                  future: ref.read(supplierRepoProvider).getSuppliers(),
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? [];
                    final Supplier? safeValue = (_selectedSupplier != null &&
                            suppliers.any((s) => s.id == _selectedSupplier!.id))
                        ? suppliers.firstWhere((s) => s.id == _selectedSupplier!.id)
                        : null;
                    return DropdownButtonFormField<Supplier>(
                      value: safeValue,
                      isExpanded: true,
                      hint: const Text('Select Supplier / Company *', overflow: TextOverflow.ellipsis),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.factory),
                      ),
                      items: suppliers
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                '${s.name} (${CurrencyFormatter.format(s.currentBalance)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (s) {
                        setState(() {
                          _selectedSupplier = s;
                          if (s != null &&
                              s.currentBalance > 0 &&
                              _amountController.text.isEmpty) {
                            _amountController.text = s.currentBalance
                                .toStringAsFixed(0);
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                if (_selectedSupplier != null)
                  Card(
                    color: AppColors.secondary.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Payable Balance:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            CurrencyFormatter.format(
                              _selectedSupplier!.currentBalance,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _selectedSupplier!.currentBalance > 0
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount (PKR) *',
                    hintText: 'e.g. 100000',
                    prefixIcon: Icon(Icons.payments),
                  ),
                  validator: (v) => Validators.positiveNumber(
                    v,
                    'Enter valid payment amount',
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode',
                        ),
                        items: AppConstants.paymentMethods
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m, overflow: TextOverflow.ellipsis),
                              ),
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
                            initialDate: _paymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null)
                            setState(() => _paymentDate = picked);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormatter.formatDate(_paymentDate)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _refController,
                  decoration: const InputDecoration(
                    labelText: 'Cheque # / Bank Transfer Ref (Optional)',
                    hintText: 'e.g. Cheque # 981240 or Online Ref',
                    prefixIcon: Icon(Icons.receipt),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    hintText: 'e.g. Advance for DAP quota booking',
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
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
                      : const Text('Save Supplier Payment Voucher'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
