import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fertilizer/core/database/database_helper.dart';
import 'package:fertilizer/core/database/database_tables.dart';
import 'package:fertilizer/core/models/storage.dart';
import 'package:fertilizer/core/repositories/storage_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late StorageRepository storageRepo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.setMockDatabase(db);

    for (final q in DatabaseTables.createTableQueries) {
      await db.execute(q);
    }
    for (final idx in DatabaseTables.createIndexQueries) {
      await db.execute(idx);
    }

    await DatabaseHelper.seedDefaultSettings(db);
    await DatabaseHelper.seedDefaultProducts(db);
    await DatabaseHelper.seedDefaultSuppliers(db);
    await DatabaseHelper.ensureStorageTables(db);

    storageRepo = StorageRepository(DatabaseHelper.instance);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('Storage & Godown Module Tests', () {
    test('Default storages are seeded automatically on init', () async {
      final storages = await storageRepo.getStorages();
      expect(storages.length, greaterThanOrEqualTo(3));

      final defaultStorage = await storageRepo.getDefaultStorage();
      expect(defaultStorage, isNotNull);
      expect(defaultStorage!.isDefault, isTrue);
      expect(defaultStorage.name, contains('Shop'));
    });

    test('Adding a new storage persists correctly with product zero-stock initialization', () async {
      final now = DateTime.now().toIso8601String();
      final newStorage = Storage(
        name: 'Depot Warehouse 3 (نیا گودام)',
        code: 'DEPOT-03',
        location: 'Railway Colony',
        inchargeName: 'Kashif Ali',
        contactNumber: '0300-9988776',
        capacityBags: 8000,
        createdAt: now,
        updatedAt: now,
      );

      final id = await storageRepo.insertStorage(newStorage);
      expect(id, greaterThan(0));

      final fetched = await storageRepo.getStorageById(id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Depot Warehouse 3 (نیا گودام)');
      expect(fetched.capacityBags, 8000);

      // Verify stocks initialized for products
      final stocks = await storageRepo.getStorageStocks(id);
      expect(stocks.isNotEmpty, isTrue);
      expect(stocks.first.quantity, 0.0);
    });

    test('Stock transfer moves quantity from source to destination storage', () async {
      final storages = await storageRepo.getStorages();
      final source = storages[0]; // Shop Floor
      final dest = storages[1];   // Main Godown

      final sourceStocks = await storageRepo.getStorageStocks(source.id!);
      final productToTransfer = sourceStocks.firstWhere((s) => s.quantity > 0);

      final initialSourceQty = productToTransfer.quantity;
      const transferQty = 15.0;
      expect(initialSourceQty, greaterThanOrEqualTo(transferQty));

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final transferId = await storageRepo.transferStock(
        fromStorageId: source.id!,
        toStorageId: dest.id!,
        productId: productToTransfer.productId,
        quantity: transferQty,
        transferDate: today,
        vehicleNumber: 'LHR-5678',
        driverName: 'Rafiq Shah',
        notes: 'Replenishing Main Godown stock',
      );

      expect(transferId, greaterThan(0));

      // Verify source deducted
      final updatedSourceStocks = await storageRepo.getStorageStocks(source.id!);
      final updatedSourceProd = updatedSourceStocks.firstWhere((s) => s.productId == productToTransfer.productId);
      expect(updatedSourceProd.quantity, initialSourceQty - transferQty);

      // Verify destination credited
      final updatedDestStocks = await storageRepo.getStorageStocks(dest.id!);
      final updatedDestProd = updatedDestStocks.firstWhere((s) => s.productId == productToTransfer.productId);
      expect(updatedDestProd.quantity, transferQty);

      // Verify transfer log
      final transfers = await storageRepo.getStockTransfers();
      expect(transfers.any((t) => t.id == transferId), isTrue);
      final transferLog = transfers.firstWhere((t) => t.id == transferId);
      expect(transferLog.vehicleNumber, 'LHR-5678');
      expect(transferLog.driverName, 'Rafiq Shah');
      expect(transferLog.quantity, transferQty);
    });

    test('Stock transfer prevents transferring more than available stock', () async {
      final storages = await storageRepo.getStorages();
      final source = storages[0];
      final dest = storages[1];

      final sourceStocks = await storageRepo.getStorageStocks(source.id!);
      final product = sourceStocks.firstWhere((s) => s.quantity > 0);
      final excessQuantity = product.quantity + 9999.0;

      final today = DateTime.now().toIso8601String().substring(0, 10);
      expect(
        () async => await storageRepo.transferStock(
          fromStorageId: source.id!,
          toStorageId: dest.id!,
          productId: product.productId,
          quantity: excessQuantity,
          transferDate: today,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Stock transfer prevents identical source and destination storage', () async {
      final storages = await storageRepo.getStorages();
      final source = storages[0];

      final today = DateTime.now().toIso8601String().substring(0, 10);
      expect(
        () async => await storageRepo.transferStock(
          fromStorageId: source.id!,
          toStorageId: source.id!,
          productId: 1,
          quantity: 10,
          transferDate: today,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
