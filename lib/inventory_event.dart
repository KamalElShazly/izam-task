import 'package:izam_mobile_team_task_may_25/item.dart';

sealed class InventoryEvent {}

class AddInventoryItem extends InventoryEvent {
  final Item item;

  AddInventoryItem(this.item);
}
