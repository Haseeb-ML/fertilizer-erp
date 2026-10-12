import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
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
              content: Column(
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
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 8),
              Text('Backup Created'),
            ],
          ),
          content: Text(
            '${result.message}\nSaved to local storage.\nWould you like to share or save a copy to your Google Drive / WhatsApp?',
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
    );

    if (pickerResult == null || pickerResult.files.single.path == null) return;

    final file = File(pickerResult.files.single.path!);
    final jsonContent = await file.readAsString();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Database Backup & Restore')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Export Card
            Card(
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
                            color: AppColors.primaryLight.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Export Full Backup',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Save all sales, inventory, ledgers, and payments locally',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _exportBackup,
                      icon: const Icon(Icons.backup),
                      label: const Text('Generate & Export Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(45),
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
            const SizedBox(height: 20),

            // Restore Card
            Card(
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Restore From Backup',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Select a backup JSON file to restore your business records',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _restoreBackup,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Select File to Restore'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        minimumSize: const Size.fromHeight(45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Danger Zone: Reset / Delete All Database Data
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                                  fontSize: 16,
                                  color: AppColors.danger,
                                ),
                              ),
                              Text(
                                ref.tr('clear_database_sub'),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                        minimumSize: const Size.fromHeight(45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

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
                      '100% Offline & Private: Backups are stored strictly on your device or shared directly by you without cloud servers.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
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
}
