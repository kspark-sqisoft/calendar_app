import 'dart:convert';

import 'package:calendar_app/calendar/event_data_source.dart';
import 'package:calendar_app/creta/creta_book.dart';
import 'package:calendar_app/creta/creta_repository.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 캘린더 이벤트 + 방송 계획 로컬 저장 (SQLite)
class EventRepository {
  EventRepository._();
  static final EventRepository instance = EventRepository._();

  static const _table = 'events';
  static const _plansTable = 'plans';
  static const _settingsTable = 'settings';
  static const _dbName = 'calendar_events.db';
  static const _version = 5;

  static const _keyCalendarMinDate = 'calendarMinDate';
  static const _keyCalendarMaxDate = 'calendarMaxDate';

  Database? _db;

  Future<Database> _getDb() async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), _dbName),
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_plansTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            minDateMillis INTEGER NOT NULL,
            maxDateMillis INTEGER NOT NULL
          )
        ''');
        final now = DateTime.now();
        final defaultMin = DateTime(now.year - 1, 1, 1);
        final defaultMax = DateTime(now.year + 2, 12, 31);
        await db.insert(_plansTable, {
          'name': '기본 방송 계획',
          'minDateMillis': defaultMin.millisecondsSinceEpoch,
          'maxDateMillis': defaultMax.millisecondsSinceEpoch,
        });
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            planId INTEGER NOT NULL,
            eventName TEXT NOT NULL,
            fromMillis INTEGER NOT NULL,
            toMillis INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            isAllDay INTEGER NOT NULL,
            recurrenceRule TEXT,
            exceptionDatesJson TEXT,
            displayOrder INTEGER,
            cretaBookIdsJson TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $_settingsTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN displayOrder INTEGER',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE $_settingsTable (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN cretaBookIdsJson TEXT',
          );
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE $_plansTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              minDateMillis INTEGER NOT NULL,
              maxDateMillis INTEGER NOT NULL
            )
          ''');
          final now = DateTime.now();
          final defaultMin = DateTime(now.year - 1, 1, 1);
          final defaultMax = DateTime(now.year + 2, 12, 31);
          final planId = await db.insert(_plansTable, {
            'name': '기본 방송 계획',
            'minDateMillis': defaultMin.millisecondsSinceEpoch,
            'maxDateMillis': defaultMax.millisecondsSinceEpoch,
          });
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN planId INTEGER',
          );
          await db.rawUpdate(
            'UPDATE $_table SET planId = ?',
            [planId],
          );
        }
      },
    );
    return _db!;
  }

  /// PlanRepository 등에서 동일 DB 사용
  Future<Database> get db async => _getDb();

  /// 방송 계획별 캘린더 표시 기간 (계획에서 조회)
  Future<({DateTime minDate, DateTime maxDate})?> getPlanDateRange(int planId) async {
    final db = await _getDb();
    final rows = await db.query(
      _plansTable,
      where: 'id = ?',
      whereArgs: [planId],
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    return (
      minDate: DateTime.fromMillisecondsSinceEpoch(r['minDateMillis'] as int),
      maxDate: DateTime.fromMillisecondsSinceEpoch(r['maxDateMillis'] as int),
    );
  }

  /// 방송 계획 표시 기간 저장
  Future<void> setPlanDateRange(
    int planId,
    DateTime minDate,
    DateTime maxDate,
  ) async {
    final db = await _getDb();
    await db.update(
      _plansTable,
      {
        'minDateMillis': minDate.millisecondsSinceEpoch,
        'maxDateMillis': maxDate.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  /// 저장된 캘린더 표시 기간 (minDate, maxDate). 없으면 null. [레거시: planId 없을 때]
  Future<({DateTime minDate, DateTime maxDate})?> getCalendarDateRange() async {
    final db = await _getDb();
    try {
      final rows = await db.query(
        _settingsTable,
        where: 'key IN (?, ?)',
        whereArgs: [_keyCalendarMinDate, _keyCalendarMaxDate],
      );
      String? minVal;
      String? maxVal;
      for (final r in rows) {
        final k = r['key'] as String?;
        if (k == _keyCalendarMinDate) minVal = r['value'] as String?;
        if (k == _keyCalendarMaxDate) maxVal = r['value'] as String?;
      }
      if (minVal == null || maxVal == null) return null;
      final minMillis = int.tryParse(minVal);
      final maxMillis = int.tryParse(maxVal);
      if (minMillis == null || maxMillis == null) return null;
      return (
        minDate: DateTime.fromMillisecondsSinceEpoch(minMillis),
        maxDate: DateTime.fromMillisecondsSinceEpoch(maxMillis),
      );
    } catch (_) {
      return null;
    }
  }

  /// 캘린더 표시 기간 저장
  Future<void> setCalendarDateRange(DateTime minDate, DateTime maxDate) async {
    final db = await _getDb();
    await db.insert(_settingsTable, {
      'key': _keyCalendarMinDate,
      'value': '${minDate.millisecondsSinceEpoch}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert(_settingsTable, {
      'key': _keyCalendarMaxDate,
      'value': '${maxDate.millisecondsSinceEpoch}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Map -> Event (exceptionDatesJson: "[millis,millis,...]", cretaBookIdsJson: "[id,id,...]")
  Event _rowToEvent(
    Map<String, Object?> row,
    Map<int, CretaBook> cretaBookById,
  ) {
    List<DateTime>? exceptionDates;
    final jsonStr = row['exceptionDatesJson'] as String?;
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        exceptionDates = list
            .map((e) => DateTime.fromMillisecondsSinceEpoch(e as int))
            .toList();
      } catch (_) {}
    }
    List<CretaBook>? cretaBooks;
    final idsStr = row['cretaBookIdsJson'] as String?;
    if (idsStr != null && idsStr.isNotEmpty) {
      try {
        final list = jsonDecode(idsStr) as List<dynamic>;
        cretaBooks = list
            .map((e) => cretaBookById[e as int])
            .whereType<CretaBook>()
            .toList();
      } catch (_) {}
    }
    return Event(
      id: row['id'] as int?,
      planId: row['planId'] as int?,
      eventName: row['eventName'] as String,
      from: DateTime.fromMillisecondsSinceEpoch(row['fromMillis'] as int),
      to: DateTime.fromMillisecondsSinceEpoch(row['toMillis'] as int),
      background: Color(row['colorValue'] as int),
      isAllDay: (row['isAllDay'] as int) == 1,
      recurrenceRule: row['recurrenceRule'] as String?,
      recurrenceExceptionDates: exceptionDates,
      displayOrder: row['displayOrder'] as int?,
      cretaBooks: cretaBooks,
    );
  }

  Future<List<Event>> getAll() async {
    final db = await _getDb();
    final allBooks = await CretaRepository.instance.getAll();
    final cretaBookById = {for (final b in allBooks) if (b.id != null) b.id!: b};
    final rows = await db.query(_table, orderBy: 'fromMillis ASC');
    return rows.map((r) => _rowToEvent(r, cretaBookById)).toList();
  }

  /// 특정 방송 계획의 일정만 조회
  Future<List<Event>> getAllByPlanId(int planId) async {
    final db = await _getDb();
    final allBooks = await CretaRepository.instance.getAll();
    final cretaBookById = {for (final b in allBooks) if (b.id != null) b.id!: b};
    final rows = await db.query(
      _table,
      where: 'planId = ?',
      whereArgs: [planId],
      orderBy: 'fromMillis ASC',
    );
    return rows.map((r) => _rowToEvent(r, cretaBookById)).toList();
  }

  Future<Event> insert(Event event) async {
    final db = await _getDb();
    String? exceptionJson;
    if (event.recurrenceExceptionDates != null &&
        event.recurrenceExceptionDates!.isNotEmpty) {
      exceptionJson = jsonEncode(
        event.recurrenceExceptionDates!
            .map((d) => d.millisecondsSinceEpoch)
            .toList(),
      );
    }
    List<CretaBook>? filteredCretaBooks;
    String? cretaBookIdsJson;
    if (event.cretaBooks != null && event.cretaBooks!.isNotEmpty) {
      final allBooks = await CretaRepository.instance.getAll();
      final validIds = allBooks.map((b) => b.id).whereType<int>().toSet();
      final idsToSave = event.cretaBooks!
          .map((b) => b.id)
          .whereType<int>()
          .where(validIds.contains)
          .toList();
      cretaBookIdsJson =
          idsToSave.isEmpty ? null : jsonEncode(idsToSave);
      filteredCretaBooks = idsToSave.isEmpty
          ? null
          : idsToSave
              .map((id) => allBooks.firstWhere((b) => b.id == id))
              .toList();
    }
    final planId = event.planId ?? 1;
    final id = await db.insert(_table, {
      'planId': planId,
      'eventName': event.eventName,
      'fromMillis': event.from.millisecondsSinceEpoch,
      'toMillis': event.to.millisecondsSinceEpoch,
      'colorValue': event.background.value,
      'isAllDay': event.isAllDay ? 1 : 0,
      'recurrenceRule': event.recurrenceRule,
      'exceptionDatesJson': exceptionJson,
      'displayOrder': event.displayOrder,
      'cretaBookIdsJson': cretaBookIdsJson,
    });
    return Event(
      id: id,
      planId: planId,
      eventName: event.eventName,
      from: event.from,
      to: event.to,
      background: event.background,
      isAllDay: event.isAllDay,
      recurrenceRule: event.recurrenceRule,
      recurrenceExceptionDates: event.recurrenceExceptionDates,
      displayOrder: event.displayOrder,
      cretaBooks: filteredCretaBooks ?? event.cretaBooks,
    );
  }

  Future<void> update(Event event) async {
    if (event.id == null) return;
    final db = await _getDb();
    String? exceptionJson;
    if (event.recurrenceExceptionDates != null &&
        event.recurrenceExceptionDates!.isNotEmpty) {
      exceptionJson = jsonEncode(
        event.recurrenceExceptionDates!
            .map((d) => d.millisecondsSinceEpoch)
            .toList(),
      );
    }
    String? cretaBookIdsJson;
    if (event.cretaBooks != null && event.cretaBooks!.isNotEmpty) {
      final validIds = (await CretaRepository.instance.getAll())
          .map((b) => b.id)
          .whereType<int>()
          .toSet();
      final idsToSave = event.cretaBooks!
          .map((b) => b.id)
          .whereType<int>()
          .where(validIds.contains)
          .toList();
      cretaBookIdsJson =
          idsToSave.isEmpty ? null : jsonEncode(idsToSave);
    }
    await db.update(
      _table,
      {
        'eventName': event.eventName,
        'fromMillis': event.from.millisecondsSinceEpoch,
        'toMillis': event.to.millisecondsSinceEpoch,
        'colorValue': event.background.value,
        'isAllDay': event.isAllDay ? 1 : 0,
        'recurrenceRule': event.recurrenceRule,
        'exceptionDatesJson': exceptionJson,
        'displayOrder': event.displayOrder,
        'cretaBookIdsJson': cretaBookIdsJson,
      },
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  /// 방송 계획 삭제 시 해당 계획의 일정도 삭제
  Future<void> deleteEventsByPlanId(int planId) async {
    final db = await _getDb();
    await db.delete(_table, where: 'planId = ?', whereArgs: [planId]);
  }

  Future<void> delete(Event event) async {
    if (event.id == null) return;
    final db = await _getDb();
    await db.delete(_table, where: 'id = ?', whereArgs: [event.id]);
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
