import 'dart:async';
import 'dart:math';

import 'package:izam_mobile_team_task_may_25/inventory_event.dart';
import 'package:izam_mobile_team_task_may_25/inventory_state.dart';
import 'package:izam_mobile_team_task_may_25/inventory_repository.dart';
import 'package:izam_mobile_team_task_may_25/item.dart';

class InventoryBloc {
  final _eventController = StreamController<InventoryEvent>();
  final _stateController = StreamController<InventoryState>.broadcast();
  late StreamSubscription<InventoryState> _subscription;

  final InventoryRepository repository;

  Stream<InventoryState> get stream => _stateController.stream;
  Sink<InventoryEvent> get sink => _eventController.sink;

  InventoryBloc(this.repository) {
    _subscription = _eventController.stream
        .where((event) => event is AddInventoryItem)
        .map((event) => (event as AddInventoryItem).item)
        .transform(_debounce(const Duration(milliseconds: 500)))
        .where((item) => item.qty >= 0 && item.qty <= 1000)
        .transform(_batch(10, const Duration(seconds: 2)))
        .asyncExpand(_handleUpdate)
        .listen(_handleState);
  }

  // Implement transformers:
  /// 1. Debounce rapid updates: 500ms cooldown per item
  /// 2. Validate quantities: 0 ≤ qty ≤ 1000, reject others
  /// 3. Batch SQLite writes: Every 10 valid updates or 2s idle
  /// 4. Recovery: Retry failed writes 3x with exponential backoff
  /// 5. Concurrency: Handle simultaneous updates to same item

  StreamTransformer<Item, Item> _debounce(Duration duration) {
    return StreamTransformer<Item, Item>.fromBind((input) {
      late StreamController<Item> controller;
      final timers = <int, Timer>{};
      final latestItems = <int, Item>{};
      late StreamSubscription<Item> subscription;

      controller = StreamController<Item>(
        onListen: () {
          subscription = input.listen(
            (item) {
              final key = item.id;
              latestItems[key] = item;

              timers[key]?.cancel();
              timers[key] = Timer(duration, () {
                final item = latestItems.remove(key);
                if (item != null) {
                  controller.add(item);
                }
                timers.remove(key);
              });
            },
            onError: controller.addError,
            onDone: () {
              for (Timer timer in timers.values) {
                timer.cancel();
              }
              timers.clear();
              controller.close();
            },
            cancelOnError: false,
          );
        },
        onCancel: () {
          subscription.cancel();
          for (Timer timer in timers.values) {
            timer.cancel();
          }
          timers.clear();
          controller.close();
        },
      );

      return controller.stream;
    });
  }

  // StreamTransformer<Item, Item> _validate() {
  //   return StreamTransformer.fromHandlers(
  //     handleData: (item, sink) {
  //       if (item.qty >= 0 && item.qty <= 1000) {
  //         sink.add(item);
  //       }
  //     },
  //   );
  // }

  StreamTransformer<Item, List<Item>> _batch(int maxCount, Duration maxDuration) {
    return StreamTransformer<Item, List<Item>>.fromBind((input) {
      late StreamController<List<Item>> controller;
      List<Item> buffer = [];
      Timer? timer;
      late StreamSubscription<Item> subscription;

      void forwardData() {
        if (buffer.isNotEmpty) {
          controller.add(List.unmodifiable(buffer));
          buffer.clear();
        }

        timer?.cancel();
        timer = null;
      }

      controller = StreamController<List<Item>>(
        onListen: () {
          subscription = input.listen(
            (item) {
              buffer.add(item);

              timer?.cancel();
              timer = Timer(maxDuration, () {
                forwardData();
              });

              if (buffer.length >= maxCount) {
                forwardData();
              }
            },
            onError: controller.addError,
            onDone: () {
              forwardData();
              timer?.cancel();
              controller.close();
            },
            cancelOnError: false,
          );
        },
        onCancel: () {
          subscription.cancel();
          timer?.cancel();
        },
      );

      return controller.stream;
    });
  }

  Stream<InventoryState> _handleUpdate(List<Item> items) async* {
    yield InventorySaving();

    try {
      await retry(
          maxAttempts: 3,
          action: () async {
            await repository.bulkUpdate(items);
          });
      yield InventorySaved();
    } catch (e) {
      yield InventorySaveError(e);
    } finally {
      yield InventoryIdle();
    }
  }

  Future<void> retry({int maxAttempts = 3, required Future<void> Function() action}) async {
    for (int attempt = 0; attempt <= maxAttempts; attempt++) {
      try {
        await action();
        return;
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delay = const Duration(seconds: 1) * pow(2, attempt);
        print('Retry #${attempt + 1} after ${delay.inSeconds}s due to error: $e');
        await Future.delayed(delay);
      }
    }
  }

  void _handleState(InventoryState state) {
    _stateController.add(state);
  }

  void dispose() {
    _subscription.cancel();
    _eventController.close();
    _stateController.close();
  }
}
