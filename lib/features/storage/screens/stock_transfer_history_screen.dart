import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/stock_transfer.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/date_formatter.dart';
import 'stock_transfer_screen.dart';

class StockTransferHistoryScreen extends ConsumerStatefulWidget {
  final int? storageId;

  const StockTransferHistoryScreen({super.key, this.storageId});

  @override
  ConsumerState<StockTransferHistoryScreen> createState() => _StockTransferHistoryScreenState();
}

class _StockTransferHistoryScreenState extends ConsumerState<StockTransferHistoryScreen> {
  List<StockTransfer> _transfers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    setState(() => _isLoading = true);
    final repo = ref.read(storageRepoProvider);
    final list = await repo.getStockTransfers(storageId: widget.storageId);
    setState(() {
      _transfers = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(storagesUpdateTriggerProvider, (_, __) => _loadTransfers());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Transfer History (منتقلی ریکارڈ)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransfers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Transfer'),
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final res = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => StockTransferScreen(initialFromStorageId: widget.storageId),
            ),
          );
          if (res == true) _loadTransfers();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transfers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_toggle_off, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'No stock transfers found\n(کوئی مال منتقلی کا ریکارڈ نہیں ملا)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Make First Transfer'),
                        onPressed: () async {
                          final res = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => StockTransferScreen(initialFromStorageId: widget.storageId),
                            ),
                          );
                          if (res == true) _loadTransfers();
                        },
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: _transfers.length,
                  itemBuilder: (context, index) {
                    final t = _transfers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Transfer No & Date
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t.transferNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormatter.formatDate(DateTime.tryParse(t.transferDate) ?? DateTime.now()),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 16),

                            // Route: From -> To
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'From (منتقل کنندہ)',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.fromStorageName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Icon(Icons.arrow_forward, color: AppColors.primary, size: 20),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'To (منتقل الیہ)',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.toStorageName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Product & Quantity
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.productName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${t.quantity.toStringAsFixed(0)} Bags',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Driver / Vehicle / Notes
                            if (t.vehicleNumber.isNotEmpty || t.driverName.isNotEmpty || t.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (t.vehicleNumber.isNotEmpty) ...[
                                    const Icon(Icons.local_shipping, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      t.vehicleNumber,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  if (t.driverName.isNotEmpty) ...[
                                    const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      t.driverName,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  if (t.notes.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        t.notes,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
