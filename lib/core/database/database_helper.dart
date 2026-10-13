import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../data/kissan_feeds_data.dart';
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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

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
        'phone': '0300-1234567',
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
    }
  }

  static Future<void> seedDefaultProducts(DatabaseExecutor db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseTables.products}',
      ),
    );
    if (count == 0) {
      final now = DateTime.now().toIso8601String();
      final products = KissanFeedsData.getProducts();
      for (final p in products) {
        final id = await db.insert(DatabaseTables.products, p.toMap());
        if (p.openingStock > 0) {
          await db.insert(DatabaseTables.stockCostLayers, {
            'product_id': id,
            'purchase_id': null,
            'purchase_date': now.substring(0, 10),
            'unit_cost': p.purchasePrice,
            'initial_quantity': p.openingStock,
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
  }

  static Future<void> seedDefaultSuppliers(DatabaseExecutor db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseTables.suppliers}',
      ),
    );
    if (count == 0) {
      await db.insert(
        DatabaseTables.suppliers,
        KissanFeedsData.defaultSupplier.toMap(),
      );
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
