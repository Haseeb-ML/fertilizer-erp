import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/storage.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import 'storage_detail_screen.dart';
import 'storage_form_screen.dart';
import 'stock_transfer_screen.dart';
import 'stock_transfer_history_screen.dart';

class StorageListScreen extends ConsumerStatefulWidget {
  const StorageListScreen({super.key});

  @override
  ConsumerState<StorageListScreen> createState() => _StorageListScreenState();
}

class _StorageListScreenState extends ConsumerState<StorageListScreen> {
  List<Storage> _storages = [];
  Map<int, double> _storageQuantities = {};
  Map<int, double> _storageValuations = {};
  bool _isLoading = true;
  double _grandTotalBags = 0.0;
  double _grandTotalValue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStorages();
  }

  Future<void> _loadStorages() async {
    setState(() => _isLoading = true);
    final repo = ref.read(storageRepoProvider);
    final storages = await repo.getStorages();

    final Map<int, double> quantities = {};
    final Map<int, double> valuations = {};
    double grandBags = 0.0;
    double grandValue = 0.0;

    for (final s in storages) {
      if (s.id != null) {
        final q = await repo.getTotalStorageQuantity(s.id!);
        final v = await repo.getStorageValuation(s.id!);
        quantities[s.id!] = q;
        valuations[s.id!] = v;
        grandBags += q;
        grandValue += v;
      }
    }

    setState(() {
      _storages = storages;
      _storageQuantities = quantities;
      _storageValuations = valuations;
      _grandTotalBags = grandBags;
      _grandTotalValue = grandValue;
      _isLoading = false;
    });
  }

  Future<void> _confirmDeleteStorage(Storage storage, double bags) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Storage (گودام ختم کریں)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${storage.name}"?\n(کیا آپ واقعی اس گودام کو ڈیلیٹ کرنا چاہتے ہیں؟)',
              style: const TextStyle(fontSize: 14),
            ),
            if (bags > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This storage currently has ${bags.toStringAsFixed(0)} bags in stock. Deleting it will remove this storage.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF856404), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ref.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete / ڈیلیٹ کریں'),
          ),
        ],
      ),
    );

    if (confirmed == true && storage.id != null) {
      final repo = ref.read(storageRepoProvider);
      await repo.deleteStorage(storage.id!);
      ref.read(storagesUpdateTriggerProvider.notifier).state++;
      ref.read(productsUpdateTriggerProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage "${storage.name}" deleted / گودام حذف کر دیا گیا'),
            backgroundColor: AppColors.danger,
          ),
        );
        _loadStorages();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(storagesUpdateTriggerProvider, (_, __) => _loadStorages());
    ref.listen(productsUpdateTriggerProvider, (_, __) => _loadStorages());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouses & Godowns (گودام)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Transfer Stock',
            onPressed: () async {
              final res = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const StockTransferScreen()),
              );
              if (res == true) _loadStorages();
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transfer History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StockTransferHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Godown / Storage',
            onPressed: () async {
              final res = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const StorageFormScreen()),
              );
              if (res == true) _loadStorages();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorages,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add, color: Colors.white, size: 22),
        label: const Text(
          'Add Godown / Storage',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: const Color(0xFF0F3B2E),
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: () async {
          final res = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const StorageFormScreen()),
          );
          if (res == true) _loadStorages();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStorages,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // KPI Overview Header Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F3B2E), Color(0xFF1B4332)],
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
                              const Row(
                                children: [
                                  Icon(Icons.warehouse, color: Color(0xFFF3C623), size: 26),
                                  SizedBox(width: 8),
                                  Text(
                                    'Total Storage Overview',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_storages.length} Storages',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Bags in Stock',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_grandTotalBags.toStringAsFixed(0)} Bags',
                                      style: const TextStyle(
                                        color: Color(0xFFF3C623),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
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
                                      'Total Stock Valuation',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.format(_grandTotalValue),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                  label: const Text(
                                    '+ Add Godown',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D6A4F),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    final res = await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(builder: (_) => const StorageFormScreen()),
                                    );
                                    if (res == true) _loadStorages();
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 4,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Transfer',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white38),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onPressed: () async {
                                    final res = await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(builder: (_) => const StockTransferScreen()),
                                    );
                                    if (res == true) _loadStorages();
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.history, size: 16, color: Colors.white),
                                  label: const Text(
                                    'History',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white38),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const StockTransferHistoryScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'All Godowns & Warehouses (تمام گودام)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // List of Storages
                  ..._storages.map((s) {
                    final bags = _storageQuantities[s.id] ?? 0.0;
                    final val = _storageValuations[s.id] ?? 0.0;
                    final capacity = s.capacityBags;
                    final capacityPct = capacity > 0 ? (bags / capacity).clamp(0.0, 1.0) : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: s.isDefault
                            ? const BorderSide(color: AppColors.primary, width: 1.5)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StorageDetailScreen(storage: s),
                            ),
                          );
                          _loadStorages();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title Row
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: s.isDefault
                                        ? AppColors.primary.withOpacity(0.15)
                                        : Colors.grey.shade100,
                                    child: Icon(
                                      Icons.warehouse,
                                      color: s.isDefault ? AppColors.primary : AppColors.textSecondary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                s.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (s.isDefault)
                                              Container(
                                                margin: const EdgeInsets.only(left: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'PRIMARY',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (s.location.isNotEmpty)
                                          Text(
                                            s.location,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        tooltip: 'Edit Storage (ترمیم)',
                                        onPressed: () async {
                                          final res = await Navigator.of(context).push<bool>(
                                            MaterialPageRoute(
                                              builder: (_) => StorageFormScreen(storage: s),
                                            ),
                                          );
                                          if (res == true) _loadStorages();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                                        tooltip: 'Delete Storage (گودام ختم کریں)',
                                        onPressed: () => _confirmDeleteStorage(s, bags),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 18),

                              // Incharge & Stock Metrics
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'In-Charge',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        s.inchargeName.isNotEmpty ? s.inchargeName : 'Sheikh Uzair',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Bags in Stock',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${bags.toStringAsFixed(0)} Bags',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Inventory Value',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(val),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Capacity Bar
                              if (capacity > 0) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Capacity: ${bags.toStringAsFixed(0)} / $capacity Bags',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      '${(capacityPct * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: capacityPct > 0.9 ? AppColors.danger : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: capacityPct,
                                    minHeight: 5,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      capacityPct > 0.9 ? AppColors.danger : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 95), // Spacing for FAB
                ],
              ),
            ),
    );
  }
}
