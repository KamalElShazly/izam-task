import 'package:flutter_test/flutter_test.dart';
import 'package:izam_mobile_team_task_may_25/csv_loader.dart';
import 'package:izam_mobile_team_task_may_25/database_service.dart';
import 'package:izam_mobile_team_task_may_25/invertory_repository.dart';
import 'package:izam_mobile_team_task_may_25/item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

@TestOn('csv')
void main() {
  late InventoryDatabase database;
  late InventoryRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    database = InventoryDatabase.inMemory();
    repository = InventoryRepository(database);
    await database.database;
  });

  tearDown(() async {
    await database.close();
  });

  test('Read csv file and insert into database', () async {
    final csvItemsMap = await loadCsvData('assets/inventory_35000_records.csv');

    await repository.bulkUpdate(List<Item>.generate(csvItemsMap.length, (index) => Item.fromMap(csvItemsMap[index], index: index),));
    final results = await repository.getPaginatedProducts(pageSize: 35000);

    expect(results.length, 35000); // it should fail because some quantities are not valid, and the test won't reach this line.
  }, tags: 'csv');

  test('Insert and retrieve item with category', () async {
    final item = Item(
      id: 1,
      name: 'Widget Pro',
      qty: 100,
      lastUpdated: DateTime.now(),
      category: 'electronics',
    );

    await repository.bulkUpdate([item]);
    final results = await repository.getPaginatedProducts(pageSize: 10);

    expect(results.length, 1);
    expect(results.first.category, 'electronics');
  });

  test('Category-based conflict resolution', () async {
    final oldItem = Item(
      id: 1,
      name: 'Old Item',
      qty: 10,
      lastUpdated: DateTime.now().subtract(Duration(days: 1)),
      category: 'old_category',
    );

    final newItem = Item(
      id: 1,
      name: 'New Item',
      qty: 20,
      lastUpdated: DateTime.now(),
      category: 'new_category',
    );

    await repository.bulkUpdate([oldItem]);
    await repository.bulkUpdate([newItem]);

    final result = await repository.getItem(1);
    expect(result.category, 'new_category');
  });

  test('Full-text search by category', () async {
    await repository.bulkUpdate([
      Item(id: 50000,
          name: 'Phone',
          category: 'electronics',
          qty: 2,
          lastUpdated: DateTime.now()),
      Item(id: 50001,
          name: 'Chair',
          category: 'furniture',
          qty: 2,
          lastUpdated: DateTime.now()),
    ]);

    final results = await repository.searchInventory('category:electronics');
    expect(results.length, 1);
    expect(results.first.name, 'Phone');
  });

  // test('Category persists through migrations', () async {
  //   // Initial version
  //   await database.database;
  //   await repository.bulkUpdate([
  //     Item(id: 50002,
  //         name: 'Test',
  //         category: 'legacy',
  //         qty: 2,
  //         lastUpdated: DateTime.now()),
  //   ]);
  //
  //   // Simulate migration
  //   await database.migrateV1ToV2(await database.database);
  //
  //   final migratedItem = await repository.getItem(1);
  //   expect(migratedItem.category, 'legacy');
  // });

  test('Category default value handling', () async {
    await repository.bulkUpdate([
      Item(id: 50003, name: 'No Category', qty: 2, lastUpdated: DateTime.now()),
    ]);

    final result = await repository.getItem(1);
    expect(result.category, null);
  });

  test('Item not found throws error', () async {
    expect(() async => await repository.getItem(999), throwsA(isA<Exception>()));
  });

  test('Database closes properly', () async {
    await database.close();
    expect(database.databaseRef, isNull);
  });
}