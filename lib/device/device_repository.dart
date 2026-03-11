import 'package:calendar_app/device/device.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 디바이스 로컬 저장 (SQLite)
class DeviceRepository {
  DeviceRepository._();
  static final DeviceRepository instance = DeviceRepository._();

  static const _table = 'devices';
  static const _dbName = 'devices.db';
  static const _version = 1;

  Database? _db;

  Future<Database> _getDb() async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), _dbName),
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            createdAtMillis INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Device _rowToDevice(Map<String, Object?> row) {
    return Device(
      id: row['id'] as int?,
      name: row['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAtMillis'] as int),
    );
  }

  Future<List<Device>> getAll() async {
    final db = await _getDb();
    final rows = await db.query(_table, orderBy: 'createdAtMillis DESC');
    return rows.map(_rowToDevice).toList();
  }

  Future<Device> insert(Device device) async {
    final db = await _getDb();
    final id = await db.insert(_table, {
      'name': device.name,
      'createdAtMillis': device.createdAt.millisecondsSinceEpoch,
    });
    return device.copyWith(id: id);
  }

  Future<void> update(Device device) async {
    if (device.id == null) return;
    final db = await _getDb();
    await db.update(
      _table,
      {
        'name': device.name,
        'createdAtMillis': device.createdAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [device.id],
    );
  }

  Future<void> delete(Device device) async {
    if (device.id == null) return;
    final db = await _getDb();
    await db.delete(_table, where: 'id = ?', whereArgs: [device.id]);
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
