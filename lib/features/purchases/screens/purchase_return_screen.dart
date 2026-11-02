import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/product.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/purchase_item.dart';
import '../../../core/models/supplier.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class PurchaseReturnScreen extends ConsumerStatefulWidget {
  final Purchase? purchase;
  final Supplier? preselectedSupplier;

  const PurchaseReturnScreen({
    super.key,
    this.purchase,
    this.preselectedSupplier,
  });

  @override
  ConsumerState<PurchaseReturnScreen> createState() =>
      _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends ConsumerState<PurchaseReturnScreen> {
  final _formKey = GlobalKey<FormState>();

  // Linked Purchase Mode
  PurchaseItem? _selectedItem;

  // Direct Mode
  Supplier? _selectedSupplier;
  Product? _selectedProduct;
  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  List<Purchase> _supplierPreviousPurchases = [];
  bool _isLoadingPurchases = false;
  bool _isLoadingData = false;

  final _qtyController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _reasonController = TextEditingController();
  String _refundType = 'LEDGER_ADJUST'; // LEDGER_ADJUST or CASH_REFUND
  DateTime _returnDate = DateTime.now();
  bool _isLoading = false;

  bool get _isDirectMode => widget.purchase == null;

  @override
  void initState() {
    super.initState();
    if (_isDirectMode) {
      _selectedSupplier = widget.preselectedSupplier;
      _loadDirectReturnData();
    } else {
      _selectedItem = widget.purchase!.items.isNotEmpty
          ? widget.purchase!.items.first
          : null;
      if (_selectedItem != null) {
        _unitPriceController.text = _selectedItem!.unitPrice.toStringAsFixed(0);
      }
    }
  }

  Future<void> _loadDirectReturnData() async {
    setState(() => _isLoadingData = true);
    try {
      final suppRepo = ref.read(supplierRepoProvider);
      final prodRepo = ref.read(productRepoProvider);
      final suppliers = await suppRepo.getSuppliers();
      final products = await prodRepo.getProducts(onlyActive: true);
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _products = products;
          if (_selectedSupplier != null) {
            final match =
                _suppliers.where((s) => s.id == _selectedSupplier!.id);
            if (match.isNotEmpty) _selectedSupplier = match.first;
          } else if (_suppliers.isNotEmpty) {
            _selectedSupplier = _suppliers.first;
          }
          _isLoadingData = false;
        });
        if (_selectedSupplier != null) {
          _fetchSupplierPreviousPurchases(_selectedSupplier!.id!);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchSupplierPreviousPurchases(int supplierId) async {
    setState(() => _isLoadingPurchases = true);
    try {
      final purchaseRepo = ref.read(purchaseRepoProvider);
      final list = await purchaseRepo.getPurchases(supplierId: supplierId);
      if (mounted) {
        setState(() {
          _supplierPreviousPurchases = list;
          _isLoadingPurchases = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPurchases = false);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _unitPriceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final price = double.tryParse(_unitPriceController.text.trim()) ?? 0.0;
    return qty * price;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _returnDate = picked);
    }
  }

  void _selectPreviousPurchasedItem(PurchaseItem item, String invoiceNo) {
    Product? prod;
    final match = _products.where((p) => p.id == item.productId);
    if (match.isNotEmpty) {
      prod = match.first;
    } else {
      prod = Product(
        id: item.productId,
        name: item.productName,
        sku: 'PROD-${item.productId}',
        category: 'Fertilizer',
        brand: '',
        bagSize: item.unit,
        unit: item.unit,
        purchasePrice: item.unitPrice,
        sellingPrice: item.unitPrice,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }

    setState(() {
      _selectedProduct = prod;
      _unitPriceController.text = item.unitPrice.toStringAsFixed(0);
      _qtyController.text = '1';
      _reasonController.text = 'Return from Inv #$invoiceNo';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selected "${item.productName}" (Purchased @ Rs. ${item.unitPrice.toStringAsFixed(0)} on Inv #$invoiceNo)',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF00796B),
      ),
    );
  }

  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (qty <= 0) return;

    final unitPrice = double.tryParse(_unitPriceController.text.trim()) ?? 0.0;
    if (unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid return unit price'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_isDirectMode && _selectedItem != null) {
      if (qty > _selectedItem!.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot return $qty. Only ${_selectedItem!.quantity} was purchased on this invoice.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    if (_isDirectMode) {
      if (_selectedSupplier == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a supplier / company'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a product to return'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (qty > _selectedProduct!.currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough stock to return (${_selectedProduct!.currentStock.toStringAsFixed(0)} available, $qty requested)',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(purchaseRepoProvider);
      final returnDateStr = _returnDate.toIso8601String().substring(0, 10);

      if (_isDirectMode) {
        await repo.processDirectPurchaseReturn(
          supplierId: _selectedSupplier!.id!,
          supplierName: _selectedSupplier!.name,
          productId: _selectedProduct!.id!,
          quantity: qty,
          unitPrice: unitPrice,
          refundType: _refundType,
          reason: _reasonController.text.trim(),
          returnDate: returnDateStr,
        );
      } else {
        await repo.returnPurchaseItem(
          purchaseId: widget.purchase!.id!,
          productId: _selectedItem!.productId,
          quantity: qty,
          unitPrice: unitPrice,
          refundType: _refundType,
          reason: _reasonController.text.trim(),
        );
      }

      ref.read(purchasesUpdateTriggerProvider.notifier).state++;
      ref.read(productsUpdateTriggerProvider.notifier).state++;
      ref.read(returnsUpdateTriggerProvider.notifier).state++;
      ref.invalidate(dashboardDataProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Purchase return processed and stock adjusted successfully',
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
    final title = _isDirectMode
        ? (ref.tr('action_purchase_return') != 'action_purchase_return'
            ? ref.tr('action_purchase_return')
            : 'Supplier Purchase Return (سپلائر واپسی)')
        : 'Process Purchase Return (بل واپسی)';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      if (!_isDirectMode)
                        Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Invoice: ${widget.purchase!.invoiceNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      widget.purchase!.purchaseDate,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supplier: ${widget.purchase!.supplierName}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Card(
                          color: const Color(0xFFE0F2F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF80CBC4)),
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Color(0xFF004D40)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Supplier select karein: Unse pehle khareedi gayi khaadein neechay show hongi jin par click kar ke foran wapis bhej saktay hain.',
                                    style: TextStyle(
                                      color: Color(0xFF004D40),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Direct Mode: Supplier Dropdown
                      if (_isDirectMode) ...[
                        DropdownButtonFormField<Supplier>(
                          value: _selectedSupplier,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                'Select Supplier / Company (کمپنی / سپلائر کا نام) *',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: _suppliers
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    '${s.name} (Baqaya: ${CurrencyFormatter.format(s.currentBalance)})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (supp) {
                            if (supp != null) {
                              setState(() {
                                _selectedSupplier = supp;
                              });
                              _fetchSupplierPreviousPurchases(supp.id!);
                            }
                          },
                          validator: (v) =>
                              v == null ? 'Please select a supplier' : null,
                        ),
                        const SizedBox(height: 12),

                        // Display Previously Purchased Items from this Supplier
                        if (_selectedSupplier != null) ...[
                          if (_isLoadingPurchases)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else if (_supplierPreviousPurchases.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF80CBC4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.history,
                                          size: 16, color: Color(0xFF004D40)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Previously Bought from ${_selectedSupplier!.name} (پہلے خریدا گیا مال):',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF004D40),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      for (final p in _supplierPreviousPurchases.take(5))
                                        for (final item in p.items)
                                          ActionChip(
                                            avatar: const Icon(
                                                Icons.keyboard_return_rounded,
                                                size: 14,
                                                color: Color(0xFF00796B)),
                                            backgroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Color(0xFF80CBC4)),
                                            label: Text(
                                              '${item.productName} (${item.quantity.toStringAsFixed(0)} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)})',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF00796B),
                                              ),
                                            ),
                                            onPressed: () =>
                                                _selectPreviousPurchasedItem(
                                                    item, p.invoiceNumber),
                                          ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],

                        // Product Dropdown
                        DropdownButtonFormField<Product>(
                          value: _selectedProduct,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                'Select Product to Return (کھاد / پراڈکٹ) *',
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: _products
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    '${p.name} (Stock: ${p.currentStock.toStringAsFixed(0)} ${p.unit})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (prod) {
                            if (prod != null) {
                              setState(() {
                                _selectedProduct = prod;
                                _unitPriceController.text =
                                    prod.purchasePrice.toStringAsFixed(0);
                              });
                            }
                          },
                          validator: (v) =>
                              v == null ? 'Please select a product' : null,
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        // Linked Mode: Items dropdown
                        DropdownButtonFormField<PurchaseItem>(
                          value: _selectedItem,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Product to Return *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: widget.purchase!.items
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
                            if (item != null) {
                              setState(() {
                                _selectedItem = item;
                                _unitPriceController.text =
                                    item.unitPrice.toStringAsFixed(0);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Return Date Picker
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today,
                            color: AppColors.primary),
                        title: const Text('Return Date (تاریخ واپسی)'),
                        subtitle: Text(
                          DateFormatter.formatDate(_returnDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _selectDate,
                          child: const Text('Change Date'),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quantity and Unit Price Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _qtyController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Return Qty (تعداد / بوریاں) *',
                                hintText: _isDirectMode
                                    ? '1'
                                    : 'Max ${_selectedItem?.quantity.toStringAsFixed(0) ?? ""}',
                                prefixIcon: const Icon(Icons.numbers),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) => Validators.positiveNumber(
                                v,
                                'Enter valid quantity',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _unitPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Return Rate (فی بوری لاگت) *',
                                prefixText: 'Rs. ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) => Validators.positiveNumber(
                                v,
                                'Enter valid rate',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Total Amount Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Return Value (کل رقم):',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(_totalAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Refund / Adjustment Mode
                      DropdownButtonFormField<String>(
                        value: _refundType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Adjustment Mode (کھاتہ یا کیش طریقہ) *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'LEDGER_ADJUST',
                            child: Text(
                              'Deduct from Supplier Payable (کھاتے سے کٹوتی)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'CASH_REFUND',
                            child: Text(
                              'Cash Received from Supplier (کمپنی سے نقد وصولی)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _refundType = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Reason
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Reason for Return (وجہ واپسی)',
                          hintText:
                              'e.g. Damaged bags, Expired stock, Wrong delivery',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitReturn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_return_outlined),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirm Purchase Return & Deduct Stock',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
