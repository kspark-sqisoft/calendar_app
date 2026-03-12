import 'package:calendar_app/calendar/event_data_source.dart';

/// 겹치는 비-올데이 일정 그룹에서 재생할 것(제일 아래 = displayOrder 최소)만 남깁니다.
class PlanPreviewUtils {
  PlanPreviewUtils._();

  static bool _overlaps(Event a, Event b) {
    return a.from.isBefore(b.to) && a.to.isAfter(b.from);
  }

  /// 겹치는 구간(연결 요소)마다 displayOrder가 가장 작은 것(젤 아래)만 남긴 목록을 반환.
  /// 올데이 일정은 리스트 순서상 맨 아래(displayOrder 최대) 하나만 포함.
  static List<Event> onlyBottomInOverlap(List<Event> events) {
    final allDay = events.where((e) => e.isAllDay).toList();
    final nonAllDay = events.where((e) => !e.isAllDay).toList();

    final List<Event> bottomAllDay;
    if (allDay.isEmpty) {
      bottomAllDay = [];
    } else {
      allDay.sort((a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0));
      bottomAllDay = [allDay.last];
    }

    if (nonAllDay.isEmpty) return List.from(bottomAllDay);

    final n = nonAllDay.length;
    // 연결 요소: i와 j가 겹치면 같은 그룹
    final parent = List.generate(n, (i) => i);
    int find(int i) {
      if (parent[i] != i) parent[i] = find(parent[i]);
      return parent[i];
    }
    void unite(int i, int j) {
      final pi = find(i);
      final pj = find(j);
      if (pi != pj) parent[pi] = pj;
    }
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if (_overlaps(nonAllDay[i], nonAllDay[j])) unite(i, j);
      }
    }
    // 그룹별로 displayOrder 최소인 인덱스만 유지
    final groupMin = <int, int>{};
    for (var i = 0; i < n; i++) {
      final p = find(i);
      final order = nonAllDay[i].displayOrder ?? 0;
      if (!groupMin.containsKey(p) || (nonAllDay[groupMin[p]!].displayOrder ?? 0) > order) {
        groupMin[p] = i;
      }
    }
    final keepIndex = groupMin.values.toSet();

    final result = <Event>[...bottomAllDay];
    for (var i = 0; i < n; i++) {
      if (keepIndex.contains(i)) result.add(nonAllDay[i]);
    }
    result.sort((a, b) => a.from.compareTo(b.from));
    return result;
  }
}
