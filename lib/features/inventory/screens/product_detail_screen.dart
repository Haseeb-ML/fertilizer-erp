import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
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
  Product? _product;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    final p = await ref
        .read(productRepoProvider)
        .getProductById(widget.productId);
    if (mounted) {
      setState(() {
        _product = p;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDeleteProduct(Product product) async {
    final repo = ref.read(productRepoProvider);
    final stats = await repo.getProductUsageStats(product.id!);
    final salesCount = stats['sales'] ?? 0;
    final purchasesCount = stats['purchases'] ?? 0;

    if (!mounted) return;

    if (salesCount == 0 && purchasesCount == 0) {
      final confirm = await ConfirmationDialog.show(
        context,
        title: 'Delete Product?',
        message:
            'Are you sure you want to permanently delete "${product.name}"? This action cannot be undone.',
        confirmLabel: 'Delete Product',
        confirmColor: AppColors.danger,
        icon: Icons.delete_forever,
      );

      if (confirm && mounted) {
        try {
          await repo.deleteProduct(product.id!);
          ref.invalidate(dashboardDataProvider);
          if (mounted) {
            Navigator.of(context).pop(true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product deleted successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting product: $e'),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        }
      }
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber, color: AppColors.warning, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Product Has Records',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This product is linked to $salesCount sales invoice(s) and $purchasesCount purchase bill(s).',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Deleting it permanently will affect invoice history and reports.\n\nRecommended: Deactivate this product instead so it is hidden from New Sales while keeping historical records safe.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await repo.deactivateProduct(product.id!);
                ref.invalidate(dashboardDataProvider);
                _loadProduct();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product deactivated successfully'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.visibility_off, size: 16),
              label: const Text('Deactivate (Safe)'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final forceConfirm = await ConfirmationDialog.show(
                  context,
                  title: 'Force Delete Product?',
                  message:
                      'Are you completely sure? This will permanently delete "${product.name}" and remove its line items from all past sales and purchases.',
                  confirmLabel: 'Force Delete',
                  confirmColor: AppColors.danger,
                  icon: Icons.delete_forever,
                );
                if (forceConfirm && mounted) {
                  try {
                    await repo.deleteProduct(product.id!, force: true);
                    ref.invalidate(dashboardDataProvider);
                    if (mounted) {
                      Navigator.of(context).pop(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product permanently deleted'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Force Delete'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final margin = product != null
        ? product.sellingPrice - product.purchasePrice
        : 0.0;
    final marginPercent = product != null && product.purchasePrice > 0
        ? (margin / product.purchasePrice) * 100
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          if (product != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Product',
              onPressed: () => _handleDeleteProduct(product),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : product == null
              ? const Center(child: Text('Product not found'))
              : SingleChildScrollView(
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
                    if (res == true) _loadProduct();
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
                          if (updated == true) _loadProduct();
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
                            ref.invalidate(dashboardDataProvider);
                            _loadProduct();
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _handleDeleteProduct(product),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Delete Product'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
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
