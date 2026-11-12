import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/validators.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final Customer? customer;

  const CustomerFormScreen({super.key, this.customer});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _openingBalController;
  late TextEditingController _creditLimitController;
  late TextEditingController _notesController;

  bool _isActive = true;
  bool _isLoading = false;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _addressController = TextEditingController(text: c?.villageOrAddress ?? '');
    _openingBalController = TextEditingController(
      text: c != null ? c.openingBalance.toStringAsFixed(0) : '0',
    );
    _creditLimitController = TextEditingController(
      text: c != null ? c.creditLimit.toStringAsFixed(0) : '0',
    );
    _notesController = TextEditingController(text: c?.notes ?? '');
    _isActive = c?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openingBalController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final repo = ref.read(customerRepoProvider);
    final now = DateTime.now().toIso8601String();
    final openingBal =
        double.tryParse(_openingBalController.text.trim()) ?? 0.0;
    final creditLimit =
        double.tryParse(_creditLimitController.text.trim()) ?? 0.0;

    try {
      if (isEditing) {
        final updated = widget.customer!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          villageOrAddress: _addressController.text.trim(),
          creditLimit: creditLimit,
          notes: _notesController.text.trim(),
          isActive: _isActive,
          updatedAt: now,
        );
        await repo.updateCustomer(updated);
      } else {
        final newCust = Customer(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          villageOrAddress: _addressController.text.trim(),
          openingBalance: openingBal,
          currentBalance: openingBal,
          creditLimit: creditLimit,
          notes: _notesController.text.trim(),
          isActive: _isActive,
          createdAt: now,
          updatedAt: now,
        );
        await repo.insertCustomer(newCust);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Customer updated successfully'
                  : 'Customer created successfully',
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
            content: Text('Error saving customer: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomer({bool force = false}) async {
    final c = widget.customer;
    if (c == null || c.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Customer?'),
          ],
        ),
        content: Text(
          force
              ? 'Warning: This will permanently delete customer "${c.name}" along with all their sales invoices, payments, and ledger history.\n\nAre you sure you want to proceed?'
              : 'Are you sure you want to delete customer "${c.name}"?\n(کیا آپ واقعی اس گاہک کو ڈیلیٹ کرنا چاہتے ہیں؟)',
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
            child: Text(force ? 'Force Delete All' : 'Delete (ڈیلیٹ کریں)'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    final repo = ref.read(customerRepoProvider);
    try {
      await repo.deleteCustomer(c.id!, force: force);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer "${c.name}" deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final errorStr = e.toString();
      if (!force && errorStr.contains('sales invoice')) {
        // Prompt for force delete
        await _deleteCustomer(force: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot delete customer: $e'),
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
        title: Text(isEditing ? 'Edit Customer' : 'Add New Customer'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Customer (کسٹمر ڈیلیٹ کریں)',
              onPressed: _isLoading ? null : () => _deleteCustomer(),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer / Farmer Name *',
                    hintText: 'e.g. Ch. Akhtar Ali / Malik Tariq',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      Validators.requiredField(v, 'Enter customer name'),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Mobile)',
                    hintText: '0300-1234567',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Village / Tehsil / Address',
                    hintText: 'e.g. Chak 42-NB / Tehsil Khanewal',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),

                if (!isEditing) ...[
                  TextFormField(
                    controller: _openingBalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Opening Balance (PKR)',
                      hintText: 'Positive = Farmer owes you (Receivable)',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _creditLimitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Credit Limit (PKR, Optional)',
                    hintText: '0 = No limit',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    hintText: 'Guarantor or land details...',
                  ),
                ),
                const SizedBox(height: 12),

                SwitchListTile(
                  title: const Text(
                    'Customer Active',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: _isActive,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _saveCustomer,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                      : Text(isEditing ? 'Save Changes' : 'Create Customer'),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _deleteCustomer(),
                    icon: const Icon(Icons.delete_forever, color: AppColors.danger),
                    label: const Text(
                      'Delete Customer (کسٹمر ڈیلیٹ کریں)',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
