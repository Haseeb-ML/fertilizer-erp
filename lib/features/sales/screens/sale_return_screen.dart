import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/sale_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class SaleReturnScreen extends ConsumerStatefulWidget {
  final Sale sale;

  const SaleReturnScreen({super.key, required this.sale});

  @override
  ConsumerState<SaleReturnScreen> createState() => _SaleReturnScreenState();
}

class _SaleReturnScreenState extends ConsumerState<SaleReturnScreen> {
  final _formKey = GlobalKey<FormState>();
  late SaleItem _selectedItem;
  final _qtyController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();
  String _refundType = 'LEDGER_ADJUST';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.sale.items.first;
    if (widget.sale.customerId == null || widget.sale.customerId == 0) {
      _refundType = 'CASH_REFUND';
    }
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
            'Cannot return $qty. Only ${_selectedItem.quantity} was sold on this invoice.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(saleRepoProvider);
      await repo.returnSaleItem(
        saleId: widget.sale.id!,
        productId: _selectedItem.productId,
        quantity: qty,
        unitPrice: _selectedItem.unitPrice,
        unitCost: _selectedItem.unitCost,
        refundType: _refundType,
        reason: _reasonController.text.trim(),
      );

      ref.read(salesUpdateTriggerProvider.notifier).state++;
      ref.read(productsUpdateTriggerProvider.notifier).state++;
      ref.invalidate(dashboardDataProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sale return processed and stock restored successfully',
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
      appBar: AppBar(title: const Text('Process Sales Return')),
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
                          'Invoice: ${widget.sale.invoiceNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Customer: ${widget.sale.customerName} • Date: ${widget.sale.saleDate}',
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

                DropdownButtonFormField<SaleItem>(
                  value: _selectedItem,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Product to Return',
                  ),
                  items: widget.sale.items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item.productName} (${item.quantity.toStringAsFixed(0)} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)})',
                            overflow: TextOverflow.ellipsis,
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
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Refund / Adjustment Mode',
                  ),
                  items: [
                    if (widget.sale.customerId != null &&
                        widget.sale.customerId! > 0)
                      const DropdownMenuItem(
                        value: 'LEDGER_ADJUST',
                        child: Text(
                          'Adjust Customer Balance (Reduce Receivable)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const DropdownMenuItem(
                      value: 'CASH_REFUND',
                      child: Text(
                        'Cash Refund Paid to Customer',
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    hintText: 'e.g. Excess bags returned by farmer',
                  ),
                  validator: (v) => Validators.requiredField(
                    v,
                    'Please enter a return reason',
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
                      : const Text('Confirm Sales Return & Restock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
