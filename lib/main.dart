import 'dart:io';
import 'dart:math';
import 'package:faker/faker.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;

void main() async {
  const recordCount = 35000; // Set between 25k-50k
  const errorRate = 0.00; // 0% invalid records

  final faker = Faker();
  final random = Random();
  final date = DateTime.now();

  List<List<dynamic>> csvData = [[
    'id',
    'name',
    'qty',
    'price',
    'category',
    'last_updated'
  ]];

  for (int i = 1; i <= recordCount; i++) {
    // Introduce errors
    final injectError = random.nextDouble() < errorRate;

    csvData.add([
      i,
      _generateItemName(faker, injectError),
      _generateQuantity(random, injectError),
      _generatePrice(random, injectError),
      _generateCategory(faker, injectError),
      _generateTimestamp(date, i, random)
    ]);
  }

  final csv = const ListToCsvConverter().convert(csvData);
  final dir = Directory.current.path;
  final filePath = path.join(dir, 'inventory_${recordCount}_records.csv');

  await File(filePath).writeAsString(csv);
  print('Generated $filePath with ${recordCount} records');


}

String _generateItemName(Faker faker, bool injectError) {
  if (injectError && Random().nextBool()) {
    // Generate problematic names
    return Random().nextBool()
        ? 'Item,With,Commas'
        : 'L"quoted"Item';
  }
  return '${faker.food.dish()} v${Random().nextInt(100)}';
}

dynamic _generateQuantity(Random random, bool injectError) {
  if (injectError) {
    return Random().nextBool() ? -1 : null;
  }
  return random.nextInt(1000); // 0-1000
}

dynamic _generatePrice(Random random, bool injectError) {
  if (injectError && Random().nextDouble() > 0.7) return 'invalid_price';
  return (random.nextDouble() * 1000).toStringAsFixed(2);
}

String _generateCategory(Faker faker, bool injectError) {
  if (injectError && Random().nextDouble() > 0.5) return '';
  return faker.lorem.word();
}

String _generateTimestamp(DateTime baseDate, int index, Random random) {
  final variation = index * random.nextInt(10);
  return baseDate.subtract(Duration(minutes: variation)).toIso8601String();
}