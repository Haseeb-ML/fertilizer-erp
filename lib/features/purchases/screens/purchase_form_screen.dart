import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../suppliers/screens/supplier_form_screen.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  Supplier? _selectedSupplier;
  String _invoiceNumber = '';
  DateTime _purchaseDate = DateTime.now();

  final _discountController = TextEditingController(text: '0');
  final _freightController = TextEditingController(text: '0');
  final _paidAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  String _paymentMethod = 'Cash';
  final List<PurchaseItem> _items = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initInvoiceNumber();
  }

  Future<void> _initInvoiceNumber() async {
    final repo = ref.read(purchaseRepoProvider);
    final inv = await repo.generateNextPurchaseNumber();
    if (mounted) setState(() => _invoiceNumber = inv);
  }

  @override
  void dispose() {
    _discountController.dispose();
    _freightController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get subtotal => _items.fold(0.0, (acc, item) => acc + item.totalPrice);
  double get discount =>
      double.tryParse(_discountController.text.trim()) ?? 0.0;
  double get freight => double.tryParse(_freightController.text.trim()) ?? 0.0;
  double get grandTotal =>
      (subtotal - discount + freight).clamp(0.0, double.infinity);
  double get paidAmount =>
      double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
  double get balanceDue =>
      (grandTotal - paidAmount).clamp(0.0, double.infinity);

  void _showAddItemDialog() async {
    final products = await ref
        .read(productRepoProvider)
        .getProducts(onlyActive: true);
    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active products found. Please add products first.'),
        ),
      );
      return;
    }

    Product selectedProduct = products.first;
    final qtyController = TextEditingController(text: '50');
    final rateController = TextEditingController(
      text: selectedProduct.purchasePrice.toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Text('Add Purchase Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Product>(
                    value: selectedProduct,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Product'),
                    items: products
                        .map(
                          (p) =>
                              DropdownMenuItem(
                                value: p,
                                child: Text(p.name, overflow: TextOverflow.ellipsis),
                              ),
                        )
                        .toList(),
                    onChanged: (p) {
                      if (p != null) {
                        setDialogState(() {
                          selectedProduct = p;
                          rateController.text = p.purchasePrice.toStringAsFixed(
                            0,
                          );
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Quantity (${selectedProduct.unit})',
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Rate per Unit (PKR)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final qty = double.tryParse(qtyController.text.trim()) ?? 0.0;
                  final rate =
                      double.tryParse(rateController.text.trim()) ?? 0.0;
                  if (qty <= 0 || rate <= 0) return;

                  setState(() {
                    _items.add(
                      PurchaseItem(
                        productId: selectedProduct.id!,
                        productName: selectedProduct.name,
                        unit: selectedProduct.unit,
                        quantity: qty,
                        unitPrice: rate,
                        totalPrice: qty * rate,
                      ),
                    );
                  });
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add to Invoice'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _savePurchase() async {
    if (_isSaving) return; // Prevent duplicate submits
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a supplier')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product item')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final status = balanceDue <= 0
        ? 'PAID'
        : (paidAmount > 0 ? 'PARTIAL' : 'UNPAID');
    final purchase = Purchase(
      invoiceNumber: _invoiceNumber,
      supplierId: _selectedSupplier!.id!,
      supplierName: _selectedSupplier!.name,
      purchaseDate: DateFormatter.toSqlDate(_purchaseDate),
      subtotal: subtotal,
      discount: discount,
      freightCharges: freight,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      balanceDue: balanceDue,
      paymentStatus: status,
      paymentMethod: paidAmount > 0 ? _paymentMethod : null,
      notes: _notesController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
      items: _items,
    );

    try {
      final repo = ref.read(purchaseRepoProvider);
      await repo.createPurchase(purchase);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase Invoice $_invoiceNumber saved successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving purchase: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Invoice')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Meta: Invoice # & Date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Invoice: $_invoiceNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _purchaseDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null)
                          setState(() => _purchaseDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormatter.formatDate(_purchaseDate)),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Select Supplier
                FutureBuilder<List<Supplier>>(
                  future: ref.read(supplierRepoProvider).getSuppliers(),
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? [];
                    final Supplier? safeValue = (_selectedSupplier != null &&
                            suppliers.any((s) => s.id == _selectedSupplier!.id))
                        ? suppliers.firstWhere((s) => s.id == _selectedSupplier!.id)
                        : null;
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Supplier>(
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
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (s) =>
                                setState(() => _selectedSupplier = s),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () async {
                            final added = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => const SupplierFormScreen(),
                                  ),
                                );
                            if (added == true) setState(() {});
                          },
                          icon: const Icon(Icons.add),
                          tooltip: 'Add Supplier',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Items Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Purchase Items',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddItemDialog,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'No items added yet. Tap "Add Product" above.',
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${item.quantity.toStringAsFixed(0)} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CurrencyFormatter.format(item.totalPrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _items.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),

                // Financial Inputs (Discount, Freight, Paid Amount)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _discountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Discount (PKR)',
                                  prefixIcon: Icon(Icons.discount_outlined),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _freightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Freight / Kiraya (PKR)',
                                  prefixIcon: Icon(
                                    Icons.local_shipping_outlined,
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _paidAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Paid Amount (PKR)',
                                  prefixIcon: Icon(Icons.payment),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                  if (val != null)
                                    setState(() => _paymentMethod = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Totals Summary
                        _summaryRow(
                          'Subtotal:',
                          CurrencyFormatter.format(subtotal),
                        ),
                        if (discount > 0)
                          _summaryRow(
                            'Discount:',
                            '- ${CurrencyFormatter.format(discount)}',
                            color: AppColors.success,
                          ),
                        if (freight > 0)
                          _summaryRow(
                            'Freight Charges:',
                            '+ ${CurrencyFormatter.format(freight)}',
                          ),
                        const Divider(height: 16),
                        _summaryRow(
                          'Grand Total:',
                          CurrencyFormatter.format(grandTotal),
                          isBold: true,
                          fontSize: 16,
                        ),
                        _summaryRow(
                          'Paid Amount:',
                          CurrencyFormatter.format(paidAmount),
                          color: AppColors.success,
                        ),
                        _summaryRow(
                          'Balance Due to Supplier:',
                          CurrencyFormatter.format(balanceDue),
                          isBold: true,
                          color: balanceDue > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Bilty / Vehicle Number (Optional)',
                    hintText: 'e.g. Truck # FSD-1234, Driver: Asif',
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isSaving ? null : _savePurchase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: AppColors.secondary,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Purchase Invoice'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
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
