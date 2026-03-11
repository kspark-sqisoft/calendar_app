import 'dart:convert';

import 'package:calendar_app/calendar/event_repository.dart';
import 'package:calendar_app/plan/broadcast_plan.dart';
import 'package:sqflite/sqflite.dart';

/// 방송 계획 로컬 저장 (EventRepository와 동일 DB 사용)
class PlanRepository {
  PlanRepository._();
  static final PlanRepository instance = PlanRepository._();

  static const _table = 'plans';

  Future<Database> _getDb() async => EventRepository.instance.db;

  List<int> _parseDeviceIdsJson(Object? value) {
    if (value == null || value is! String || value.isEmpty) return [];
    try {
      final list = jsonDecode(value) as List<dynamic>?;
      return list
              ?.map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [];
    } catch (_) {
      return [];
    }
  }

  BroadcastPlan _rowToPlan(Map<String, Object?> row) {
    return BroadcastPlan(
      id: row['id'] as int?,
      name: row['name'] as String,
      minDate: DateTime.fromMillisecondsSinceEpoch(row['minDateMillis'] as int),
      maxDate: DateTime.fromMillisecondsSinceEpoch(row['maxDateMillis'] as int),
      deviceIds: _parseDeviceIdsJson(row['deviceIdsJson']),
    );
  }

  Future<List<BroadcastPlan>> getAll() async {
    final db = await _getDb();
    final rows = await db.query(_table, orderBy: 'id ASC');
    return rows.map(_rowToPlan).toList();
  }

  Future<BroadcastPlan?> getById(int id) async {
    final db = await _getDb();
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _rowToPlan(rows.single);
  }

  Future<BroadcastPlan> insert(BroadcastPlan plan) async {
    final db = await _getDb();
    final id = await db.insert(_table, {
      'name': plan.name,
      'minDateMillis': plan.minDate.millisecondsSinceEpoch,
      'maxDateMillis': plan.maxDate.millisecondsSinceEpoch,
      'deviceIdsJson': plan.deviceIds.isEmpty ? null : jsonEncode(plan.deviceIds),
    });
    return plan.copyWith(id: id);
  }

  Future<void> update(BroadcastPlan plan) async {
    if (plan.id == null) return;
    final db = await _getDb();
    await db.update(
      _table,
      {
        'name': plan.name,
        'minDateMillis': plan.minDate.millisecondsSinceEpoch,
        'maxDateMillis': plan.maxDate.millisecondsSinceEpoch,
        'deviceIdsJson': plan.deviceIds.isEmpty ? null : jsonEncode(plan.deviceIds),
      },
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<void> delete(BroadcastPlan plan) async {
    if (plan.id == null) return;
    final db = await _getDb();
    await db.delete(_table, where: 'id = ?', whereArgs: [plan.id]);
    await EventRepository.instance.deleteEventsByPlanId(plan.id!);
  }
}
