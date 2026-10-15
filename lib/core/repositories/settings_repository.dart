import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/business_settings.dart';

class SettingsRepository {
  final DatabaseHelper _dbHelper;
  SettingsRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<BusinessSettings> getSettings() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.businessSettings,
      where: 'id = 1',
    );
    if (maps.isEmpty) {
      final now = DateTime.now().toIso8601String();
      final defaultSettings = BusinessSettings(
        id: 1,
        businessName: 'Sheikh Uzair & Co - Fertilizer',
        ownerName: 'Sheikh Uzair',
        phone: '+92 3498460039',
        address: 'Grain Market / Fertilizer Hub',
        city: 'Punjab, Pakistan',
        ntnStrn: '1234567-8',
        updatedAt: now,
      );
      await db.insert(DatabaseTables.businessSettings, defaultSettings.toMap());
      return defaultSettings;
    }
    final existing = BusinessSettings.fromMap(maps.first);
    if (existing.phone == '0300-1234567' || existing.phone.trim().isEmpty) {
      final updated = existing.copyWith(phone: '+92 3498460039');
      await updateSettings(updated);
      return updated;
    }
    return existing;
  }

  Future<void> updateSettings(BusinessSettings settings) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final map = settings.copyWith(updatedAt: now).toMap();
    await db.update(DatabaseTables.businessSettings, map, where: 'id = 1');
  }

  Future<bool> verifyPin(String enteredPin) async {
    final settings = await getSettings();
    if (!settings.isPinEnabled) return true;
    return settings.pinCode == enteredPin;
  }
}
