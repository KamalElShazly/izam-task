// database_service.dart
import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class InventoryDatabase {
  static const _databaseName = "inventory.db";
  static const _databaseVersion = 2;

  // Add inMemory constructor
  factory InventoryDatabase.inMemory() {
    return InventoryDatabase._init(inMemory: true);
  }

  static final InventoryDatabase instance = InventoryDatabase._init();
  Database? _database;
  Database? get databaseRef => _database;
  final bool _inMemory;
  final Completer<Database> _completer = Completer<Database>();

  InventoryDatabase._init({bool inMemory = false}) : _inMemory = inMemory {
    _initialize();
  }

  Future<Database> get database async {
    return _completer.future;
    // return _database ??= await _initDatabase();
  }

  Future<void> _initialize() async {
    _database = await _initDatabase();
    _completer.complete(_database);
  }

  Future<Database> _initDatabase() async {
    final dbPath = _inMemory ? ':memory:' : await getDatabasesPath();
    final path = _inMemory ? ':memory:' : join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        qty INTEGER NOT NULL CHECK(qty BETWEEN 0 AND 1000),
        last_updated INTEGER NOT NULL,
        category TEXT DEFAULT NULL
      )
    ''');

    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS inventory_fts USING fts5(
        id UNINDEXED,
        name,
        category,
        content='inventory',
        tokenize='porter unicode61'
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_inventory_quickaccess 
      ON inventory(qty, last_updated, category)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await migrateV1ToV2(db);
    }
  }

  Future<void> migrateV1ToV2(Database db) async {
    await db.execute('''
        CREATE TABLE inventory_new (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          qty INTEGER NOT NULL CHECK(qty BETWEEN 0 AND 1000),
          last_updated INTEGER NOT NULL,
          category TEXT DEFAULT NULL
        )
      ''');

    await db.execute('''
        INSERT INTO inventory_new (id, name, qty, last_updated)
        SELECT id, name, qty, last_updated FROM inventory
      ''');

    await db.execute('DROP TABLE inventory');
    await db.execute('ALTER TABLE inventory_new RENAME TO inventory');

    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS inventory_fts fts5(
        id UNINDEXED,
        name,
        category,
        content='inventory',
        tokenize='porter unicode61'
      )
    ''');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  int? firstIntValue(List<Map<String, Object?>> list) {
    return Sqflite.firstIntValue(list);
  }
}
