abstract class InventoryState {}

class InventoryIdle extends InventoryState {}

class InventorySaving extends InventoryState {}

class InventorySaved extends InventoryState {}

class InventorySaveError extends InventoryState {
  final Object error;
  InventorySaveError(this.error);
}
