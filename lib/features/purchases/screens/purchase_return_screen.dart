import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';

class PurchaseReturnScreen extends ConsumerStatefulWidget {
  final Purchase purchase;

  const PurchaseReturnScreen({super.key, required this.purchase});

  @override
  ConsumerState<PurchaseReturnScreen> createState() =>
      _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends ConsumerState<PurchaseReturnScreen> {
  final _formKey = GlobalKey<FormState>();
  late PurchaseItem _selectedItem;
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  String _refundType = 'LEDGER_ADJUST'; // LEDGER_ADJUST or CASH_REFUND
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.purchase.items.first;
    _qtyController.text = '1';
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (qty <= 0) return;

    if (qty > _selectedItem.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot return $qty. Only ${_selectedItem.quantity} was purchased on this invoice.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(purchaseRepoProvider);
      await repo.returnPurchaseItem(
        purchaseId: widget.purchase.id!,
        productId: _selectedItem.productId,
        quantity: qty,
        unitPrice: _selectedItem.unitPrice,
        refundType: _refundType,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase return processed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing return: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Process Purchase Return')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice: ${widget.purchase.invoiceNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Supplier: ${widget.purchase.supplierName} • Date: ${widget.purchase.purchaseDate}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<PurchaseItem>(
                  value: _selectedItem,
                  decoration: const InputDecoration(
                    labelText: 'Select Product to Return',
                  ),
                  items: widget.purchase.items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item.productName} (${item.quantity.toStringAsFixed(0)} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (item) {
                    if (item != null) setState(() => _selectedItem = item);
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Return Quantity (${_selectedItem.unit}) *',
                    hintText:
                        'Max ${_selectedItem.quantity.toStringAsFixed(0)}',
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  validator: (v) => Validators.positiveNumber(
                    v,
                    'Enter valid return quantity',
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _refundType,
                  decoration: const InputDecoration(
                    labelText: 'Adjustment / Refund Treatment',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'LEDGER_ADJUST',
                      child: Text('Adjust Supplier Ledger (Reduce Payable)'),
                    ),
                    DropdownMenuItem(
                      value: 'CASH_REFUND',
                      child: Text('Cash Refund Received'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _refundType = val);
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Return *',
                    hintText: 'e.g. Damaged bags / Caked urea / Wrong delivery',
                  ),
                  validator: (v) => Validators.requiredField(
                    v,
                    'Please provide a reason for the return',
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
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
                      : const Text('Confirm Purchase Return'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
