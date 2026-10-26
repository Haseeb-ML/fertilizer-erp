import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/storage.dart';
import '../../../core/models/storage_stock.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/date_formatter.dart';

class StockTransferScreen extends ConsumerStatefulWidget {
  final int? initialFromStorageId;
  final int? initialProductId;

  const StockTransferScreen({
    super.key,
    this.initialFromStorageId,
    this.initialProductId,
  });

  @override
  ConsumerState<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends ConsumerState<StockTransferScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _fromStorageId;
  int? _toStorageId;
  int? _selectedProductId;
  final _qtyController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _driverController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _transferDate;

  List<Storage> _storages = [];
  List<StorageStock> _sourceStocks = [];
  bool _isLoading = true;
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    _transferDate = DateTime.now();
    _fromStorageId = widget.initialFromStorageId;
    _selectedProductId = widget.initialProductId;
    _loadData();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _vehicleController.dispose();
    _driverController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(storageRepoProvider);
    final storages = await repo.getStorages(onlyActive: true);

    setState(() {
      _storages = storages;
      if (_fromStorageId == null && storages.isNotEmpty) {
        _fromStorageId = storages.first.id;
      }
      if (_toStorageId == null && storages.length > 1) {
        _toStorageId = storages[1].id;
      }
    });

    if (_fromStorageId != null) {
      await _loadSourceStocks(_fromStorageId!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSourceStocks(int storageId) async {
    final repo = ref.read(storageRepoProvider);
    final stocks = await repo.getStorageStocks(storageId);
    setState(() {
      _sourceStocks = stocks;
      // If previously selected product is not in this storage, pick first with stock
      if (_selectedProductId != null && !stocks.any((s) => s.productId == _selectedProductId)) {
        _selectedProductId = null;
      }
      if (_selectedProductId == null && stocks.isNotEmpty) {
        final available = stocks.where((s) => s.quantity > 0);
        if (available.isNotEmpty) {
          _selectedProductId = available.first.productId;
        } else {
          _selectedProductId = stocks.first.productId;
        }
      }
      _isLoading = false;
    });
  }

  StorageStock? get _selectedStock {
    if (_selectedProductId == null) return null;
    try {
      return _sourceStocks.firstWhere((s) => s.productId == _selectedProductId);
    } catch (_) {
      return null;
    }
  }

  double get _availableQuantity => _selectedStock?.quantity ?? 0.0;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _transferDate = picked);
    }
  }

  Future<void> _executeTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromStorageId == null || _toStorageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both storages / گودام منتخب کریں')),
      );
      return;
    }
    if (_fromStorageId == _toStorageId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination cannot be identical / الگ الگ گودام چنیں')),
      );
      return;
    }
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select product to transfer / پراڈکٹ منتخب کریں')),
      );
      return;
    }

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid quantity / درست تعداد درج کریں')),
      );
      return;
    }
    if (qty > _availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot transfer more than available stock ($_availableQuantity Bags) / گودام میں اتنا مال موجود نہیں',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isTransferring = true);
    final repo = ref.read(storageRepoProvider);

    try {
      final dateStr = DateFormatter.toSqlDate(_transferDate);
      await repo.transferStock(
        fromStorageId: _fromStorageId!,
        toStorageId: _toStorageId!,
        productId: _selectedProductId!,
        quantity: qty,
        transferDate: dateStr,
        vehicleNumber: _vehicleController.text.trim(),
        driverName: _driverController.text.trim(),
        notes: _notesController.text.trim(),
      );

      // Trigger reactive refresh
      ref.read(storagesUpdateTriggerProvider.notifier).state++;
      ref.read(productsUpdateTriggerProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock transfer completed successfully! ($qty Bags transferred)',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stock Transfer (مال منتقلی)')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_storages.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stock Transfer (مال منتقلی)')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warehouse_outlined, size: 64, color: AppColors.warning),
                const SizedBox(height: 16),
                const Text(
                  'Minimum 2 storages required for transfer.\n(مال منتقل کرنے کے لیے کم از کم 2 گودام ضروری ہیں)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Godown (نیا گودام بنائیں)'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Transfer (مال منتقلی)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Transfer Route Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transfer Route (منتقلی کا راستہ)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      // From Storage Dropdown
                      DropdownButtonFormField<int>(
                        value: _fromStorageId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'From Storage (کس گودام سے مال نکلے گا) *',
                          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                          prefixIcon: const Icon(Icons.outbox, color: AppColors.danger),
                          filled: true,
                          fillColor: AppColors.danger.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: _storages.map((s) {
                          return DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(
                              s.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            setState(() => _fromStorageId = newId);
                            _loadSourceStocks(newId);
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Connecting Arrow
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_downward,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // To Storage Dropdown
                      DropdownButtonFormField<int>(
                        value: _toStorageId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'To Storage (کس گودام میں مال پہنچے گا) *',
                          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                          prefixIcon: const Icon(Icons.move_to_inbox, color: AppColors.success),
                          filled: true,
                          fillColor: AppColors.success.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: _storages.map((s) {
                          return DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(
                              s.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            setState(() => _toStorageId = newId);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Product & Quantity Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product & Quantity (پراڈکٹ اور بوریوں کی تعداد)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _selectedProductId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Product / Fertilizer (کھاد منتخب کریں) *',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        items: _sourceStocks.map((s) {
                          return DropdownMenuItem<int>(
                            value: s.productId,
                            child: Text(
                              '${s.productName} (${s.productBrand}) - Avail: ${s.quantity.toStringAsFixed(0)} ${s.unit}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: s.quantity > 0 ? FontWeight.w600 : FontWeight.normal,
                                color: s.quantity > 0 ? Colors.black87 : Colors.grey,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) => setState(() => _selectedProductId = id),
                        validator: (val) => val == null ? 'Please select a product' : null,
                      ),
                      const SizedBox(height: 8),

                      // Live Available Stock Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _availableQuantity > 0 ? AppColors.successBg : AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _availableQuantity > 0 ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Stock in Source Godown:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${_availableQuantity.toStringAsFixed(0)} Bags',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _availableQuantity > 0 ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Transfer Quantity (منتقل کی جانے والی تعداد) *',
                          hintText: 'e.g. 50',
                          prefixIcon: const Icon(Icons.numbers),
                          suffixText: 'Bags',
                          suffixIcon: TextButton(
                            onPressed: _availableQuantity > 0
                                ? () => _qtyController.text = _availableQuantity.toStringAsFixed(0)
                                : null,
                            child: const Text('ALL', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter quantity';
                          final num = double.tryParse(val.trim());
                          if (num == null || num <= 0) return 'Enter positive quantity';
                          if (num > _availableQuantity) return 'Cannot exceed available stock';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Transport & Date Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transport & Details (گاڑی اور تاریخ)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                        title: const Text('Transfer Date (منتقلی کی تاریخ)'),
                        subtitle: Text(
                          DateFormatter.formatDate(_transferDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _selectDate,
                          child: const Text('Change Date'),
                        ),
                      ),
                      const Divider(),
                      TextFormField(
                        controller: _vehicleController,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle / Rickshaw / Truck No (گاڑی نمبر)',
                          hintText: 'e.g. LES-1234, Shahzor',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _driverController,
                        decoration: const InputDecoration(
                          labelText: 'Driver / Transport Incharge (ڈرائیور کا نام)',
                          hintText: 'e.g. Ghulam Rasool',
                          prefixIcon: Icon(Icons.person_pin_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes / Remarks (ریمارکس یا نوٹ)',
                          hintText: 'Reason for transfer, bill reference, etc.',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                icon: _isTransferring
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz),
                label: const Text(
                  'Confirm & Execute Transfer (مال منتقل کریں)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isTransferring ? null : _executeTransfer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
