import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/storage.dart';
import '../../../core/models/storage_stock.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import 'storage_form_screen.dart';
import 'stock_transfer_screen.dart';
import 'stock_transfer_history_screen.dart';

class StorageDetailScreen extends ConsumerStatefulWidget {
  final Storage storage;

  const StorageDetailScreen({super.key, required this.storage});

  @override
  ConsumerState<StorageDetailScreen> createState() => _StorageDetailScreenState();
}

class _StorageDetailScreenState extends ConsumerState<StorageDetailScreen> {
  late Storage _storage;
  List<StorageStock> _stocks = [];
  List<StorageStock> _filteredStocks = [];
  bool _isLoading = true;
  double _totalBags = 0.0;
  double _valuation = 0.0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _storage = widget.storage;
    _loadStorageData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(storageRepoProvider);
    if (_storage.id != null) {
      final updated = await repo.getStorageById(_storage.id!);
      if (updated != null) _storage = updated;

      final stocks = await repo.getStorageStocks(_storage.id!);
      final totalBags = await repo.getTotalStorageQuantity(_storage.id!);
      final valuation = await repo.getStorageValuation(_storage.id!);

      setState(() {
        _stocks = stocks;
        _filteredStocks = stocks;
        _totalBags = totalBags;
        _valuation = valuation;
        _isLoading = false;
      });
      _applySearch();
    }
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredStocks = _stocks;
      } else {
        _filteredStocks = _stocks.where((s) {
          return s.productName.toLowerCase().contains(q) ||
              s.productBrand.toLowerCase().contains(q) ||
              s.category.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(storagesUpdateTriggerProvider, (_, __) => _loadStorageData());
    ref.listen(productsUpdateTriggerProvider, (_, __) => _loadStorageData());

    final capacity = _storage.capacityBags;
    final capacityPercent = capacity > 0 ? (_totalBags / capacity).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_storage.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Storage',
            onPressed: () async {
              final res = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => StorageFormScreen(storage: _storage),
                ),
              );
              if (res == true) _loadStorageData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transfer History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StockTransferHistoryScreen(storageId: _storage.id),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Transfer Stock Out'),
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final res = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => StockTransferScreen(initialFromStorageId: _storage.id),
            ),
          );
          if (res == true) _loadStorageData();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStorageData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Summary Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.08),
                              Colors.white,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warehouse, color: AppColors.primary, size: 28),
                                    const SizedBox(width: 8),
                                    Text(
                                      _storage.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_storage.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRIMARY / شاپ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_storage.location.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _storage.location,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            if (_storage.inchargeName.isNotEmpty || _storage.contactNumber.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_storage.inchargeName} ${_storage.contactNumber.isNotEmpty ? '(${_storage.contactNumber})' : ''}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 20),

                            // Metrics
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Stock',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${_totalBags.toStringAsFixed(0)} Bags',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Inventory Value',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(_valuation),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Capacity Progress
                            if (capacity > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Capacity: ${_totalBags.toStringAsFixed(0)} / $capacity Bags',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${(capacityPercent * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: capacityPercent > 0.9 ? AppColors.danger : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: capacityPercent,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    capacityPercent > 0.9 ? AppColors.danger : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search & Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stock in this Storage (${_filteredStocks.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products in this godown...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _applySearch();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => _applySearch(),
                    ),
                    const SizedBox(height: 12),

                    // Products List
                    if (_filteredStocks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            _searchController.text.isNotEmpty
                                ? 'No products match search'
                                : 'No products recorded in this storage yet',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredStocks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final stock = _filteredStocks[index];
                          final hasStock = stock.quantity > 0;

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: hasStock
                                    ? AppColors.primary.withOpacity(0.12)
                                    : Colors.grey.shade200,
                                child: Icon(
                                  Icons.eco,
                                  color: hasStock ? AppColors.primary : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                stock.productName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${stock.productBrand} • ${stock.bagSize.isNotEmpty ? stock.bagSize : stock.category}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${stock.quantity.toStringAsFixed(0)} ${stock.unit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: hasStock ? AppColors.primary : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(stock.quantity * stock.purchasePrice),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 70), // Space for FAB
                  ],
                ),
              ),
            ),
    );
  }
}
