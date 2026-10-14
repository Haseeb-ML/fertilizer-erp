import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';

class ReceivePaymentScreen extends ConsumerStatefulWidget {
  final int? preselectedCustomerId;

  const ReceivePaymentScreen({super.key, this.preselectedCustomerId});

  @override
  ConsumerState<ReceivePaymentScreen> createState() =>
      _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends ConsumerState<ReceivePaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  Customer? _selectedCustomer;
  DateTime _paymentDate = DateTime.now();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'Cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialCustomer();
  }

  Future<void> _loadInitialCustomer() async {
    if (widget.preselectedCustomerId != null) {
      final cust = await ref
          .read(customerRepoProvider)
          .getCustomerById(widget.preselectedCustomerId!);
      if (mounted) setState(() => _selectedCustomer = cust);
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
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isLoading = true);

    final payment = Payment(
      paymentType: 'CUSTOMER_IN',
      partyType: 'CUSTOMER',
      partyId: _selectedCustomer!.id!,
      partyName: _selectedCustomer!.name,
      amount: amount,
      paymentDate: DateFormatter.toSqlDate(_paymentDate),
      paymentMethod: _paymentMethod,
      referenceNumber: _refController.text.trim(),
      notes: _notesController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      final repo = ref.read(paymentRepoProvider);
      await repo.recordCustomerPayment(payment);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${CurrencyFormatter.format(amount)} received from ${_selectedCustomer!.name}',
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
            content: Text('Error recording payment: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Customer Payment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<List<Customer>>(
                  future: ref.read(customerRepoProvider).getCustomers(),
                  builder: (context, snapshot) {
                    final customers = snapshot.data ?? [];
                    final Customer? safeValue = (_selectedCustomer != null &&
                            customers.any((c) => c.id == _selectedCustomer!.id))
                        ? customers.firstWhere((c) => c.id == _selectedCustomer!.id)
                        : null;
                    return DropdownButtonFormField<Customer>(
                      value: safeValue,
                      isExpanded: true,
                      hint: const Text('Select Customer / Farmer *', overflow: TextOverflow.ellipsis),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: customers
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.name} (${CurrencyFormatter.format(c.currentBalance)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (c) {
                        setState(() {
                          _selectedCustomer = c;
                          if (c != null &&
                              c.currentBalance > 0 &&
                              _amountController.text.isEmpty) {
                            _amountController.text = c.currentBalance
                                .toStringAsFixed(0);
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                if (_selectedCustomer != null)
                  Card(
                    color: AppColors.primaryLight.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Balance Due:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            CurrencyFormatter.format(
                              _selectedCustomer!.currentBalance,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _selectedCustomer!.currentBalance > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Received Amount (PKR) *',
                    hintText: 'e.g. 50000',
                    prefixIcon: Icon(Icons.payments),
                  ),
                  validator: (v) => Validators.positiveNumber(
                    v,
                    'Enter valid received amount',
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Mode & Date
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
                    labelText: 'Reference / Cheque / Bank Tx ID (Optional)',
                    hintText: 'e.g. Chq # 482910 or HBL Ref',
                    prefixIcon: Icon(Icons.receipt),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    hintText: 'e.g. Cleared harvest dues for Wheat season',
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
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
                      : const Text('Save Customer Payment Receipt'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
