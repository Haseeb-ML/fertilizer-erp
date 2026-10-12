import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fertilizer/core/database/database_helper.dart';
import 'package:fertilizer/core/database/database_tables.dart';

class TestHelper {
  static bool _initialized = false;

  static Future<Database> createInMemoryDatabase() async {
    if (!_initialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _initialized = true;
    }

    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
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

          final now = DateTime.now().toIso8601String();
          await db.insert(DatabaseTables.businessSettings, {
            'id': 1,
            'business_name': 'Test Fertilizer Agency',
            'owner_name': 'Test Owner',
            'phone': '0300-1111111',
            'address': 'Test Market',
            'city': 'Multan',
            'ntn_strn': '1234567',
            'invoice_prefix': 'INV-',
            'purchase_prefix': 'PUR-',
            'currency_symbol': '₨',
            'pin_code': '',
            'is_pin_enabled': 0,
            'initial_cash_balance': 0.0,
            'updated_at': now,
          });
        },
      ),
    );

    DatabaseHelper.setMockDatabase(db);
    return db;
  }
}
