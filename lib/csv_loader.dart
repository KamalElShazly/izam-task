import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

Future<List<Map<String, dynamic>>> loadCsvData(String path) async {
  final file = File(path);
  if (!await file.exists()) throw Exception('CSV file not found at $path');

  return file
      .openRead()
      .transform(utf8.decoder)
      .transform(const CsvToListConverter())
      .skip(1) // Skip header row
      .map((row) => {
    'id': row[0],
    'name': row[1].toString(),
    'qty': row[2],
    'price': row[3],
    'category': row[4].toString(),
    'last_updated': row[5].toString(),
    // Add other columns
  })
      .toList();
}