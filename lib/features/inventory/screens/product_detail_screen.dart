import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import 'product_form_screen.dart';
import 'stock_adjustment_dialog.dart';
import 'stock_movement_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  Future<Product?> _fetchProduct() async {
    return ref.read(productRepoProvider).getProductById(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: FutureBuilder<Product?>(
        future: _fetchProduct(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final product = snapshot.data;
          if (product == null) {
            return const Center(child: Text('Product not found'));
          }

          final margin = product.sellingPrice - product.purchasePrice;
          final marginPercent = product.purchasePrice > 0
              ? (margin / product.purchasePrice) * 100
              : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${product.brand} • ${product.category}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: product.isActive ? 'Active' : 'Inactive',
                              isSuccess: product.isActive,
                              isDanger: !product.isActive,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statColumn(
                              'Current Stock',
                              '${product.currentStock.toStringAsFixed(0)} ${product.unit}',
                              isBold: true,
                            ),
                            _statColumn('Bag Size', product.bagSize),
                            _statColumn('SKU / Code', product.sku),
                          ],
                        ),
                        if (product.isLowStock) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Low Stock Warning: Min alert is ${product.minStockAlert.toStringAsFixed(0)} ${product.unit}',
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Pricing Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pricing & Valuation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statColumn(
                              'Purchase Rate',
                              CurrencyFormatter.format(product.purchasePrice),
                            ),
                            _statColumn(
                              'Selling Rate',
                              CurrencyFormatter.format(product.sellingPrice),
                            ),
                            _statColumn(
                              'Margin',
                              '+${CurrencyFormatter.format(margin)} (${marginPercent.toStringAsFixed(1)}%)',
                              color: AppColors.success,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Stock Inventory Valuation:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(
                                product.inventoryValuation,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                ElevatedButton.icon(
                  onPressed: () async {
                    final res = await StockAdjustmentDialog.show(
                      context,
                      product,
                    );
                    if (res == true) setState(() {});
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text(
                    'Adjust Stock (Correction / Loss / Return)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StockMovementScreen(product: product),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('View Stock Movement History'),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductFormScreen(product: product),
                                ),
                              );
                          if (updated == true) setState(() {});
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Product'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await ConfirmationDialog.show(
                            context,
                            title: product.isActive
                                ? 'Deactivate Product?'
                                : 'Activate Product?',
                            message: product.isActive
                                ? 'Deactivating will hide this product from New Sales, but keep all past records.'
                                : 'Activating will make this product available for sales again.',
                            confirmLabel: product.isActive
                                ? 'Deactivate'
                                : 'Activate',
                            confirmColor: product.isActive
                                ? AppColors.danger
                                : AppColors.success,
                          );
                          if (confirm) {
                            final repo = ref.read(productRepoProvider);
                            if (product.isActive) {
                              await repo.deactivateProduct(product.id!);
                            } else {
                              await repo.activateProduct(product.id!);
                            }
                            setState(() {});
                          }
                        },
                        icon: Icon(
                          product.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                        ),
                        label: Text(
                          product.isActive ? 'Deactivate' : 'Activate',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: product.isActive
                              ? AppColors.danger
                              : AppColors.success,
                          side: BorderSide(
                            color: product.isActive
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statColumn(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
