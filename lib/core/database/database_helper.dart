import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../data/kissan_feeds_data.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sale_repository.dart';
import 'database_tables.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _database;
  static String dbName = 'fertilizer_erp.db';

  /// For testing: allows overriding database instance (e.g. sqflite_common_ffi / in-memory)
  static void setMockDatabase(Database? db) {
    _database = db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path;
    if (kIsWeb) {
      path = dbName;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, dbName);
    }

    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        for (final query in DatabaseTables.createTableQueries) {
          await db.execute(query);
        }
        for (final index in DatabaseTables.createIndexQueries) {
          await db.execute(index);
        }
        await seedDefaultSettings(db);
        await seedDefaultProducts(db);
        await seedDefaultSuppliers(db);
      },
    );

    // Ensure initial settings and catalog are seeded if tables are empty
    await seedDefaultSettings(db);
    await seedDefaultProducts(db);
    await seedDefaultSuppliers(db);
    await syncInventoryCostLayersAndSales(db);

    return db;
  }

  static Future<void> seedDefaultSettings(DatabaseExecutor db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseTables.businessSettings}',
      ),
    );
    if (count == 0) {
      final now = DateTime.now().toIso8601String();
      await db.insert(DatabaseTables.businessSettings, {
        'id': 1,
        'business_name': 'Sheikh Uzair & Co - Fertilizer & Feeds',
        'owner_name': 'Sheikh Uzair',
        'phone': '+92 3498460039',
        'address': 'Grain Market / Fertilizer & Feed Hub',
        'city': 'Punjab, Pakistan',
        'ntn_strn': '1234567-8',
        'invoice_prefix': 'INV-',
        'purchase_prefix': 'PUR-',
        'currency_symbol': '₨',
        'pin_code': '',
        'is_pin_enabled': 0,
        'initial_cash_balance': 0.0,
        'updated_at': now,
      });
    } else {
      await db.rawUpdate('''
        UPDATE ${DatabaseTables.businessSettings}
        SET phone = '+92 3498460039'
        WHERE phone = '0300-1234567' OR phone = '' OR phone IS NULL
      ''');
    }
  }

  static Future<void> seedDefaultProducts(DatabaseExecutor db) async {
    try {
      final now = DateTime.now().toIso8601String();
      final products = KissanFeedsData.getProducts();
      for (final p in products) {
        final existing = await db.query(
          DatabaseTables.products,
          where: 'sku = ?',
          whereArgs: [p.sku],
        );
        if (existing.isEmpty) {
          final id = await db.insert(DatabaseTables.products, p.toMap());
          if (p.openingStock > 0) {
            await db.insert(DatabaseTables.stockCostLayers, {
              'product_id': id,
              'purchase_id': null,
              'purchase_date': now.substring(0, 10),
              'unit_cost': p.purchasePrice,
              'original_quantity': p.openingStock,
              'remaining_quantity': p.openingStock,
              'created_at': now,
            });

            await db.insert(DatabaseTables.stockMovements, {
              'product_id': id,
              'product_name': p.name,
              'movement_type': 'OPENING_STOCK',
              'quantity': p.openingStock,
              'balance_after': p.openingStock,
              'reference_id': null,
              'reference_type': 'OPENING',
              'notes': 'Initial opening stock',
              'movement_date': now.substring(0, 10),
              'created_at': now,
            });
          }
        }
      }
    } catch (_) {
      // Graceful fallback
    }
  }

  static Future<void> seedDefaultSuppliers(DatabaseExecutor db) async {
    try {
      final existing = await db.query(
        DatabaseTables.suppliers,
        where: 'name = ?',
        whereArgs: [KissanFeedsData.defaultSupplier.name],
      );
      if (existing.isEmpty) {
        await db.insert(
          DatabaseTables.suppliers,
          KissanFeedsData.defaultSupplier.toMap(),
        );
      }
    } catch (_) {
      // Graceful fallback
    }
  }

  /// Synchronizes opening stock cost layers and recalculates sales profit
  static Future<void> syncInventoryCostLayersAndSales(
    DatabaseExecutor db,
  ) async {
    try {
      // 1. If Kisaan Dairy Gold (Pellet No. 32) still has the old dummy purchase rate of 4225.0,
      // update it to 3000.0 as requested.
      await db.update(
        DatabaseTables.products,
        {'purchase_price': 3000.0},
        where:
            "(sku = 'KF-32-PELLET' OR name LIKE '%Pellet No. 32%') AND purchase_price = 4225.0",
      );

      // 2. Synchronize all opening stock layers (purchase_id IS NULL) with product purchase_price
      final products = await db.query(DatabaseTables.products);
      for (final p in products) {
        final pId = p['id'] as int;
        final pPrice = (p['purchase_price'] as num?)?.toDouble() ?? 0.0;
        if (pPrice > 0) {
          await db.update(
            DatabaseTables.stockCostLayers,
            {'unit_cost': pPrice},
            where: 'product_id = ? AND purchase_id IS NULL',
            whereArgs: [pId],
          );
        }
      }

      // 3. Recalculate profit on existing sales to correct historical invoices (e.g. INV-2026-0003)
      await SaleRepository.recalculateAllSalesProfits(db);

      // 4. Reconcile all customer ledgers to ensure old sales invoices and balances are verified
      await CustomerRepository.reconcileAllCustomerLedgers(db);

      // 5. Update default business phone number to user's real number (+92 3498460039)
      await db.rawUpdate('''
        UPDATE ${DatabaseTables.businessSettings}
        SET phone = '+92 3498460039'
        WHERE phone = '0300-1234567' OR phone = '' OR phone IS NULL
      ''');
    } catch (e) {
      debugPrint('syncInventoryCostLayersAndSales error: $e');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Delete DB file (for test resets or clean restore)
  Future<void> deleteDatabaseFile() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);
    await deleteDatabase(path);
  }
}
