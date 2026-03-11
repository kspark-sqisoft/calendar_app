import 'dart:convert';

import 'package:calendar_app/calendar/event_data_source.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 캘린더 이벤트 로컬 저장 (SQLite)
class EventRepository {
  EventRepository._();
  static final EventRepository instance = EventRepository._();

  static const _table = 'events';
  static const _settingsTable = 'settings';
  static const _dbName = 'calendar_events.db';
  static const _version = 3;

  static const _keyCalendarMinDate = 'calendarMinDate';
  static const _keyCalendarMaxDate = 'calendarMaxDate';

  Database? _db;

  Future<Database> _getDb() async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), _dbName),
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eventName TEXT NOT NULL,
            fromMillis INTEGER NOT NULL,
            toMillis INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            isAllDay INTEGER NOT NULL,
            recurrenceRule TEXT,
            exceptionDatesJson TEXT,
            displayOrder INTEGER
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
      },
    );
    return _db!;
  }

  /// 저장된 캘린더 표시 기간 (minDate, maxDate). 없으면 null.
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

  /// Map -> Event (exceptionDatesJson: "[millis,millis,...]")
  Event _rowToEvent(Map<String, Object?> row) {
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
    return Event(
      id: row['id'] as int?,
      eventName: row['eventName'] as String,
      from: DateTime.fromMillisecondsSinceEpoch(row['fromMillis'] as int),
      to: DateTime.fromMillisecondsSinceEpoch(row['toMillis'] as int),
      background: Color(row['colorValue'] as int),
      isAllDay: (row['isAllDay'] as int) == 1,
      recurrenceRule: row['recurrenceRule'] as String?,
      recurrenceExceptionDates: exceptionDates,
      displayOrder: row['displayOrder'] as int?,
    );
  }

  Future<List<Event>> getAll() async {
    final db = await _getDb();
    final rows = await db.query(_table, orderBy: 'fromMillis ASC');
    return rows.map(_rowToEvent).toList();
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
    final id = await db.insert(_table, {
      'eventName': event.eventName,
      'fromMillis': event.from.millisecondsSinceEpoch,
      'toMillis': event.to.millisecondsSinceEpoch,
      'colorValue': event.background.value,
      'isAllDay': event.isAllDay ? 1 : 0,
      'recurrenceRule': event.recurrenceRule,
      'exceptionDatesJson': exceptionJson,
      'displayOrder': event.displayOrder,
    });
    return Event(
      id: id,
      eventName: event.eventName,
      from: event.from,
      to: event.to,
      background: event.background,
      isAllDay: event.isAllDay,
      recurrenceRule: event.recurrenceRule,
      recurrenceExceptionDates: event.recurrenceExceptionDates,
      displayOrder: event.displayOrder,
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
      },
      where: 'id = ?',
      whereArgs: [event.id],
    );
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
