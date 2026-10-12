import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/sale_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/search_bar_widget.dart';
import '../../customers/screens/customer_form_screen.dart';

class SalesPosScreen extends ConsumerStatefulWidget {
  const SalesPosScreen({super.key});

  @override
  ConsumerState<SalesPosScreen> createState() => _SalesPosScreenState();
}

class _SalesPosScreenState extends ConsumerState<SalesPosScreen> {
  final _searchProductController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _paidAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  Customer? _selectedCustomer; // null = Walk-in Customer
  String _invoiceNumber = '';
  DateTime _saleDate = DateTime.now();
  String _paymentMethod = 'Cash'; // Cash, Credit, Bank Transfer

  final List<SaleItem> _cart = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initInvoiceNumber();
  }

  Future<void> _initInvoiceNumber() async {
    final repo = ref.read(saleRepoProvider);
    final inv = await repo.generateNextInvoiceNumber();
    if (mounted) setState(() => _invoiceNumber = inv);
  }

  @override
  void dispose() {
    _searchProductController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get subtotal => _cart.fold(0.0, (acc, item) => acc + item.totalPrice);
  double get discount =>
      double.tryParse(_discountController.text.trim()) ?? 0.0;
  double get grandTotal => (subtotal - discount).clamp(0.0, double.infinity);
  double get paidAmount =>
      double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
  double get balanceDue =>
      (grandTotal - paidAmount).clamp(0.0, double.infinity);

  void _showProductPicker() async {
    final products = await ref
        .read(productRepoProvider)
        .getProducts(onlyActive: true);
    if (!mounted) return;

    final searchCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final query = searchCtrl.text.toLowerCase().trim();
          final filtered = products.where((p) {
            return p.name.toLowerCase().contains(query) ||
                p.sku.toLowerCase().contains(query) ||
                p.category.toLowerCase().contains(query);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Product for Sale',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SearchBarWidget(
                  controller: searchCtrl,
                  hintText: 'Search fertilizer products...',
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      final isOutOfStock = p.currentStock <= 0;

                      return ListTile(
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Available: ${p.currentStock.toStringAsFixed(0)} ${p.unit} • ${p.category}',
                          style: TextStyle(
                            color: isOutOfStock
                                ? AppColors.danger
                                : AppColors.textSecondary,
                            fontWeight: isOutOfStock
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(p.sellingPrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                        onTap: () {
                          if (isOutOfStock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${p.name} is out of stock! Cannot add to sale.',
                                ),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                            return;
                          }
                          Navigator.of(ctx).pop();
                          _addToCart(p);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addToCart(Product product) {
    // Check if already in cart
    final existingIndex = _cart.indexWhere(
      (item) => item.productId == product.id,
    );
    if (existingIndex != -1) {
      final existing = _cart[existingIndex];
      final newQty = existing.quantity + 1;
      if (newQty > product.currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot add more. Only ${product.currentStock.toStringAsFixed(0)} available in stock.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      setState(() {
        _cart[existingIndex] = existing.copyWith(
          quantity: newQty,
          totalPrice: newQty * existing.unitPrice,
        );
        _autoUpdatePaidAmount();
      });
    } else {
      setState(() {
        _cart.add(
          SaleItem(
            productId: product.id!,
            productName: product.name,
            unit: product.unit,
            quantity: 1,
            unitPrice: product.sellingPrice,
            totalPrice: product.sellingPrice,
          ),
        );
        _autoUpdatePaidAmount();
      });
    }
  }

  void _autoUpdatePaidAmount() {
    if (_paymentMethod == 'Cash') {
      _paidAmountController.text = grandTotal.toStringAsFixed(0);
    }
  }

  void _editCartItem(int index) async {
    final item = _cart[index];
    final prod = await ref
        .read(productRepoProvider)
        .getProductById(item.productId);
    final maxAvailable = prod?.currentStock ?? item.quantity;

    final qtyCtrl = TextEditingController(
      text: item.quantity.toStringAsFixed(0),
    );
    final rateCtrl = TextEditingController(
      text: item.unitPrice.toStringAsFixed(0),
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Max available in stock: ${maxAvailable.toStringAsFixed(0)} ${item.unit}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'Quantity (${item.unit})'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Rate per Unit (PKR)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
              final newRate = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
              if (newQty <= 0 || newRate <= 0) return;

              if (newQty > maxAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot sell $newQty. Only $maxAvailable available in stock.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              setState(() {
                _cart[index] = item.copyWith(
                  quantity: newQty,
                  unitPrice: newRate,
                  totalPrice: newQty * newRate,
                );
                _autoUpdatePaidAmount();
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Update Item'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSale() async {
    if (_isSaving) return; // Prevent double save
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty. Add products to checkout.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final customerName = _selectedCustomer?.name ?? 'Walk-in Customer';
    final status = balanceDue <= 0
        ? 'PAID'
        : (paidAmount > 0 ? 'PARTIAL' : 'UNPAID');

    final sale = Sale(
      invoiceNumber: _invoiceNumber,
      customerId: _selectedCustomer?.id,
      customerName: customerName,
      saleDate: DateFormatter.toSqlDate(_saleDate),
      subtotal: subtotal,
      discount: discount,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      balanceDue: balanceDue,
      paymentStatus: status,
      paymentMethod: _paymentMethod,
      notes: _notesController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
      items: _cart,
    );

    try {
      final repo = ref.read(saleRepoProvider);
      await repo.createSale(sale);

      if (mounted) {
        // Show success and offer instant PDF print
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 28),
                SizedBox(width: 8),
                Text('Sale Completed!'),
              ],
            ),
            content: Text(
              'Invoice $_invoiceNumber for $customerName has been saved successfully.\nGrand Total: ${CurrencyFormatter.format(grandTotal)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final settings = await ref
                      .read(settingsRepoProvider)
                      .getSettings();
                  await PdfService.printSaleInvoice(
                    sale: sale,
                    settings: settings,
                  );
                },
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print / Share Invoice'),
              ),
            ],
          ),
        );

        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot complete sale: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Point of Sale (New Sale)')),
      body: SafeArea(
        child: Column(
          children: [
            // Top Customer & Date Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Invoice: $_invoiceNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _saleDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null)
                            setState(() => _saleDate = picked);
                        },
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormatter.formatDate(_saleDate),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Customer Selector
                  FutureBuilder<List<Customer>>(
                    future: ref.read(customerRepoProvider).getCustomers(),
                    builder: (context, snapshot) {
                      final customers = snapshot.data ?? [];
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Customer?>(
                              value: _selectedCustomer,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.person),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              hint: const Text('Walk-in Customer (Cash)'),
                              items: [
                                const DropdownMenuItem<Customer?>(
                                  value: null,
                                  child: Text('Walk-in Customer (Cash)'),
                                ),
                                ...customers.map(
                                  (c) => DropdownMenuItem<Customer?>(
                                    value: c,
                                    child: Text(
                                      '${c.name} (${CurrencyFormatter.format(c.currentBalance)})',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (c) {
                                setState(() {
                                  _selectedCustomer = c;
                                  if (c != null && _paymentMethod == 'Cash') {
                                    // Can switch to Credit
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () async {
                              final added = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CustomerFormScreen(),
                                    ),
                                  );
                              if (added == true) setState(() {});
                            },
                            icon: const Icon(Icons.person_add),
                            tooltip: 'Add Customer',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Cart Items
            Expanded(
              child: _cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: AppColors.textMuted.withOpacity(0.6),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Cart is empty',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showProductPicker,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Products to Cart'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            title: Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${item.quantity.toStringAsFixed(0)} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  CurrencyFormatter.format(item.totalPrice),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => _editCartItem(index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.danger,
                                  ),
                                  onPressed: () => setState(() {
                                    _cart.removeAt(index);
                                    _autoUpdatePaidAmount();
                                  }),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Bottom POS Checkout Panel
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cart.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _showProductPicker,
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('Add More Products'),
                      ),
                    ),

                  // Discount, Payment Method & Paid Amount
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _discountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Discount',
                            prefixIcon: Icon(Icons.discount_outlined),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (_) =>
                              setState(() => _autoUpdatePaidAmount()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Mode',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          items: ['Cash', 'Credit', 'Bank Transfer', 'JazzCash']
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _paymentMethod = val;
                                if (val == 'Credit') {
                                  _paidAmountController.text = '0';
                                } else if (val == 'Cash') {
                                  _paidAmountController.text = grandTotal
                                      .toStringAsFixed(0);
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _paidAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount Paid',
                            prefixIcon: Icon(Icons.payment),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Total & Balance Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grand Total: ${CurrencyFormatter.format(grandTotal)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          if (balanceDue > 0)
                            Text(
                              'Balance Due: ${CurrencyFormatter.format(balanceDue)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSaving || _cart.isEmpty
                            ? null
                            : _completeSale,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save & Print Sale',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
