import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/data/kissan_feeds_data.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/search_bar_widget.dart';
import '../../../core/widgets/status_badge.dart';
import 'product_form_screen.dart';
import 'product_detail_screen.dart';
import 'stock_adjustment_dialog.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _onlyLowStock = false;
  bool? _onlyActive = true;
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Product>> _loadProducts() async {
    final repo = ref.read(productRepoProvider);
    return repo.getProducts(
      search: _searchController.text.trim(),
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      onlyActive: _onlyActive,
      onlyLowStock: _onlyLowStock,
    );
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = _loadProducts();
    });
  }

  Future<void> _importKissanFeedsProducts() async {
    final repo = ref.read(productRepoProvider);
    final kissanProducts = KissanFeedsData.getProducts();
    int addedCount = 0;
    for (final p in kissanProducts) {
      final existing = await repo.getProducts(search: p.sku);
      if (!existing.any((e) => e.sku == p.sku)) {
        await repo.insertProduct(p);
        addedCount++;
      }
    }

    final supplierRepo = ref.read(supplierRepoProvider);
    final existingSuppliers = await supplierRepo.getSuppliers(
      search: 'Kissan Feeds',
    );
    if (existingSuppliers.isEmpty) {
      await supplierRepo.insertSupplier(KissanFeedsData.defaultSupplier);
    }

    _refreshProducts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount > 0
                ? '$addedCount Kissan Feeds products added to inventory!'
                : 'All 17 Kissan Feeds products are already present in inventory.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to reactive update trigger so products list auto-updates when stock/product changes anywhere
    ref.listen<int>(productsUpdateTriggerProvider, (_, __) {
      _refreshProducts();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('inventory_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: ref.tr('refresh'),
            onPressed: _refreshProducts,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: ref.tr('add_product'),
            onPressed: () async {
              final added = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              );
              if (added == true) _refreshProducts();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'import_kissan') {
                _importKissanFeedsProducts();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'import_kissan',
                child: Row(
                  children: [
                    const Icon(Icons.inventory, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(ref.tr('load_kissan_feeds')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                SearchBarWidget(
                  controller: _searchController,
                  hintText: 'Search by name, SKU or brand...',
                  onChanged: (val) => _refreshProducts(),
                ),
                const SizedBox(height: 8),

                // Category & Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Categories'),
                        selected: _selectedCategory == 'All',
                        selectedColor: AppColors.accentLight,
                        onSelected: (_) {
                          _selectedCategory = 'All';
                          _refreshProducts();
                        },
                      ),
                      const SizedBox(width: 6),
                      ...AppConstants.fertilizerCategories.take(6).map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(cat.split(' ').first),
                            selected: _selectedCategory == cat,
                            selectedColor: AppColors.accentLight,
                            onSelected: (_) {
                              _selectedCategory = cat;
                              _refreshProducts();
                            },
                          ),
                        );
                      }),
                      FilterChip(
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 4),
                            Text('Low Stock Only'),
                          ],
                        ),
                        selected: _onlyLowStock,
                        selectedColor: AppColors.warningBg,
                        onSelected: (val) {
                          _onlyLowStock = val;
                          _refreshProducts();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Product List
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _refreshProducts(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.65,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 64,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Products Found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Load Kissan Feeds official catalog or add custom fertilizer items.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _importKissanFeedsProducts,
                                    icon: const Icon(Icons.download),
                                    label: Text(ref.tr('load_kissan_feeds')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final added =
                                          await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => const ProductFormScreen(),
                                        ),
                                      );
                                      if (added == true) _refreshProducts();
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Custom Product'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshProducts(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = products[index];

                      return Card(
                        child: InkWell(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(productId: p.id!),
                              ),
                            );
                            _refreshProducts();
                          },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${p.brand} • ${p.category} (${p.bagSize})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(
                                    label: p.isLowStock
                                        ? 'Low Stock (${p.currentStock.toStringAsFixed(0)})'
                                        : '${p.currentStock.toStringAsFixed(0)} ${p.unit}',
                                    isWarning: p.isLowStock,
                                    isSuccess:
                                        !p.isLowStock && p.currentStock > 0,
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Selling Rate',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(
                                          p.sellingPrice,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Cost Rate',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(
                                          p.purchasePrice,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.tune,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                        tooltip: 'Adjust Stock',
                                        onPressed: () async {
                                          final res =
                                              await StockAdjustmentDialog.show(
                                                context,
                                                p,
                                              );
                                          if (res == true) setState(() {});
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                        tooltip: 'Edit',
                                        onPressed: () async {
                                          final res =
                                              await Navigator.of(
                                                context,
                                              ).push<bool>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ProductFormScreen(
                                                        product: p,
                                                      ),
                                                ),
                                              );
                                          if (res == true) setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
          if (added == true) setState(() {});
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
