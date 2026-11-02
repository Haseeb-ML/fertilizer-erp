import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/sale_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class _SaleReturnLineItem {
  final int productId;
  final String productName;
  final String unit;
  double quantity;
  double unitPrice;
  final double unitCost;
  final double? maxQty;

  _SaleReturnLineItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    this.maxQty,
  });

  double get total => quantity * unitPrice;
}

class SaleReturnScreen extends ConsumerStatefulWidget {
  final Sale? sale;
  final Customer? preselectedCustomer;

  const SaleReturnScreen({
    super.key,
    this.sale,
    this.preselectedCustomer,
  });

  @override
  ConsumerState<SaleReturnScreen> createState() => _SaleReturnScreenState();
}

class _SaleReturnScreenState extends ConsumerState<SaleReturnScreen> {
  final _formKey = GlobalKey<FormState>();

  // Linked Invoice Mode
  SaleItem? _selectedItem;

  // Direct Mode
  Customer? _selectedCustomer;
  Product? _selectedProduct;
  List<Customer> _customers = [];
  List<Product> _products = [];
  List<Sale> _customerPreviousSales = [];
  bool _isLoadingSales = false;
  bool _isLoadingData = false;

  // Multi-item return list
  final List<_SaleReturnLineItem> _returnItems = [];

  final _qtyController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _reasonController = TextEditingController();
  String _refundType = 'LEDGER_ADJUST';
  DateTime _returnDate = DateTime.now();
  bool _isLoading = false;

  bool get _isDirectMode => widget.sale == null;

  @override
  void initState() {
    super.initState();
    if (_isDirectMode) {
      _selectedCustomer = widget.preselectedCustomer;
      _loadDirectReturnData();
      _refundType = _selectedCustomer != null ? 'LEDGER_ADJUST' : 'CASH_REFUND';
    } else {
      _selectedItem =
          widget.sale!.items.isNotEmpty ? widget.sale!.items.first : null;
      if (_selectedItem != null) {
        _unitPriceController.text = _selectedItem!.unitPrice.toStringAsFixed(0);
      }
      if (widget.sale!.customerId == null || widget.sale!.customerId == 0) {
        _refundType = 'CASH_REFUND';
      }
    }
  }

