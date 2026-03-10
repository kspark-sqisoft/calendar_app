import 'dart:convert';

import 'package:calendar_app/event_data_source.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 캘린더 이벤트 로컬 저장 (SQLite)
class EventRepository {
  EventRepository._();
  static final EventRepository instance = EventRepository._();

  static const _table = 'events';
  static const _dbName = 'calendar_events.db';
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
            eventName TEXT NOT NULL,
            fromMillis INTEGER NOT NULL,
            toMillis INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            isAllDay INTEGER NOT NULL,
            recurrenceRule TEXT,
            exceptionDatesJson TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  /// Map -> Event (exceptionDatesJson: "[millis,millis,...]")
  Event _rowToEvent(Map<String, Object?> row) {
    List<DateTime>? exceptionDates;
    final jsonStr = row['exceptionDatesJson'] as String?;
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        exceptionDates = list.map((e) => DateTime.fromMillisecondsSinceEpoch(e as int)).toList();
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
    if (event.recurrenceExceptionDates != null && event.recurrenceExceptionDates!.isNotEmpty) {
      exceptionJson = jsonEncode(
        event.recurrenceExceptionDates!.map((d) => d.millisecondsSinceEpoch).toList(),
      );
    }
    final id = await db.insert(
      _table,
      {
        'eventName': event.eventName,
        'fromMillis': event.from.millisecondsSinceEpoch,
        'toMillis': event.to.millisecondsSinceEpoch,
        'colorValue': event.background.value,
        'isAllDay': event.isAllDay ? 1 : 0,
        'recurrenceRule': event.recurrenceRule,
        'exceptionDatesJson': exceptionJson,
      },
    );
    return Event(
      id: id,
      eventName: event.eventName,
      from: event.from,
      to: event.to,
      background: event.background,
      isAllDay: event.isAllDay,
      recurrenceRule: event.recurrenceRule,
      recurrenceExceptionDates: event.recurrenceExceptionDates,
    );
  }

  Future<void> update(Event event) async {
    if (event.id == null) return;
    final db = await _getDb();
    String? exceptionJson;
    if (event.recurrenceExceptionDates != null && event.recurrenceExceptionDates!.isNotEmpty) {
      exceptionJson = jsonEncode(
        event.recurrenceExceptionDates!.map((d) => d.millisecondsSinceEpoch).toList(),
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
