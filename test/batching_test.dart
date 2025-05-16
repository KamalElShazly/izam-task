import 'package:flutter_test/flutter_test.dart';
import 'package:izam_mobile_team_task_may_25/database_service.dart';
import 'package:izam_mobile_team_task_may_25/inventory_bloc.dart';
import 'package:izam_mobile_team_task_may_25/inventory_event.dart';
import 'package:izam_mobile_team_task_may_25/invertory_repository.dart';
import 'package:izam_mobile_team_task_may_25/item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late InventoryDatabase database;
  late InventoryRepository repository;
  late InventoryBloc bloc;

  setUp(() async {
    databaseFactoryOrNull = null;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    database = InventoryDatabase.inMemory();
    repository = InventoryRepository(database);
    bloc = InventoryBloc(repository);
  });

  tearDown(() async {
    await database.close();
    bloc.dispose();
  });

  test('Test batching after 2 seconds', () async {
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 10, lastUpdated: DateTime.now())));
    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    bloc.sink.add(AddInventoryItem(Item(id: 2, name: 'Item 2', qty: 20, lastUpdated: DateTime.now())));
    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));

    List<Item> results;

    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 0);

    // wait for batching
    await Future.delayed(const Duration(seconds: 2));
    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 2);
  });

  test('Test batching after 10 entries', () async {
    for (int i = 0; i < 10; i++) {
      final index = i + 1;
      bloc.sink.add(AddInventoryItem(Item(id: index, name: 'Item $index', qty: index * 10, lastUpdated: DateTime.now())));
      // wait for debounce
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    final results = await repository.getPaginatedProducts(pageSize: 20);
    expect(results.length, 10);
  });

  test('Test batching after 10 entries or 2 seconds', () async {
    for (int i = 0; i < 15; i++) {
      final index = i + 1;
      bloc.sink.add(AddInventoryItem(Item(id: index, name: 'Item $index', qty: index * 10, lastUpdated: DateTime.now())));
      // wait for debounce
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    List<Item> results;

    results = await repository.getPaginatedProducts(pageSize: 20);
    expect(results.length, 10);

    // wait to make sure events are emitted
    await Future.delayed(const Duration(seconds: 2));

    results = await repository.getPaginatedProducts(pageSize: 20);
    expect(results.length, 15);
  });
}
