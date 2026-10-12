import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/validators.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _brandController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _openingStockController;
  late TextEditingController _minStockController;
  late TextEditingController _notesController;

  late String _selectedCategory;
  late String _selectedUnit;
  late String _selectedBagSize;
  bool _isActive = true;
  bool _isLoading = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(
      text:
          p?.sku ??
          'FERT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    _brandController = TextEditingController(
      text: p?.brand ?? AppConstants.popularBrands.first,
    );
    _purchasePriceController = TextEditingController(
      text: p != null ? p.purchasePrice.toStringAsFixed(0) : '',
    );
    _sellingPriceController = TextEditingController(
      text: p != null ? p.sellingPrice.toStringAsFixed(0) : '',
    );
    _openingStockController = TextEditingController(
      text: p != null ? p.openingStock.toStringAsFixed(0) : '0',
    );
    _minStockController = TextEditingController(
      text: p != null ? p.minStockAlert.toStringAsFixed(0) : '10',
    );
    _notesController = TextEditingController(text: p?.notes ?? '');

    _selectedCategory = p?.category ?? AppConstants.fertilizerCategories.first;
    _selectedUnit = p?.unit ?? 'Bag';
    _selectedBagSize = p?.bagSize ?? '50 Kg';
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _brandController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _openingStockController.dispose();
    _minStockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final repo = ref.read(productRepoProvider);
    final now = DateTime.now().toIso8601String();

    final purchasePrice =
        double.tryParse(_purchasePriceController.text.trim()) ?? 0.0;
    final sellingPrice =
        double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final openingStock =
        double.tryParse(_openingStockController.text.trim()) ?? 0.0;
    final minStock = double.tryParse(_minStockController.text.trim()) ?? 10.0;

    try {
      if (isEditing) {
        final updated = widget.product!.copyWith(
          name: _nameController.text.trim(),
          sku: _skuController.text.trim(),
          category: _selectedCategory,
          brand: _brandController.text.trim(),
          bagSize: _selectedBagSize,
          unit: _selectedUnit,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          minStockAlert: minStock,
          notes: _notesController.text.trim(),
          isActive: _isActive,
          updatedAt: now,
        );
        await repo.updateProduct(updated);
      } else {
        final newProduct = Product(
          name: _nameController.text.trim(),
          sku: _skuController.text.trim(),
          category: _selectedCategory,
          brand: _brandController.text.trim(),
          bagSize: _selectedBagSize,
          unit: _selectedUnit,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          openingStock: openingStock,
          currentStock: openingStock,
          minStockAlert: minStock,
          notes: _notesController.text.trim(),
          isActive: _isActive,
          createdAt: now,
          updatedAt: now,
        );
        await repo.insertProduct(newProduct);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Product updated successfully'
                  : 'Product created successfully',
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
            content: Text('Error saving product: $e'),
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
        title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    hintText: 'e.g. Sona Urea / Engro DAP',
                    prefixIcon: Icon(Icons.eco),
                  ),
                  validator: (v) =>
                      Validators.requiredField(v, 'Enter product name'),
                ),
                const SizedBox(height: 12),

                // Category & Brand
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Fertilizer Category *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: AppConstants.fertilizerCategories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(
                    labelText: 'Brand / Manufacturer *',
                    hintText: 'e.g. Fauji Fertilizer (FFC) / Engro',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) =>
                      Validators.requiredField(v, 'Enter brand name'),
                ),
                const SizedBox(height: 12),

                // Bag size & Unit
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBagSize,
                        decoration: const InputDecoration(
                          labelText: 'Bag Size',
                          prefixIcon: Icon(Icons.scale),
                        ),
                        items:
                            [
                                  '50 Kg',
                                  '25 Kg',
                                  '10 Kg',
                                  '1 Liter',
                                  '5 Liter',
                                  'Other',
                                ]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null)
                            setState(() => _selectedBagSize = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          prefixIcon: Icon(Icons.inventory_2),
                        ),
                        items: ['Bag', 'Kg', 'Liter', 'Packet', 'Bottle']
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedUnit = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // SKU
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU / Product Code *',
                    hintText: 'e.g. UREA-50KG',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  validator: (v) =>
                      Validators.requiredField(v, 'Enter SKU or product code'),
                ),
                const SizedBox(height: 12),

                // Prices
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Purchase Rate (PKR) *',
                          hintText: 'e.g. 4500',
                          prefixIcon: Icon(Icons.shopping_cart),
                        ),
                        validator: (v) => Validators.positiveNumber(
                          v,
                          'Enter valid purchase rate',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Selling Rate (PKR) *',
                          hintText: 'e.g. 4800',
                          prefixIcon: Icon(Icons.sell),
                        ),
                        validator: (v) => Validators.positiveNumber(
                          v,
                          'Enter valid selling rate',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Opening Stock & Min Alert
                Row(
                  children: [
                    if (!isEditing) ...[
                      Expanded(
                        child: TextFormField(
                          controller: _openingStockController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Opening Stock',
                            hintText: '0',
                            prefixIcon: Icon(Icons.add_business),
                          ),
                          validator: (v) => Validators.nonNegativeNumber(v),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: TextFormField(
                        controller: _minStockController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Min Stock Alert',
                          hintText: '10',
                          prefixIcon: Icon(Icons.warning_amber),
                        ),
                        validator: (v) => Validators.nonNegativeNumber(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Description (Optional)',
                    hintText: 'Specific storage or chemical info...',
                  ),
                ),
                const SizedBox(height: 12),

                // Active status switch
                SwitchListTile(
                  title: const Text(
                    'Product Status Active',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Inactive products are hidden from POS but preserve history',
                  ),
                  value: _isActive,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
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
                      : Text(isEditing ? 'Save Changes' : 'Create Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
