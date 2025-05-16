import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:izam_mobile_team_task_may_25/item.dart';

class CSVProcessorInput {
  final String filePath;
  final int batchSize;
  final SendPort sendPort;

  CSVProcessorInput({
    required this.filePath,
    required this.batchSize,
    required this.sendPort,
  });
}

sealed class CSVProcessorMessage {}

class CSVProcessorAddItemMessage extends CSVProcessorMessage {
  final Item item;

  CSVProcessorAddItemMessage(this.item);
}

class CSVProcessorUpdateUIMessage extends CSVProcessorMessage {
  final int numberOfLines;

  CSVProcessorUpdateUIMessage(this.numberOfLines);
}

class CSVProcessorSummaryMessage extends CSVProcessorMessage {
  final int processed;
  final int succeeded;
  final int failed;
  final int duration;
  final List<CSVRowError> errors;

  CSVProcessorSummaryMessage({
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.duration,
    required this.errors,
  });
}

sealed class CSVRowError {
  final int lineNumber;
  final String line;

  CSVRowError(this.lineNumber, this.line);
}

class CSVValidationError extends CSVRowError {
  final List<String> errors;

  CSVValidationError(super.lineNumber, super.line, this.errors);
}

class CSVExceptionError extends CSVRowError {
  final Object exception;

  CSVExceptionError(super.lineNumber, super.line, this.exception);
}

void parseCSV(CSVProcessorInput msg) async {
  final stopwatch = Stopwatch()..start();

  final file = File(msg.filePath);
  final lines = file.openRead().transform(utf8.decoder).transform(const LineSplitter()).skip(1);
  const converter = CsvToListConverter();

  int processed = 0;
  int succeeded = 0;
  int failed = 0;
  final List<CSVRowError> errors = [];

  await for (final line in lines) {
    processed++;

    try {
      final row = converter.convert(line).first;

      final rowErrors = _validateRow(row);
      if (rowErrors.isEmpty) {
        succeeded++;

        final item = {
          'id': row[0],
          'name': row[1].toString(),
          'qty': row[2],
          'price': row[3],
          'category': row[4].toString(),
          'last_updated': row[5].toString(),
        };
        final finalItem = Item.fromMap(item);
        msg.sendPort.send(CSVProcessorAddItemMessage(finalItem));
        if (processed % msg.batchSize == 0) {
          msg.sendPort.send(CSVProcessorUpdateUIMessage(processed));
        }
      } else {
        failed++;
        errors.add(CSVValidationError(processed, line, rowErrors));
      }
    } catch (e) {
      failed++;
      errors.add(CSVExceptionError(processed, line, e));
    }
  }

  msg.sendPort.send(CSVProcessorSummaryMessage(
    processed: processed,
    succeeded: succeeded,
    failed: failed,
    duration: stopwatch.elapsedMilliseconds,
    errors: errors,
  ));
}

List<String> _validateRow(List<dynamic> row) {
  final id = row[0];
  final name = row[1];
  final qty = row[2];
  final price = row[3];
  final category = row[4];
  final lastUpdated = row[5];

  List<String> errors = [];

  if (id == null) {
    errors.add('Id missing');
  } else if (id is! int) {
    errors.add('Id type error');
  }

  if (name == null || name.isEmpty) {
    errors.add('Name missing');
  } else if (name is! String) {
    errors.add('Name type error');
  }

  if (qty == null) {
    errors.add('Qty missing');
  } else if (qty is! int) {
    errors.add('Qty type error');
  } else if (qty < 0) {
    errors.add('Qty negative');
  } else if (qty > 1000) {
    errors.add('Qty overflow');
  }

  if (price == null) {
    errors.add('Price missing');
  } else if (price is! num) {
    errors.add('Price type error');
  }

  if (category == null || category.isEmpty) {
    errors.add('Category missing');
  } else if (category is! String) {
    errors.add('Category type error');
  }

  if (lastUpdated == null || lastUpdated.isEmpty) {
    errors.add('LastUpdated missing');
  } else if (lastUpdated is! String) {
    errors.add('LastUpdated type error');
  } else if (DateTime.tryParse(lastUpdated) == null) {
    errors.add('LastUpdated not valid format');
  }

  return errors;
}
