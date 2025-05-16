import 'package:flutter_test/flutter_test.dart';
import 'package:izam_mobile_team_task_may_25/database_service.dart';
import 'package:izam_mobile_team_task_may_25/inventory_bloc.dart';
import 'package:izam_mobile_team_task_may_25/inventory_event.dart';
import 'package:izam_mobile_team_task_may_25/invertory_repository.dart';
import 'package:izam_mobile_team_task_may_25/item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeInventoryRepository extends InventoryRepository {
  FakeInventoryRepository(super.database);

  int numberOfFailures = 0;

  @override
  Future<void> bulkUpdate(List<Item> items) {
    if (numberOfFailures > 0) {
      numberOfFailures--;
      throw Exception('Simulated Error');
    } else {
      return super.bulkUpdate(items);
    }
  }
}

void main() {
  late InventoryDatabase database;
  late FakeInventoryRepository repository;
  late InventoryBloc bloc;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    database = InventoryDatabase.inMemory();
    repository = FakeInventoryRepository(database);
    bloc = InventoryBloc(repository);
  });

  tearDown(() async {
    await database.close();
    bloc.dispose();
  });

  test('Test recovery after 1 failure', () async {
    repository.numberOfFailures = 1;

    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 10, lastUpdated: DateTime.now())));
    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    // wait for batching
    await Future.delayed(const Duration(seconds: 2));
    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    List<Item> results;
    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 0);

    await Future.delayed(const Duration(seconds: 1));

    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 1);
  });

  test('Test recovery after 2 failures', () async {
    repository.numberOfFailures = 2;

    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 10, lastUpdated: DateTime.now())));
    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    // wait for batching
    await Future.delayed(const Duration(seconds: 2));
    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    List<Item> results;
    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 0);

    await Future.delayed(const Duration(seconds: 1));

    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 0);

    await Future.delayed(const Duration(seconds: 2));

    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 1);
  });

  test('Test recovery after 3 failures', () async {
    repository.numberOfFailures = 3;

    bloc.sink.add(AddInventoryItem(Item(id: 1, name: 'Item 1', qty: 10, lastUpdated: DateTime.now())));
    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    // wait for batching
    await Future.delayed(const Duration(seconds: 2));
    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    List<Item> results;
    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 0);

    await Future.delayed(const Duration(seconds: 1));

    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 0);

    await Future.delayed(const Duration(seconds: 2));

    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 0);

    await Future.delayed(const Duration(seconds: 4));

    results = await repository.getPaginatedProducts(pageSize: 10);
    expect(results.length, 1);
  });
}