  Future<void> _loadDirectReturnData() async {
    setState(() => _isLoadingData = true);
    try {
      final custRepo = ref.read(customerRepoProvider);
      final prodRepo = ref.read(productRepoProvider);
      final customers = await custRepo.getCustomers();
      final products = await prodRepo.getProducts(onlyActive: true);
      if (mounted) {
        setState(() {
          _customers = customers;
          _products = products;
          if (_selectedCustomer != null) {
            final match =
                _customers.where((c) => c.id == _selectedCustomer!.id);
            if (match.isNotEmpty) _selectedCustomer = match.first;
          }
          _isLoadingData = false;
        });
        if (_selectedCustomer != null) {
          _fetchCustomerPreviousSales(_selectedCustomer!.id!);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchCustomerPreviousSales(int customerId) async {
    setState(() => _isLoadingSales = true);
    try {
      final saleRepo = ref.read(saleRepoProvider);
      final sales = await saleRepo.getSales(customerId: customerId);
      if (mounted) {
        setState(() {
          _customerPreviousSales = sales;
          _isLoadingSales = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSales = false);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _unitPriceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double get _currentInputTotal {
    final hasSelection =
        _isDirectMode ? _selectedProduct != null : _selectedItem != null;
    if (!hasSelection) return 0.0;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final price = double.tryParse(_unitPriceController.text.trim()) ?? 0.0;
    if (qty <= 0 || price <= 0) return 0.0;
    return qty * price;
  }

  double get _totalAmount {
    final listTotal =
        _returnItems.fold<double>(0.0, (sum, item) => sum + item.total);
    return listTotal + _currentInputTotal;
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

  void _selectPreviousSoldItem(SaleItem item, String invoiceNo) {
    // Find product in product list
    Product? prod;
    final match = _products.where((p) => p.id == item.productId);
    if (match.isNotEmpty) {
      prod = match.first;
    } else {
      // Create fallback product reference
      prod = Product(
        id: item.productId,
        name: item.productName,
        sku: 'PROD-${item.productId}',
        category: 'Fertilizer',
        brand: '',
        bagSize: item.unit,
        unit: item.unit,
        purchasePrice: item.unitCost,
        sellingPrice: item.unitPrice,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }

    setState(() {
      _selectedProduct = prod;
      _unitPriceController.text = item.unitPrice.toStringAsFixed(0);
      _qtyController.text = '1';
      if (_reasonController.text.trim().isEmpty) {
        _reasonController.text = 'Return from Inv #$invoiceNo';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selected "${item.productName}" (@ Rs. ${item.unitPrice.toStringAsFixed(0)}). Tap "+ Add Product" to add more items!',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  bool _addCurrentItemToList({bool showFeedback = true}) {
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final unitPrice = double.tryParse(_unitPriceController.text.trim()) ?? 0.0;

    if (_isDirectMode) {
      if (_selectedProduct == null) {
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a product first (پہلے پراڈکٹ منتخب کریں)'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return false;
      }
    } else {
      if (_selectedItem == null) {
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a product from invoice'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return false;
      }
    }

    if (qty <= 0) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid return quantity (درست تعداد لکھیں)'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }

    if (unitPrice <= 0) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid return rate (درست ریٹ لکھیں)'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }

    final int prodId =
        _isDirectMode ? _selectedProduct!.id! : _selectedItem!.productId;
    final String prodName =
        _isDirectMode ? _selectedProduct!.name : _selectedItem!.productName;
    final String unit =
        _isDirectMode ? _selectedProduct!.unit : _selectedItem!.unit;
    final double unitCost = _isDirectMode
        ? _selectedProduct!.purchasePrice
        : _selectedItem!.unitCost;
    final double? maxQty = _isDirectMode ? null : _selectedItem!.quantity;

    final existingIndex =
        _returnItems.indexWhere((e) => e.productId == prodId);
    final currentListedQty =
        existingIndex >= 0 ? _returnItems[existingIndex].quantity : 0.0;

    if (maxQty != null && (currentListedQty + qty) > maxQty) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot return ${currentListedQty + qty}. Only $maxQty was sold on this invoice.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }

    setState(() {
      if (existingIndex >= 0) {
        _returnItems[existingIndex].quantity += qty;
        _returnItems[existingIndex].unitPrice = unitPrice;
      } else {
        _returnItems.add(
          _SaleReturnLineItem(
            productId: prodId,
            productName: prodName,
            unit: unit,
            quantity: qty,
            unitPrice: unitPrice,
            unitCost: unitCost,
            maxQty: maxQty,
          ),
        );
      }
      // Reset inputs so user can easily pick another product
      _selectedProduct = null;
      _selectedItem = null;
      _qtyController.text = '1';
      _unitPriceController.clear();
    });

    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added "$prodName" (${qty.toStringAsFixed(0)} $unit) to return list',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );
    }
    return true;
  }

  Future<void> _submitReturn() async {
    // If user currently has a product selected in the inputs, add it to the list first
    final hasPendingSelection =
        _isDirectMode ? _selectedProduct != null : _selectedItem != null;
    if (hasPendingSelection) {
      final ok = _addCurrentItemToList(showFeedback: _returnItems.isEmpty);
      if (!ok && _returnItems.isEmpty) return;
    }

    if (_returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least 1 product to return (کم از کم ایک پراڈکٹ منتخب کریں)',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(saleRepoProvider);
      final returnDateStr = _returnDate.toIso8601String().substring(0, 10);

      for (final item in _returnItems) {
        if (_isDirectMode) {
          await repo.processDirectSaleReturn(
            customerId: _selectedCustomer?.id,
            customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
            productId: item.productId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            unitCost: item.unitCost,
            refundType: _refundType,
            reason: _reasonController.text.trim(),
            returnDate: returnDateStr,
          );
        } else {
          await repo.returnSaleItem(
            saleId: widget.sale!.id!,
            productId: item.productId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            unitCost: item.unitCost,
            refundType: _refundType,
            reason: _reasonController.text.trim(),
          );
        }
      }

      ref.read(salesUpdateTriggerProvider.notifier).state++;
      ref.read(productsUpdateTriggerProvider.notifier).state++;
      ref.read(returnsUpdateTriggerProvider.notifier).state++;
      ref.invalidate(dashboardDataProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.tr('sale_return_success') != 'sale_return_success'
                  ? ref.tr('sale_return_success')
                  : 'Sale return (${_returnItems.length} item(s)) processed and stock restored successfully',
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
        ? (ref.tr('action_sale_return') != 'action_sale_return'
            ? ref.tr('action_sale_return')
            : 'Customer Sale Return (گاہک واپسی)')
        : 'Process Sales Return (بل واپسی)';

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
                                      'Invoice: ${widget.sale!.invoiceNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      widget.sale!.saleDate,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Customer: ${widget.sale!.customerName}',
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
                          color: const Color(0xFFF1F8E9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFAED581)),
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Color(0xFF33691E)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Kisaan ya customer select karein: Unko pehle bechi gayi khaadein neechay show hongi jin par click kar ke foran wapis le saktay hain.',
                                    style: TextStyle(
                                      color: Color(0xFF33691E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Direct Mode: Customer Selection
                      if (_isDirectMode) ...[
                        DropdownButtonFormField<Customer?>(
                          value: _selectedCustomer,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                'Select Customer / Farmer (کسان / گاہک کا نام)',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<Customer?>(
                              value: null,
                              child: Text(
                                'Walk-in / Cash Customer (عام گاہک)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ..._customers.map(
                              (c) => DropdownMenuItem<Customer?>(
                                value: c,
                                child: Text(
                                  '${c.name} (Khata: ${CurrencyFormatter.format(c.currentBalance)}) ${c.villageOrAddress.isNotEmpty ? "- ${c.villageOrAddress}" : ""}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (cust) {
                            setState(() {
                              _selectedCustomer = cust;
                              if (cust == null) {
                                _refundType = 'CASH_REFUND';
                                _customerPreviousSales = [];
                              } else {
                                _refundType = 'LEDGER_ADJUST';
                                _fetchCustomerPreviousSales(cust.id!);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Display Previously Sold Items to this Customer
                        if (_selectedCustomer != null) ...[
                          if (_isLoadingSales)
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
                          else if (_customerPreviousSales.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FBE7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDCE775)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.history,
                                          size: 16, color: Color(0xFF827717)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Previously Sold to ${_selectedCustomer!.name} (پہلے بیچی گئی کھادیں):',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF827717),
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
                                      for (final s in _customerPreviousSales.take(5))
                                        for (final item in s.items)
                                          ActionChip(
                                            avatar: const Icon(
                                                Icons.assignment_return_outlined,
                                                size: 14,
                                                color: Color(0xFF2E7D32)),
                                            backgroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Color(0xFFC5E1A5)),
                                            label: Text(
                                              '${item.productName} (${item.quantity.toStringAsFixed(0)} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)})',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2E7D32),
                                              ),
                                            ),
                                            onPressed: () =>
                                                _selectPreviousSoldItem(
                                                    item, s.invoiceNumber),
                                          ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],

                        // Product Selection
                        DropdownButtonFormField<Product>(
                          value: _selectedProduct,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                'Select Fertilizer / Product (کھاد / پراڈکٹ) *',
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
                                    prod.sellingPrice.toStringAsFixed(0);
                              });
                            }
                          },
                          validator: (v) =>
                              (v == null && _returnItems.isEmpty)
                                  ? 'Please select a product'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        // Linked Mode: Items dropdown
                        DropdownButtonFormField<SaleItem>(
                          value: _selectedItem,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Product to Return *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: widget.sale!.items
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
                                labelText: 'Return Qty (بوریاں / تعداد) *',
                                hintText: _isDirectMode
                                    ? '1'
                                    : 'Max ${_selectedItem?.quantity.toStringAsFixed(0) ?? ""}',
                                prefixIcon: const Icon(Icons.numbers),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) => _returnItems.isNotEmpty
                                  ? null
                                  : Validators.positiveNumber(
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
                                labelText: 'Return Rate (فی بوری ریٹ) *',
                                prefixText: 'Rs. ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) => _returnItems.isNotEmpty
                                  ? null
                                  : Validators.positiveNumber(
                                      v,
                                      'Enter valid rate',
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // "+ Add Product to Return List" Button
                      OutlinedButton.icon(
                        onPressed: () => _addCurrentItemToList(showFeedback: true),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text(
                          '+ Add Product to Return List (لسٹ میں شامل کریں / مزید پراڈکٹ)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor: const Color(0xFFE8F5E9),
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Return Items Cart / List
                      if (_returnItems.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Return Products List (${_returnItems.length} آئٹمز)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _returnItems.clear()),
                                    icon: const Icon(
                                      Icons.clear_all,
                                      size: 16,
                                      color: AppColors.danger,
                                    ),
                                    label: const Text(
                                      'Clear All',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              for (int i = 0; i < _returnItems.length; i++) ...[
                                if (i > 0) const Divider(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${i + 1}. ${_returnItems[i].productName}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_returnItems[i].quantity.toStringAsFixed(0)} ${_returnItems[i].unit} × ${CurrencyFormatter.format(_returnItems[i].unitPrice)} = ${CurrencyFormatter.format(_returnItems[i].total)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // - Qty button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setState(() {
                                          if (_returnItems[i].quantity > 1) {
                                            _returnItems[i].quantity -= 1;
                                          } else {
                                            _returnItems.removeAt(i);
                                          }
                                        });
                                      },
                                    ),
                                    Text(
                                      _returnItems[i]
                                          .quantity
                                          .toStringAsFixed(0),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    // + Qty button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        final maxQ = _returnItems[i].maxQty;
                                        if (maxQ != null &&
                                            _returnItems[i].quantity + 1 >
                                                maxQ) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Max sold on invoice is ${maxQ.toStringAsFixed(0)}',
                                              ),
                                              backgroundColor: AppColors.danger,
                                            ),
                                          );
                                          return;
                                        }
                                        setState(() {
                                          _returnItems[i].quantity += 1;
                                        });
                                      },
                                    ),
                                    // Delete button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppColors.danger,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setState(() {
                                          _returnItems.removeAt(i);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Total Amount Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBE9E7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFCCBC)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Refund / Credit (کل رقم):',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFFD84315),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(_totalAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFBF360C),
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
                          labelText:
                              'Refund / Adjustment Mode (رقم کی واپسی کا طریقہ) *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [
                          if ((!_isDirectMode &&
                                  widget.sale!.customerId != null &&
                                  widget.sale!.customerId! > 0) ||
                              (_isDirectMode && _selectedCustomer != null))
                            const DropdownMenuItem(
                              value: 'LEDGER_ADJUST',
                              child: Text(
                                'Credit Customer Khata (کھاتے میں جمع / ادھار کٹوتی)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const DropdownMenuItem(
                            value: 'CASH_REFUND',
                            child: Text(
                              'Cash Refund to Customer (نقد رقم کی واپسی)',
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
                          labelText: 'Reason / Notes (وجہ / تفصیل)',
                          hintText:
                              'e.g. Extra bags returned, Damaged packaging',
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
                          backgroundColor: const Color(0xFFC62828),
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
                                    'Confirm Sales Return & Add to Stock',
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
