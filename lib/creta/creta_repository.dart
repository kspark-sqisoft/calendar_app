import 'package:calendar_app/creta/creta_book.dart';
import 'package:calendar_app/main.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 크레타북 로컬 저장 (SQLite)
class CretaRepository {
  CretaRepository._();
  static final CretaRepository instance = CretaRepository._();

  static const _table = 'cretabooks';
  static const _dbName = 'creta_books.db';
  static const _version = 1;

  Database? _db;

  Future<Database> _getDb() async {
    if (_db == null) {
      final dbPath = join(await getDatabasesPath(), _dbName);
      logger.d('로컬 DB: $_dbName → $dbPath');
      _db = await openDatabase(
        dbPath,
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
    }
    return _db!;
  }

  CretaBook _rowToBook(Map<String, Object?> row) {
    return CretaBook(
      id: row['id'] as int?,
      name: row['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAtMillis'] as int),
    );
  }

  Future<List<CretaBook>> getAll() async {
    final db = await _getDb();
    final rows = await db.query(_table, orderBy: 'createdAtMillis DESC');
    return rows.map(_rowToBook).toList();
  }

  Future<CretaBook> insert(CretaBook book) async {
    final db = await _getDb();
    final id = await db.insert(_table, {
      'name': book.name,
      'createdAtMillis': book.createdAt.millisecondsSinceEpoch,
    });
    return book.copyWith(id: id);
  }

  Future<void> update(CretaBook book) async {
    if (book.id == null) return;
    final db = await _getDb();
    await db.update(
      _table,
      {
        'name': book.name,
        'createdAtMillis': book.createdAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> delete(CretaBook book) async {
    if (book.id == null) return;
    final db = await _getDb();
    await db.delete(_table, where: 'id = ?', whereArgs: [book.id]);
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
