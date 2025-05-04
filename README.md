# izam_mobile_team_task_may_25

A new Flutter project.

## Getting Started

Task: Offline Inventory Sync Engine
(Simulates bulk data processing with fault tolerance)
No UI handling required, you can do all your work validation in unit tests.

1. Custom Stream-Based BLoC (Mandatory)
   Problem: Create InventoryBloc using raw streams (no packages) that:

- Validates input quantities (≥0, ≤1000)
- Debounces rapid quantity updates (500ms)
- Batches SQLite writes every 10 items
- Handles concurrent update conflicts

your answer could follow the following code snippet, but it is not mandatory:

// Skeleton
class InventoryBloc {
final _inputController = StreamController<InventoryEvent>();
late final Stream<InventoryState> _state;

InventoryBloc() {
_state = _inputController.stream
.transform(_debounce())
.transform(_validate())
.asyncExpand(_handleUpdate);
}

// Implement transformers:
/// 1. Debounce rapid updates: 500ms cooldown per item
/// 2. Validate quantities: 0 ≤ qty ≤ 1000, reject others
/// 3. Batch SQLite writes: Every 10 valid updates or 2s idle
/// 4. Recovery: Retry failed writes 3x with exponential backoff
/// 5. Concurrency: Handle simultaneous updates to same item
}


2. Isolate CSV Processor (Mandatory)
   We have a csv file with 35000 records, which has about 1% errornious records that must be handled as well.

Requirements:

- Parse in isolate with progress reports
- Use Completer for DB initialization
- Queue valid items for BLoC
- Collect errors with original line numbers
  To Identify errors, please refer to this csv file: assets/inventory_35000_records.csv
- Required Error Handling:

1,"Item A",100,12.50     // Valid
2,"Item,B",,45.00        // Comma in quoted name + missing qty
3,"Item C",-5,           // Negative qty + missing price
4,"Item D",2000,invalid  // Qty overflow + price type error

your answer could follow the following code snippet, but it is not mandatory:

// Isolate setup
void parseCSVIsolate(SendPort sendPort) {
final completer = Completer<Database>();
// Implement:
// 1. DB initialization with completer
// 2. Line-by-line parsing
// 3. Progress streaming
// 4. Error recovery
}


3. Use the SQLite Database service provided in the git repo, 
   and you can do all unit tests you want to ensure its validity,
   or even regenerate the inventory_35000_records.csv file by running "dart run .\lib\main.dart" command 
   in the project terminal with different errorRate, to test the database behaviour. (Optional)
