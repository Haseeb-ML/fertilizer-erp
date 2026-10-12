import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/supplier.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/validators.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  final Supplier? supplier;

  const SupplierFormScreen({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _openingBalController;
  late TextEditingController _notesController;

  bool _isActive = true;
  bool _isLoading = false;

  bool get isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _addressController = TextEditingController(text: s?.companyOrAddress ?? '');
    _openingBalController = TextEditingController(
      text: s != null ? s.openingBalance.toStringAsFixed(0) : '0',
    );
    _notesController = TextEditingController(text: s?.notes ?? '');
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openingBalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final repo = ref.read(supplierRepoProvider);
    final now = DateTime.now().toIso8601String();
    final openingBal =
        double.tryParse(_openingBalController.text.trim()) ?? 0.0;

    try {
      if (isEditing) {
        final updated = widget.supplier!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          companyOrAddress: _addressController.text.trim(),
          notes: _notesController.text.trim(),
          isActive: _isActive,
          updatedAt: now,
        );
        await repo.updateSupplier(updated);
      } else {
        final newSupp = Supplier(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          companyOrAddress: _addressController.text.trim(),
          openingBalance: openingBal,
          currentBalance: openingBal,
          notes: _notesController.text.trim(),
          isActive: _isActive,
          createdAt: now,
          updatedAt: now,
        );
        await repo.insertSupplier(newSupp);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Supplier updated successfully'
                  : 'Supplier created successfully',
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
            content: Text('Error saving supplier: $e'),
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
        title: Text(isEditing ? 'Edit Supplier' : 'Add New Supplier'),
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
                    labelText: 'Company / Supplier Name *',
                    hintText: 'e.g. Engro Fertilizer Multan Depot / FFC Dealer',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) =>
                      Validators.requiredField(v, 'Enter supplier name'),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone / Representative Contact',
                    hintText: '0300-7654321',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address / Warehouse Location',
                    hintText: 'e.g. Industrial Estate / Railway Road',
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
                      hintText: 'Positive = You owe supplier (Payable)',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Payment Terms (Optional)',
                    hintText: 'e.g. 15 days credit term, bank details...',
                  ),
                ),
                const SizedBox(height: 12),

                SwitchListTile(
                  title: const Text(
                    'Supplier Active',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: _isActive,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _saveSupplier,
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
                      : Text(isEditing ? 'Save Changes' : 'Create Supplier'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
