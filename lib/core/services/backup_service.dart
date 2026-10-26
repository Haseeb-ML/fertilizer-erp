import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';

class BackupResult {
  final bool success;
  final String message;
  final String? filePath;
  final Map<String, int>? tableCounts;

  BackupResult({
    required this.success,
    required this.message,
    this.filePath,
    this.tableCounts,
  });
}

class BackupService {
  static const int kSchemaVersion = 1;
  static const List<String> _tablesInOrder = [
    DatabaseTables.businessSettings,
    DatabaseTables.products,
    DatabaseTables.customers,
    DatabaseTables.suppliers,
    DatabaseTables.purchases,
    DatabaseTables.purchaseItems,
    DatabaseTables.sales,
    DatabaseTables.saleItems,
    DatabaseTables.payments,
    DatabaseTables.expenses,
    DatabaseTables.stockCostLayers,
    DatabaseTables.stockMovements,
    DatabaseTables.customerLedger,
    DatabaseTables.supplierLedger,
    DatabaseTables.returns,
  ];

  /// Exports complete database to a verified JSON backup file
  static Future<BackupResult> exportBackup({
    DatabaseHelper? dbHelper,
    String? customDirectory,
  }) async {
    try {
      final helper = dbHelper ?? DatabaseHelper.instance;
      final db = await helper.database;

      final backupData = <String, dynamic>{
        'schema_version': kSchemaVersion,
        'app': 'Fertilizer Business ERP',
        'created_at': DateTime.now().toIso8601String(),
        'table_counts': <String, int>{},
        'tables': <String, List<Map<String, dynamic>>>{},
      };

      final tableCounts = <String, int>{};

      for (final table in _tablesInOrder) {
        final rows = await db.query(table);
        tableCounts[table] = rows.length;
        backupData['tables'][table] = rows;
      }
      backupData['table_counts'] = tableCounts;

      final jsonString = jsonEncode(backupData);

      if (kIsWeb) {
        return BackupResult(
          success: true,
          message:
              'Backup successfully created (${tableCounts.values.fold(0, (a, b) => a + b)} records)',
          filePath: null,
          tableCounts: tableCounts,
        );
      }

      String targetDirPath;
      if (customDirectory != null) {
        targetDirPath = customDirectory;
      } else {
        try {
          final tempDir = await getTemporaryDirectory();
          targetDirPath = tempDir.path;
        } catch (_) {
          targetDirPath = io.Directory.systemTemp.path;
        }
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'fertilizer_erp_backup_$timestamp.json';
      final file = io.File('$targetDirPath/$fileName');
      await file.writeAsString(jsonString);

      return BackupResult(
        success: true,
        message:
            'Backup successfully created (${tableCounts.values.fold(0, (a, b) => a + b)} records)',
        filePath: file.path,
        tableCounts: tableCounts,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Backup export failed: $e');
    }
  }

  /// Exports backup directly to JSON string
  static Future<String> exportBackupToJson({DatabaseHelper? dbHelper}) async {
    final helper = dbHelper ?? DatabaseHelper.instance;
    final db = await helper.database;

    final backupData = <String, dynamic>{
      'schema_version': kSchemaVersion,
      'app': 'Fertilizer Business ERP',
      'created_at': DateTime.now().toIso8601String(),
      'table_counts': <String, int>{},
      'tables': <String, List<Map<String, dynamic>>>{},
    };

    final tableCounts = <String, int>{};
    for (final table in _tablesInOrder) {
      final rows = await db.query(table);
      tableCounts[table] = rows.length;
      backupData['tables'][table] = rows;
    }
    backupData['table_counts'] = tableCounts;

    return jsonEncode(backupData);
  }

  /// Validates a backup string before restoration
  static Map<String, dynamic> validateBackupData(String jsonContent) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonContent);
    } catch (_) {
      throw Exception('Invalid file format: Not a valid JSON backup file.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid backup format: root must be a JSON object.');
    }

    final schemaVer = decoded['schema_version'];
    if (schemaVer == null || schemaVer is! int) {
      throw Exception('Incompatible backup file: missing schema version.');
    }

    if (schemaVer > kSchemaVersion) {
      throw Exception(
        'Backup was made with a newer app version (Schema $schemaVer). Please update the app.',
      );
    }

    final tables = decoded['tables'];
    if (tables == null || tables is! Map<String, dynamic>) {
      throw Exception('Corrupted backup file: missing tables data.');
    }

    // Check essential core tables
    const requiredTables = [
      DatabaseTables.products,
      DatabaseTables.customers,
      DatabaseTables.suppliers,
      DatabaseTables.sales,
      DatabaseTables.purchases,
    ];

    for (final req in requiredTables) {
      if (!tables.containsKey(req)) {
        throw Exception(
          'Incomplete backup file: missing required table "$req".',
        );
      }
    }

    return decoded;
  }

  /// Restores verified backup into local database safely within atomic transaction
  static Future<BackupResult> restoreBackup(
    String jsonContent, {
    DatabaseHelper? dbHelper,
  }) async {
    try {
      final validatedData = validateBackupData(jsonContent);
      final tables = validatedData['tables'] as Map<String, dynamic>;

      final helper = dbHelper ?? DatabaseHelper.instance;
      final db = await helper.database;

      final restoredCounts = <String, int>{};

      await db.transaction((txn) async {
        // Clear existing data in reverse order of foreign keys
        final reverseTables = _tablesInOrder.reversed.toList();
        for (final table in reverseTables) {
          await txn.delete(table);
        }

        // Insert rows in foreign-key dependency order
        for (final table in _tablesInOrder) {
          if (tables.containsKey(table) && tables[table] is List) {
            final rows = tables[table] as List;
            int count = 0;
            for (final row in rows) {
              if (row is Map<String, dynamic>) {
                await txn.insert(table, row);
                count++;
              }
            }
            restoredCounts[table] = count;
          }
        }
      });

      return BackupResult(
        success: true,
        message:
            'Database restored successfully! (${restoredCounts.values.fold(0, (a, b) => a + b)} records)',
        tableCounts: restoredCounts,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Restore failed: $e');
    }
  }

  /// Completely deletes all business records from the database safely within an atomic transaction.
  /// If [resetBusinessSettings] is false, agency profile/shop settings are preserved.
  static Future<int> clearAllDatabaseData({
    DatabaseHelper? dbHelper,
    bool resetBusinessSettings = false,
  }) async {
    final helper = dbHelper ?? DatabaseHelper.instance;
    final db = await helper.database;
    int totalDeleted = 0;

    await db.transaction((txn) async {
      final reverseTables = _tablesInOrder.reversed.toList();
      for (final table in reverseTables) {
        if (!resetBusinessSettings &&
            table == DatabaseTables.businessSettings) {
          continue;
        }
        final count = await txn.delete(table);
        totalDeleted += count;
      }
      if (resetBusinessSettings) {
        await DatabaseHelper.seedDefaultSettings(txn);
      }
    });

    return totalDeleted;
  }

  /// Returns live statistics and counts for all stored tables on local storage
  static Future<Map<String, int>> getStorageStats({DatabaseHelper? dbHelper}) async {
    final helper = dbHelper ?? DatabaseHelper.instance;
    final db = await helper.database;
    final counts = <String, int>{};
    for (final table in _tablesInOrder) {
      try {
        final res = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        counts[table] = (res.first['count'] as int?) ?? 0;
      } catch (_) {
        counts[table] = 0;
      }
    }
    return counts;
  }
}

