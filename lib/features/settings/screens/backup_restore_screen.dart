import 'dart:convert';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_tables.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/widgets/confirmation_dialog.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isProcessing = false;
  String? _lastBackupMessage;
  Map<String, int>? _stats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final dbHelper = ref.read(databaseHelperProvider);
      final stats = await BackupService.getStorageStats(dbHelper: dbHelper);
      if (mounted) {
        setState(() {
          _stats = stats;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<void> _clearDatabase() async {
    // 1. Initial warning dialog
    final confirm1 = await ConfirmationDialog.show(
      context,
      title: ref.tr('clear_database'),
      message:
          '${ref.tr('wipe_database_warning')}\n\nThis will permanently delete all sales invoices, purchases, stock inventory, customers, suppliers, expenses, and ledger entries.',
      confirmLabel: ref.tr('confirm'),
      confirmColor: AppColors.danger,
      icon: Icons.delete_forever,
    );

    if (!confirm1) return;

    // 2. Secondary confirmation dialog with option to keep/reset business profile
    if (!mounted) return;
    bool resetSettings = false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 38,
              ),
              title: Text(
                ref.tr('wipe_database_confirm'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Text(
                    'All transaction and inventory records will be permanently erased.\n\nTip: You can export a backup before wiping data if you wish.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Also reset business profile & settings to default',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: resetSettings,
                    onChanged: (val) {
                      setDialogState(() => resetSettings = val ?? false);
                    },
                  ),
                ],
              ),
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
                  child: Text(ref.tr('delete')),
                ),
              ],
            );
          },
        );
      },
    );

    if (proceed != true) return;

    setState(() => _isProcessing = true);
    final dbHelper = ref.read(databaseHelperProvider);
    try {
      final deletedCount = await BackupService.clearAllDatabaseData(
        dbHelper: dbHelper,
        resetBusinessSettings: resetSettings,
      );

      // Invalidate live providers so all screens update immediately
      ref.invalidate(businessSettingsProvider);

      setState(() {
        _isProcessing = false;
        _lastBackupMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Database cleared successfully! ($deletedCount records removed)',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear database: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isProcessing = true);
    final dbHelper = ref.read(databaseHelperProvider);

    if (kIsWeb) {
      final jsonString =
          await BackupService.exportBackupToJson(dbHelper: dbHelper);
      setState(() => _isProcessing = false);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'fertilizer_erp_backup_$timestamp.json';
      final xFile = XFile.fromData(
        Uint8List.fromList(utf8.encode(jsonString)),
        name: fileName,
        mimeType: 'application/json',
      );
      await Share.shareXFiles([xFile], text: 'Fertilizer ERP Backup File');
      _lastBackupMessage = 'Backup downloaded successfully';
      if (mounted) setState(() {});
      return;
    }

    final result = await BackupService.exportBackup(dbHelper: dbHelper);
    setState(() => _isProcessing = false);

    if (result.success && result.filePath != null) {
      _lastBackupMessage = result.message;
      setState(() {});

      if (!mounted) return;

      // Offer to share file
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 8),
              Text('Backup Created'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              '${result.message}\nSaved to local storage.\nWould you like to share or save a copy to your Google Drive / WhatsApp?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Share.shareXFiles([
                  XFile(result.filePath!),
                ], text: 'Fertilizer ERP Backup File');
              },
              icon: const Icon(Icons.share),
              label: const Text('Share Backup File'),
            ),
          ],
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    // 1. Pick file
    final pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (pickerResult == null) return;
    final pickedFile = pickerResult.files.single;

    String jsonContent;
    if (pickedFile.bytes != null) {
      jsonContent = utf8.decode(pickedFile.bytes!);
    } else if (pickedFile.path != null) {
      final file = io.File(pickedFile.path!);
      jsonContent = await file.readAsString();
    } else {
      return;
    }

    // 2. Validate first
    try {
      final validated = BackupService.validateBackupData(jsonContent);
      final counts = validated['table_counts'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;

      // 3. Mandatory confirmation warning dialog
      final confirm = await ConfirmationDialog.show(
        context,
        title: 'Restore Database Backup?',
        message:
            'WARNING: Restoring will overwrite all current local data with the contents of this backup file (${counts.values.fold(0, (a, b) => a + (b as int))} records). Are you sure?',
        confirmLabel: 'Restore Database',
        confirmColor: AppColors.danger,
        icon: Icons.warning,
      );

      if (!confirm) return;

      setState(() => _isProcessing = true);
      final dbHelper = ref.read(databaseHelperProvider);
      final restoreResult = await BackupService.restoreBackup(
        jsonContent,
        dbHelper: dbHelper,
      );
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restoreResult.message),
            backgroundColor: restoreResult.success
                ? AppColors.success
                : AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid backup file: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRecords = _stats != null
        ? _stats!.values.fold<int>(0, (a, b) => a + b)
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('data_storage')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Storage Stats',
            onPressed: _loadStats,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Status Card: 100% Offline Device Storage
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00796B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF004D40).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.storage_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Offline Device Storage (لوکل ڈیٹا بیس)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ref.tr('data_storage_desc'),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Status: 100% Offline & Private',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _loadingStats ? 'Loading...' : '$totalRecords Records',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Database Storage Stats Grid
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stored Business Data (محفوظ شدہ ریکارڈز)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (_loadingStats)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        _buildStatTile(
                          icon: Icons.point_of_sale,
                          color: AppColors.primary,
                          label: 'Sales Invoices',
                          count: _stats?[DatabaseTables.sales] ?? 0,
                        ),
                        _buildStatTile(
                          icon: Icons.shopping_bag_outlined,
                          color: AppColors.secondary,
                          label: 'Purchases',
                          count: _stats?[DatabaseTables.purchases] ?? 0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatTile(
                          icon: Icons.people_outline,
                          color: const Color(0xFF0288D1),
                          label: 'Customers',
                          count: _stats?[DatabaseTables.customers] ?? 0,
                        ),
                        _buildStatTile(
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFF00796B),
                          label: 'Products',
                          count: _stats?[DatabaseTables.products] ?? 0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatTile(
                          icon: Icons.receipt_long,
                          color: AppColors.danger,
                          label: 'Expenses',
                          count: _stats?[DatabaseTables.expenses] ?? 0,
                        ),
                        _buildStatTile(
                          icon: Icons.payments_outlined,
                          color: AppColors.success,
                          label: 'Payments & Ledger',
                          count: (_stats?[DatabaseTables.payments] ?? 0) +
                              (_stats?[DatabaseTables.customerLedger] ?? 0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Export / Save Backup Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Save All Data / Export Backup (ڈیٹا محفوظ کریں)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Export complete JSON file to device storage, WhatsApp, or Google Drive',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _exportBackup,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text(
                        'Save / Export Data File Now (ڈیٹا فائل محفوظ کریں)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (_lastBackupMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _lastBackupMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Restore Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings_backup_restore,
                            color: AppColors.warning,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Restore from Backup File (ڈیٹا بحال کریں)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Load previously saved JSON backup file into this device',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _restoreBackup,
                      icon: const Icon(Icons.file_open),
                      label: const Text(
                        'Select Backup File to Restore (فائل منتخب کریں)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Danger Zone: Reset / Clear Database
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: AppColors.danger.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_forever,
                            color: AppColors.danger,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.tr('clear_database'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.danger,
                                ),
                              ),
                              Text(
                                ref.tr('clear_database_sub'),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _clearDatabase,
                      icon: const Icon(Icons.delete_sweep, color: Colors.white),
                      label: Text(
                        ref.tr('clear_database'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Security note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: AppColors.info, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '100% Offline & Private: No cloud servers are involved. Your financial and customer records stay exclusively on this device unless you choose to export and share a backup.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
