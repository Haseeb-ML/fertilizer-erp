import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
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

    return await openDatabase(
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
      },
    );
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
        'business_name': 'Sheikh Uzair & Co - Fertilizer',
        'owner_name': 'Sheikh Uzair',
        'phone': '0300-1234567',
        'address': 'Grain Market / Fertilizer Hub',
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
