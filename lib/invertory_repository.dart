import 'database_service.dart';
import 'item.dart';

class InventoryRepository {
  final InventoryDatabase _database;

  InventoryRepository(this._database);

  Future<void> bulkUpdate(List<Item> items) async {
    final db = await _database.database;
    final batch = db.batch();

    for (final item in items) {
      batch.execute(
        '''
        INSERT INTO inventory(id, name, qty, last_updated, category)
        VALUES(?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
          qty = excluded.qty,
          last_updated = excluded.last_updated,
          category = excluded.category
        WHERE excluded.last_updated > inventory.last_updated
        ''',
        [item.id, item.name, item.qty, item.lastUpdated.toString(), item.category],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<Item> getItem(int itemId) async {
    final db = await _database.database;
    final results = await db.query(
      'inventory',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );

    if (results.isEmpty) {
      throw Exception('Item not found');
    }

    return Item.fromMap(results.first);
  }

  Future<List<Item>> getPaginatedProducts({
    required int pageSize,
    int? lastItemId,
  }) async {
    final db = await _database.database;

    final results = await db.query(
      'inventory',
      where: lastItemId != null ? 'id > ?' : null,
      whereArgs: lastItemId != null ? [lastItemId] : null,
      orderBy: 'id ASC',
      limit: pageSize,
    );

    return results.map((json) => Item.fromMap(json)).toList();
  }

  Future<List<Item>> searchInventory(String query) async {
    final db = await _database.database;

    final results = await db.rawQuery('''
      SELECT id AS item_id, name, category 
      FROM inventory_fts
      WHERE name MATCH ?
      ORDER BY rank
      LIMIT 50
    ''', [query]);

    return results.map((json) => Item.fromMap(json)).toList();
  }
}
