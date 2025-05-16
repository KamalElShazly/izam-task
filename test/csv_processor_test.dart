import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:izam_mobile_team_task_may_25/csv_handler.dart';
import 'package:izam_mobile_team_task_may_25/database_service.dart';
import 'package:izam_mobile_team_task_may_25/inventory_bloc.dart';
import 'package:izam_mobile_team_task_may_25/inventory_event.dart';
import 'package:izam_mobile_team_task_may_25/inventory_repository.dart';
import 'package:izam_mobile_team_task_may_25/log_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late InventoryDatabase database;
  late InventoryRepository repository;
  late InventoryBloc bloc;
  late LogHelper logHelper;

  setUp(() async {
    databaseFactoryOrNull = null;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    database = InventoryDatabase.inMemory();
    repository = InventoryRepository(database);
    bloc = InventoryBloc(repository);
    logHelper = LogHelper('log.txt');
  });

  tearDown(() async {
    await database.close();
    await logHelper.close();
  });

  test('CSV Processor', () async {
    const filePath = 'assets/inventory_35000_records.csv';
    const batchSize = 1000;
    final receivePort = ReceivePort();

    final Completer<void> completer = Completer<void>();
    int succeeded = 0;

    // Start isolate
    await Isolate.spawn(
        parseCSV,
        CSVProcessorInput(
          filePath: filePath,
          batchSize: batchSize,
          sendPort: receivePort.sendPort,
        ));

    // Listen for messages
    receivePort.listen((message) async {
      if (message is CSVProcessorMessage) {
        switch (message) {
          case CSVProcessorAddItemMessage():
            bloc.sink.add(AddInventoryItem(message.item));
          case CSVProcessorUpdateUIMessage():
            print('Processed ${message.numberOfLines} lines.');
          case CSVProcessorSummaryMessage():
            succeeded = message.succeeded;
            print(
                'Proccessed: ${message.processed}, Succeeded: ${message.succeeded}, Failed: ${message.failed}, Duration: ${message.duration} ms');
            for (CSVRowError error in message.errors) {
              switch (error) {
                case CSVValidationError():
                  await logHelper.log('Error in line ${error.lineNumber} :: ${error.line} :: ${error.errors.join(', ')}');
                // print('Error in line ${error.lineNumber} :: ${error.line} :: ${error.errors.join(', ')}');
                case CSVExceptionError():
                  await logHelper.log('Error in line ${error.lineNumber} :: ${error.line} :: ${error.exception}');
                // print('Error in line ${error.lineNumber} :: ${error.line} :: ${error.exception}');
              }
            }
            print('CSV parsing completed.');
            receivePort.close();
            completer.complete();
        }
      }
    });

    await completer.future;

    // wait for debounce
    await Future.delayed(const Duration(milliseconds: 500));
    // wait for batching
    await Future.delayed(const Duration(seconds: 2));
    // wait to make sure events are emitted
    await Future.delayed(const Duration(milliseconds: 200));

    final count = await repository.getTableCount();
    expect(count, succeeded);
  });
}
