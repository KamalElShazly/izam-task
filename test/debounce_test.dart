import 'package:flutter_test/flutter_test.dart';
import 'package:izam_mobile_team_task_may_25/database_service.dart';
import 'package:izam_mobile_team_task_may_25/inventory_bloc.dart';
import 'package:izam_mobile_team_task_may_25/inventory_event.dart';
import 'package:izam_mobile_team_task_may_25/inventory_repository.dart';
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

  test('Test debounce with multiple different items incoming fast (< 500ms)', () async {
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 10, lastUpdated: DateTime.now())));
    bloc.sink.add(AddInventoryItem(Item(id: 2, name: 'Item 2', qty: 20, lastUpdated: DateTime.now())));
    bloc.sink.add(AddInventoryItem(Item(id: 3, name: 'Item 3', qty: 30, lastUpdated: DateTime.now())));
    bloc.sink.add(AddInventoryItem(Item(id: 4, name: 'Item 4', qty: 40, lastUpdated: DateTime.now())));

    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    // wait for batching
    await Future.delayed(const Duration(seconds: 2));
    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    final results = await repository.getPaginatedProducts(pageSize: 20);
    expect(results.length, 4);
  });

  test('Test debounce with multiple same items incoming fast (< 500ms)', () async {
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 10, lastUpdated: DateTime.now())));
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 20, lastUpdated: DateTime.now())));
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 30, lastUpdated: DateTime.now())));
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 40, lastUpdated: DateTime.now())));

    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    // wait for batching
    await Future.delayed(const Duration(seconds: 2));
    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    final results = await repository.getPaginatedProducts(pageSize: 20);
    expect(results.length, 1);
  });

  test('Test debounce with multiple same items incoming slow (> 500ms)', () async {
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 10, lastUpdated: DateTime.now())));
    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 20, lastUpdated: DateTime.now())));
    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 30, lastUpdated: DateTime.now())));
    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));

    // wait for batching
    await Future.delayed(const Duration(seconds: 2));
    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    final results = await repository.getPaginatedProducts(pageSize: 20);
    expect(results.length, 1);
  });
}
