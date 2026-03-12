import 'dart:async';
import 'dart:convert';

import 'package:calendar_app/calendar/event_data_source.dart';
import 'package:calendar_app/calendar/event_edit_dialog.dart';
import 'package:calendar_app/calendar/event_repository.dart';
import 'package:calendar_app/extensions/string_color_extension.dart';
import 'package:calendar_app/main.dart';
import 'package:calendar_app/plan/plan_name_edit_dialog.dart';
import 'package:calendar_app/plan/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key, required this.planId});

  final int planId;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage>
    with SingleTickerProviderStateMixin {
  late CalendarController _calendarController;
  late EventDataSource _eventDataSource;
  late AnimationController _onAirBlinkController;
  late Animation<double> _onAirBlinkAnimation;
  final List<Event> _events = [];
  bool _isLoading = true;
  String? _loadError;
  String? _planName;

  /// 우클릭 메뉴용: 마지막으로 탭한 셀의 날짜 (우클릭 시 이 날짜에 이벤트 생성)
  DateTime? _contextMenuDate;

  /// 더블클릭 감지: 같은 일정을 짧은 간격에 두 번 탭하면 수정 창
  DateTime? _lastTapTime;
  Event? _lastTappedEvent;
  static const _doubleTapInterval = Duration(milliseconds: 400);

  /// 현재 캘린더 뷰 (기본: timelineDay)
  CalendarView _currentView = CalendarView.timelineWeek;

  /// 드래그/리사이즈 반영 후 캘린더 재생성용 (중복 표시 방지)
  final int _calendarDataKey = 0;

  /// 캘린더 표시 범위 (상단 UI로 변경 가능)
  late DateTime _calendarMinDate;
  late DateTime _calendarMaxDate;

  /// On Air 아이콘 갱신용: 1분마다 setState
  Timer? _onAirUpdateTimer;

  /// 뷰 변경 시 오늘 날짜로 이동 (true) vs 라이브러리 기본 동작 유지 (false)
  bool _viewChangeMovesToToday = true;

  /// 타임라인 시간축 간격 너비 (기본 75)
  double _timeIntervalWidth = 75;

  /// 타임라인 시간축 간격 높이 (기본 60)
  double _timeIntervalHeight = 60;

  /// 타임라인 일정 높이 (기본 60)
  double _timelineAppointmentHeight = 60;

  static const _viewLabels = {
    CalendarView.day: '일',
    CalendarView.week: '주',
    CalendarView.workWeek: '주(평일)',
    CalendarView.month: '월',
    CalendarView.timelineDay: '타임라인 일',
    CalendarView.timelineWeek: '타임라인 주',
    CalendarView.timelineWorkWeek: '타임라인 평일',
    CalendarView.timelineMonth: '타임라인 월',
    CalendarView.schedule: '스케줄',
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMinDate = DateTime(now.year - 1, 1, 1);
    _calendarMaxDate = DateTime(now.year + 2, 12, 31);
    _calendarController = CalendarController();
    _calendarController.view = CalendarView.timelineWeek;
    _eventDataSource = EventDataSource(_events);
    _loadEvents();
    _onAirUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _onAirBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _onAirBlinkAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _onAirBlinkController, curve: Curves.easeInOut),
    );
    _loadViewChangeMovesToToday();
    _loadTimeIntervalWidth();
    _loadTimeIntervalHeight();
    _loadTimelineAppointmentHeight();
  }

  Future<void> _loadViewChangeMovesToToday() async {
    final value = await EventRepository.instance.getViewChangeMovesToToday();
    if (mounted) setState(() => _viewChangeMovesToToday = value);
  }

  Future<void> _loadTimeIntervalWidth() async {
    final value = await EventRepository.instance.getTimeIntervalWidth();
    if (mounted) setState(() => _timeIntervalWidth = value.toDouble());
  }

  Future<void> _loadTimeIntervalHeight() async {
    final value = await EventRepository.instance.getTimeIntervalHeight();
    if (mounted) setState(() => _timeIntervalHeight = value.toDouble());
  }

  Future<void> _loadTimelineAppointmentHeight() async {
    final value = await EventRepository.instance.getTimelineAppointmentHeight();
    if (mounted) setState(() => _timelineAppointmentHeight = value.toDouble());
  }

  Future<void> _showCalendarOptions() async {
    var movesToToday = _viewChangeMovesToToday;
    var timeIntervalWidth = _timeIntervalWidth;
    var timeIntervalHeight = _timeIntervalHeight;
    var timelineAppointmentHeight = _timelineAppointmentHeight;
    final result = await showDialog<(bool, int, int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('캘린더 옵션'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: const Text('뷰 변경 시 오늘 날짜로 이동'),
                  subtitle: Text(
                    movesToToday
                        ? '뷰를 바꾸면 오늘 날짜로 이동합니다.'
                        : '뷰만 바꾸고 현재 보이는 날짜를 유지합니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: movesToToday,
                  onChanged: (v) {
                    setDialogState(() => movesToToday = v);
                  },
                ),
                const Divider(height: 24),
                Text(
                  '시간축 간격 너비 (timeIntervalWidth)기본 70',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: timeIntervalWidth,
                        min: 40,
                        max: 200,
                        divisions: 16,
                        label: timeIntervalWidth.round().toString(),
                        onChanged: (v) {
                          setDialogState(() => timeIntervalWidth = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${timeIntervalWidth.round()}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '시간축 간격 높이 (timeIntervalHeight) 기본 60',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: timeIntervalHeight,
                        min: 30,
                        max: 120,
                        divisions: 9,
                        label: timeIntervalHeight.round().toString(),
                        onChanged: (v) {
                          setDialogState(() => timeIntervalHeight = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${timeIntervalHeight.round()}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '타임라인 일정 높이 (timelineAppointmentHeight) 기본 60',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: timelineAppointmentHeight,
                        min: 30,
                        max: 120,
                        divisions: 9,
                        label: timelineAppointmentHeight.round().toString(),
                        onChanged: (v) {
                          setDialogState(() => timelineAppointmentHeight = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${timelineAppointmentHeight.round()}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop((
                movesToToday,
                timeIntervalWidth.round(),
                timeIntervalHeight.round(),
                timelineAppointmentHeight.round(),
              )),
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await EventRepository.instance.setViewChangeMovesToToday(result.$1);
      await EventRepository.instance.setTimeIntervalWidth(result.$2);
      await EventRepository.instance.setTimeIntervalHeight(result.$3);
      await EventRepository.instance.setTimelineAppointmentHeight(result.$4);
      setState(() {
        _viewChangeMovesToToday = result.$1;
        _timeIntervalWidth = result.$2.toDouble();
        _timeIntervalHeight = result.$3.toDouble();
        _timelineAppointmentHeight = result.$4.toDouble();
      });
    }
  }

  @override
  void dispose() {
    _onAirUpdateTimer?.cancel();
    _onAirBlinkController.dispose();
    super.dispose();
  }

  /// 올데이 이벤트끼리만 displayOrder 부여(0, 1, 2, …). 리스트 순서와 맞추기 위해 _events 안 올데이도 displayOrder 오름차순으로 재배치.
  void _normalizeDisplayOrderForAllDay() {
    final allDay = _events.where((e) => e.isAllDay).toList();
    if (allDay.isEmpty) return;
    allDay.sort((a, b) {
      final oa = a.displayOrder ?? 0;
      final ob = b.displayOrder ?? 0;
      if (oa != ob) return ob.compareTo(oa);
      final fc = a.from.compareTo(b.from);
      if (fc != 0) return fc;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    var order = allDay.length - 1;
    for (final e in allDay) {
      e.displayOrder = order--;
    }
    _reorderAllDayInEventsByDisplayOrder();
  }

  /// _events 리스트 안에서 올데이만 displayOrder 오름차순으로 재배치 (리스트 앞=위, 뒤=아래 = 메뉴와 동기화).
  void _reorderAllDayInEventsByDisplayOrder() {
    final indices = <int>[];
    for (var i = 0; i < _events.length; i++) {
      if (_events[i].isAllDay) indices.add(i);
    }
    if (indices.isEmpty) return;
    final allDay = indices.map((i) => _events[i]).toList();
    allDay.sort((a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0));
    for (var j = 0; j < indices.length; j++) {
      _events[indices[j]] = allDay[j];
    }
  }

  /// 겹치는 비-올데이 그룹에서 displayOrder가 없거나 같으면, 시작 시간 순(빠른 쪽이 왼쪽/위)으로 초기값 부여.
  void _normalizeDisplayOrderForOverlappingGroups() {
    final nonAllDay = _events.where((e) => !e.isAllDay).toList();
    for (final event in nonAllDay) {
      final overlapping = nonAllDay
          .where(
            (e) =>
                e != event &&
                _timeRangesOverlap(event.from, event.to, e.from, e.to),
          )
          .toList();
      if (overlapping.isEmpty) continue;
      overlapping.add(event);
      final orders = overlapping.map((e) => e.displayOrder ?? 0).toSet();
      if (orders.length <= 1) {
        overlapping.sort((a, b) => a.from.compareTo(b.from));
        var order = 1000 + overlapping.length - 1;
        for (final e in overlapping) {
          e.displayOrder = order--;
        }
      }
    }
  }

  /// 제외 요일을 표시 기간 내 제외 날짜로 넣은 이벤트 목록 (Syncfusion이 제외 요일을 지원하지 않으므로)
  List<Event> _getDisplayEvents() {
    final min = _calendarMinDate;
    final max = _calendarMaxDate;
    return _events.map<Event>((e) {
      final wd = e.recurrenceExceptionWeekdays;
      if (wd == null || wd.isEmpty || e.recurrenceRule == null) return e;
      final existing = e.recurrenceExceptionDates ?? [];
      final added = <DateTime>[];
      for (var d = DateTime(min.year, min.month, min.day);
          !d.isAfter(max);
          d = d.add(const Duration(days: 1))) {
        if (wd.contains(d.weekday)) added.add(DateTime(d.year, d.month, d.day));
      }
      if (added.isEmpty) return e;
      final merged = [...existing];
      for (final day in added) {
        if (merged.any((x) =>
            x.year == day.year && x.month == day.month && x.day == day.day)) {
          continue;
        }
        merged.add(day);
      }
      merged.sort((a, b) => a.compareTo(b));
      return Event(
        id: e.id,
        planId: e.planId,
        eventName: e.eventName,
        from: e.from,
        to: e.to,
        background: e.background,
        isAllDay: e.isAllDay,
        recurrenceRule: e.recurrenceRule,
        recurrenceExceptionDates: merged,
        recurrenceExceptionWeekdays: e.recurrenceExceptionWeekdays,
        displayOrder: e.displayOrder,
        cretaBooks: e.cretaBooks,
      );
    }).toList();
  }

  void _refreshCalendarDisplay() {
    _eventDataSource.appointments = _getDisplayEvents();
    _eventDataSource.notifyListeners(
      CalendarDataSourceAction.reset,
      _eventDataSource.appointments!,
    );
  }

  /// Event → JSON 맵 (팝업 표시용)
  Map<String, dynamic> _eventToJson(Event e) {
    return {
      'id': e.id,
      'eventName': e.eventName,
      'from': e.from.toIso8601String(),
      'to': e.to.toIso8601String(),
      'colorValue': e.background.value,
      'isAllDay': e.isAllDay,
      'recurrenceRule': e.recurrenceRule,
      'recurrenceExceptionDates': e.recurrenceExceptionDates
          ?.map((d) => d.toIso8601String())
          .toList(),
      'recurrenceExceptionWeekdays': e.recurrenceExceptionWeekdays,
      'displayOrder': e.displayOrder,
      'cretaBooks': e.cretaBooks
          ?.map(
            (b) => {
              'id': b.id,
              'name': b.name,
              'createdAt': b.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  /// 전체 데이터 가져와서 JSON 팝업으로 표시 (일정 + 캘린더 표시 기간 포함)
  Future<void> _showAllDataPopup() async {
    try {
      final list = _events;
      final jsonList = list.map(_eventToJson).toList();
      final fullData = <String, dynamic>{
        'broadcastPlanName': _planName,
        'calendarDateRange': {
          'minDate': _calendarMinDate.toIso8601String(),
          'maxDate': _calendarMaxDate.toIso8601String(),
        },
        'events': jsonList,
      };
      final jsonString = const JsonEncoder.withIndent('  ').convert(fullData);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('전체 일정 데이터 (JSON)'),
          content: SizedBox(
            width: 620,
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '총 ${list.length}건',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SelectableText(
                        jsonString,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON이 클립보드에 복사되었습니다.')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('복사'),
            ),
          ],
        ),
      );
    } catch (e, st) {
      debugPrint('getAll error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로드 실패: $e')));
      }
    }
  }

  Future<void> _editPlanName() async {
    final plan = await PlanRepository.instance.getById(widget.planId);
    if (plan == null || !mounted) return;
    final newName = await showPlanNameEditDialog(
      context,
      initialName: plan.name,
    );
    if (newName == null || newName == plan.name || !mounted) return;
    try {
      await PlanRepository.instance.update(plan.copyWith(name: newName));
      if (mounted) setState(() => _planName = newName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      final planId = widget.planId;
      final list = await EventRepository.instance.getAllByPlanId(planId);
      final savedRange = await EventRepository.instance.getPlanDateRange(
        planId,
      );
      final plan = await PlanRepository.instance.getById(planId);
      logger.d('Loaded events: $list'.toGreen);
      if (mounted) {
        setState(() {
          _events.clear();
          _events.addAll(list);
          _normalizeDisplayOrderForOverlappingGroups();
          _normalizeDisplayOrderForAllDay();
          _planName = plan?.name;
          if (savedRange != null) {
            _calendarMinDate = savedRange.minDate;
            _calendarMaxDate = savedRange.maxDate;
          }
          _isLoading = false;
          _loadError = null;
        });
        _refreshCalendarDisplay();
        // 캘린더가 뜬 직후 현재 시간선이 바로 그려지도록 한두 번 더 갱신
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() {});
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() {});
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  void _showContextMenu(DateTime date, Offset globalPosition) {
    final initialFrom = DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
    );
    final initialTo = initialFrom.add(const Duration(hours: 1));

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          child: const ListTile(leading: Icon(Icons.add), title: Text('새 이벤트')),
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final event = await showEventEditDialog(
                context: context,
                initialFrom: initialFrom,
                initialTo: initialTo,
              );
              if (event != null && mounted) {
                event.planId = widget.planId;
                _addEvent(event);
              }
            });
          },
        ),
      ],
    );
  }

  /// FAB으로 새 이벤트 생성: 현재 표시 중인 날짜(displayDate) 기준 1시간 구간으로 편집 다이얼로그 오픈
  Future<void> _onFabNewEvent() async {
    final displayDate = _calendarController.displayDate ?? DateTime.now();
    final initialFrom = DateTime(
      displayDate.year,
      displayDate.month,
      displayDate.day,
      displayDate.hour,
      0,
    );
    final initialTo = initialFrom.add(const Duration(hours: 1));
    final event = await showEventEditDialog(
      context: context,
      initialFrom: initialFrom,
      initialTo: initialTo,
    );
    if (event != null && mounted) {
      event.planId = widget.planId;
      _addEvent(event);
    }
  }

  Future<void> _addEvent(Event event) async {
    try {
      final saved = await EventRepository.instance.insert(event);
      if (!mounted) return;
      _events.add(saved);
      // 겹치는 일정이 있으면 새 일정을 그 아래에 두기 위해 displayOrder를 더 작게 설정
      if (!saved.isAllDay) {
        final overlapping = _events
            .where(
              (e) =>
                  e != saved &&
                  !e.isAllDay &&
                  _timeRangesOverlap(saved.from, saved.to, e.from, e.to),
            )
            .toList();
        if (overlapping.isNotEmpty) {
          final minOrder = overlapping
              .map((e) => e.displayOrder ?? 0)
              .reduce((a, b) => a < b ? a : b);
          saved.displayOrder = minOrder - 1;
          await EventRepository.instance.update(saved);
        }
      }
      _normalizeDisplayOrderForOverlappingGroups();
      _normalizeDisplayOrderForAllDay();
      _refreshCalendarDisplay();
      if (mounted) {
        // 생성한 일정 날짜가 오늘이 아니면(미래/과거) 캘린더를 해당 날짜로 이동
        final now = DateTime.now();
        final createdDate = saved.from;
        if (createdDate.year != now.year ||
            createdDate.month != now.month ||
            createdDate.day != now.day) {
          _calendarController.displayDate = createdDate;
          _calendarController.selectedDate = createdDate;
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  /// 탭한 요소에서 우리 Event 찾기 (Syncfusion이 Appointment로 넘기면 _events에서 매칭)
  /// 반복 일정은 매 탭마다 convertAppointmentToObject로 새 Event 인스턴스가 오므로, 항상 _events 안의 동일 시리즈를 반환.
  Event? _findEventFromTapped(dynamic tapped) {
    if (tapped is Event) {
      final idx = _events.indexOf(tapped);
      if (idx >= 0) return tapped;
      // 반복 회차로 넘어온 복사본: id로 시리즈 찾기 (수정 시 _events 항목이어야 함)
      if (tapped.id != null) {
        for (final e in _events) {
          if (e.id == tapped.id) return e;
        }
      }
      // id 없이 넘어온 반복 회차: 제목 + 반복 규칙으로 시리즈 찾기
      if (tapped.recurrenceRule != null) {
        for (final e in _events) {
          if (e.recurrenceRule != null && e.eventName == tapped.eventName) {
            return e;
          }
        }
      }
      return tapped;
    }
    if (tapped is Appointment) {
      for (final e in _events) {
        if (e.from == tapped.startTime &&
            e.to == tapped.endTime &&
            e.eventName == tapped.subject) {
          return e;
        }
      }
      for (final e in _events) {
        if (e.recurrenceRule != null && e.eventName == tapped.subject) {
          return e;
        }
      }
    }
    return null;
  }

  /// 더블탭 판별: 같은 시리즈면 true (반복 일정은 탭마다 새 인스턴스가 오므로 id로 비교)
  bool _isSameEvent(Event? a, Event? b) {
    if (a == null || b == null) return a == b;
    if (identical(a, b)) return true;
    if (a.id != null && a.id == b.id) return true;
    return a.from == b.from && a.to == b.to && a.eventName == b.eventName;
  }

  /// 드래그/리사이즈 콜백에서 appointment → Event 변환 (동일 참조 또는 매칭)
  Event? _getEventFromAppointment(dynamic appointment) {
    if (appointment is Event) return appointment;
    return _findEventFromTapped(appointment);
  }

  /// 드래그로 놓은 위치가 위/아래 기준. 겹친 이벤트가 누구인지로만 판단.
  /// B·C 둘 다 겹치면 → B와 C 사이. C만 겹치면 → C 아래. B만 겹치면 → B 아래.
  void _onAppointmentDragEnd(AppointmentDragEndDetails details) {
    // 디버깅: 드래그 종료 시 호출 여부·인자 확인
    debugPrint(
      '[DragEnd] called. appointment=${details.appointment?.runtimeType} droppingTime=${details.droppingTime}',
    );
    if (details.appointment is Event) {
      final e = details.appointment as Event;
      debugPrint(
        '[DragEnd] appointment is Event: id=${e.id} from=${e.from} to=${e.to}',
      );
    }
    final event = _getEventFromAppointment(details.appointment);
    if (event == null) {
      debugPrint(
        '[DragEnd] early return: event is null (appointment not matched to Event). _events.length=${_events.length}',
      );
      return;
    }
    if (details.droppingTime == null) {
      debugPrint('[DragEnd] early return: droppingTime is null');
      return;
    }
    final duration = event.to.difference(event.from);
    final newFrom = details.droppingTime!;
    final newTo = newFrom.add(duration);
    debugPrint(
      '[DragEnd] event=${event.eventName} newFrom=$newFrom newTo=$newTo',
    );
    event.from = newFrom;
    event.to = newTo;

    if (!event.isAllDay) {
      final overlapping = _events
          .where(
            (e) =>
                e != event &&
                !e.isAllDay &&
                _timeRangesOverlap(newFrom, newTo, e.from, e.to),
          )
          .toList();

      if (overlapping.isEmpty) {
        debugPrint('[DragEnd] no overlap, persisting single event');
        _persistEventAfterDragOrResize(event);
        return;
      }

      if (overlapping.length == 1) {
        debugPrint('[DragEnd] 1 overlapping, setting displayOrder below it');
        // 한 명만 겹침 → 그 이벤트 바로 아래로
        event.displayOrder = (overlapping.first.displayOrder ?? 0) - 1;
        _persistEventAfterDragOrResize(event);
        return;
      }

      overlapping.sort(
        (a, b) => (b.displayOrder ?? 0).compareTo(a.displayOrder ?? 0),
      );
      int insertIndex;
      final dropPos = details.dropPosition;
      if (dropPos != null &&
          _calendarController.getCalendarDetailsAtOffset != null) {
        insertIndex = _insertIndexFromDropPosition(dropPos);
        debugPrint(
          '[DragEnd] ${overlapping.length} overlapping, insertIndex from drop position: $insertIndex',
        );
      } else {
        debugPrint(
          '[DragEnd] ${overlapping.length} overlapping, inserting by drop time (no dropPosition)',
        );
        final atOrAfter = overlapping
            .where((e) => !e.from.isBefore(newFrom))
            .toList();
        final DateTime effectiveFrom;
        if (atOrAfter.length >= 2) {
          effectiveFrom = atOrAfter[1].from;
        } else if (atOrAfter.length == 1) {
          effectiveFrom = atOrAfter[0].from;
        } else {
          effectiveFrom = newFrom;
        }
        insertIndex = overlapping
            .where((e) => e.from.isBefore(effectiveFrom))
            .length;
      }
      insertIndex = insertIndex.clamp(0, overlapping.length);
      final ordered = [
        ...overlapping.sublist(0, insertIndex),
        event,
        ...overlapping.sublist(insertIndex),
      ];
      var order = 1000 + ordered.length - 1;
      for (final e in ordered) {
        e.displayOrder = order--;
      }
      _persistDragOrder(ordered);
      return;
    }
    _persistEventAfterDragOrResize(event);
  }

  Future<void> _persistDragOrder(List<Event> events) async {
    try {
      debugPrint('[DragEnd] persistDragOrder: ${events.length} events');
      for (final e in events) {
        await EventRepository.instance.update(e);
      }
      if (!mounted) return;
      _refreshCalendarDisplay();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('일정 순서 저장 실패: $e')));
      }
    }
  }

  static const _timelineViews = {
    CalendarView.timelineDay,
    CalendarView.timelineWeek,
    CalendarView.timelineWorkWeek,
    CalendarView.timelineMonth,
  };

  /// 일/주/주(평일) 뷰: 겹치는 일정이 가로 배치 → 메뉴는 왼쪽/오른쪽/맨 오른쪽
  static const _dayViewsWithHorizontalStack = {
    CalendarView.day,
    CalendarView.week,
    CalendarView.workWeek,
  };

  /// 타임라인 뷰: Y 스캔. 일/주 뷰(시간 세로): X 스캔.
  int _insertIndexFromDropPosition(Offset dropPos) {
    if (_timelineViews.contains(_currentView)) {
      return _insertIndexFromDropY(dropPos);
    }
    return _insertIndexFromDropX(dropPos);
  }

  /// 타임라인 뷰용. 겹치는 이벤트들의 경계(Y)를 스캔해, drop Y보다 위에 있는 경계 개수 = 삽입 인덱스.
  /// 일정↔일정 전환만 경계로 센다(빈칸↔일정은 제외해 BACD가 되도록).
  int _insertIndexFromDropY(Offset dropPos) {
    final getDetails = _calendarController.getCalendarDetailsAtOffset;
    if (getDetails == null) return 0;
    const double step = 6.0;
    final RenderObject? ro = context.findRenderObject();
    final double rawMax = (ro is RenderBox) ? ro.size.height : 2000.0;
    final double maxY = rawMax > 2500 ? 2500 : rawMax;
    final boundaries = <double>[];
    int? prevId;
    for (double y = 0; y <= maxY; y += step) {
      final details = getDetails(Offset(dropPos.dx, y));
      final current =
          (details?.targetElement == CalendarElement.appointment &&
              details?.appointments != null &&
              details!.appointments!.isNotEmpty)
          ? _findEventFromTapped(details.appointments!.first)
          : null;
      final currentId = current?.id;
      if (prevId != null && currentId != null && prevId != currentId) {
        boundaries.add(y);
      }
      prevId = currentId;
    }
    return boundaries.where((b) => b < dropPos.dy).length;
  }

  /// 일/주 뷰용(시간 세로). 겹치는 이벤트들의 경계(X)를 스캔해, drop X보다 왼쪽에 있는 경계 개수 = 삽입 인덱스.
  /// 일정↔일정 전환만 경계로 센다.
  int _insertIndexFromDropX(Offset dropPos) {
    final getDetails = _calendarController.getCalendarDetailsAtOffset;
    if (getDetails == null) return 0;
    const double step = 8.0;
    const double maxX = 3000.0;
    final boundaries = <double>[];
    int? prevId;
    for (double x = 0; x <= maxX; x += step) {
      final details = getDetails(Offset(x, dropPos.dy));
      final current =
          (details?.targetElement == CalendarElement.appointment &&
              details?.appointments != null &&
              details!.appointments!.isNotEmpty)
          ? _findEventFromTapped(details.appointments!.first)
          : null;
      final currentId = current?.id;
      if (prevId != null && currentId != null && prevId != currentId) {
        boundaries.add(x);
      }
      prevId = currentId;
    }
    return boundaries.where((b) => b < dropPos.dx).length;
  }

  static bool _timeRangesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
  }

  /// 겹치는 그룹에서 맨 앞(타임라인=맨 아래, 일뷰=맨 오른쪽)이면 true. 둘 다 displayOrder 최소가 맨 앞.
  /// 올데이: Syncfusion은 displayOrder 작을수록 위 행에 그림 → displayOrder 최대 = 맨 아래 행 = 방송 중(온에어).
  bool _isFrontInOverlappingStack(Event event) {
    if (event.isAllDay) {
      final allDay = _events.where((e) => e.isAllDay).toList();
      if (allDay.isEmpty) return true;
      final maxOrder = allDay
          .map((e) => e.displayOrder ?? 0)
          .reduce((a, b) => a > b ? a : b);
      return (event.displayOrder ?? 0) == maxOrder;
    }
    final overlapping = _events
        .where(
          (e) =>
              e != event &&
              !e.isAllDay &&
              _timeRangesOverlap(event.from, event.to, e.from, e.to),
        )
        .toList();
    final allOrders = [
      event.displayOrder ?? 0,
      ...overlapping.map((e) => e.displayOrder ?? 0),
    ];
    final minOrder = allOrders.reduce((a, b) => a < b ? a : b);
    return (event.displayOrder ?? 0) == minOrder;
  }

  /// 방송 중인 일정(1.0)이고 현재 시간이 구간 안이면 true (시간 기반만). 시리즈 from/to 사용.
  bool _isOnAir(Event event) {
    if (event.isAllDay) return false;
    final now = DateTime.now();
    return !now.isBefore(event.from) && now.isBefore(event.to);
  }

  /// 이 회차(occurrence)가 오늘이고, 현재 시간이 회차 구간 안이면 true (반복 일정 온에어용)
  bool _isOnAirForOccurrence(DateTime occurrenceStart, DateTime occurrenceEnd) {
    final now = DateTime.now();
    if (!_isSameDay(occurrenceStart, now)) return false;
    return !now.isBefore(occurrenceStart) && now.isBefore(occurrenceEnd);
  }

  /// 같은 날인지 (날짜만 비교)
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 현재 시각에 방송 중인 시간 기반 이벤트가 하나라도 있으면 true
  bool _hasTimeBasedOnAirNow() {
    return _events.any(
      (e) => !e.isAllDay && _isFrontInOverlappingStack(e) && _isOnAir(e),
    );
  }

  /// 툴팁용 시간 문자열 (HH:mm)
  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// min/max 날짜 표시용 (yyyy-MM-dd)
  String _formatDateYMD(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 상단 min/max 날짜 설정 바
  Widget _buildMinMaxDateBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Text('표시 범위:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_formatDateYMD(_calendarMinDate)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _calendarMinDate,
                firstDate: DateTime(1990),
                lastDate: _calendarMaxDate.subtract(const Duration(days: 1)),
              );
              if (picked != null && mounted) {
                setState(() {
                  _calendarMinDate = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                  );
                  if (!_calendarMaxDate.isAfter(_calendarMinDate)) {
                    _calendarMaxDate = _calendarMinDate.add(
                      const Duration(days: 365),
                    );
                  }
                });
                EventRepository.instance.setPlanDateRange(
                  widget.planId,
                  _calendarMinDate,
                  _calendarMaxDate,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _refreshCalendarDisplay();
                });
              }
            },
          ),
          const SizedBox(width: 8),
          const Text('~', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_formatDateYMD(_calendarMaxDate)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _calendarMaxDate,
                firstDate: _calendarMinDate.add(const Duration(days: 1)),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() {
                  _calendarMaxDate = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                  );
                });
                EventRepository.instance.setPlanDateRange(
                  widget.planId,
                  _calendarMinDate,
                  _calendarMaxDate,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _refreshCalendarDisplay();
                });
              }
            },
          ),
          const Spacer(),
          Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(localeProvider);
              final label = locale.languageCode == 'ko' ? '오늘로 이동' : 'Go Today';
              return TextButton.icon(
                onPressed: () {
                  final today = DateTime.now();
                  _calendarController.displayDate = today;
                  _calendarController.selectedDate = today;
                  setState(() {});
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(label),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 지금 그려지는 일정의 날짜 (반복이면 해당 회차 날짜). 셀 날짜(detailsDate)가 있으면 Event인 경우 그걸 사용.
  DateTime _getOccurrenceDate(dynamic appointment, [DateTime? detailsDate]) {
    if (appointment is Appointment) {
      return appointment.startTime;
    }
    if (appointment is Event && detailsDate != null) {
      return detailsDate;
    }
    if (appointment is Event) {
      return appointment.from;
    }
    return DateTime.now();
  }

  /// 지금 그려지는 회차의 시작·종료. Syncfusion Appointment이면 그 회차의 start/end, Event면 details.date에 이벤트 시·분 적용.
  (DateTime start, DateTime end) _getOccurrenceTimeRange(
    dynamic appointment,
    Event event,
    DateTime detailsDate,
  ) {
    if (appointment is Appointment) {
      return (appointment.startTime, appointment.endTime);
    }
    // 월/아젠더 등에서 Event만 넘어오면 셀 날짜(detailsDate)에 이벤트 시간을 붙여 해당 회차로 사용.
    if (event.isAllDay) return (event.from, event.to);
    return (
      DateTime(
        detailsDate.year,
        detailsDate.month,
        detailsDate.day,
        event.from.hour,
        event.from.minute,
      ),
      DateTime(
        detailsDate.year,
        detailsDate.month,
        detailsDate.day,
        event.to.hour,
        event.to.minute,
      ),
    );
  }

  Widget _buildAppointmentWithStackOpacity(
    BuildContext context,
    CalendarAppointmentDetails details,
  ) {
    if (details.appointments.isEmpty) return const SizedBox.shrink();
    final event = _findEventFromTapped(details.appointments.first);
    if (event == null) return const SizedBox.shrink();
    final isFront = _isFrontInOverlappingStack(event);
    final opacity = isFront ? 1.0 : 0.3;
    // 시간 기반: 맨 앞이면서 **이 회차가 오늘**이고 현재 시간이 **이 회차** 구간 안일 때만 On Air. 하루 종일: 오늘이 이 회차 날짜일 때만.
    final DateTime occurrenceDate = _getOccurrenceDate(
      details.appointments.first,
      details.date,
    );
    final (occurrenceStart, occurrenceEnd) = _getOccurrenceTimeRange(
      details.appointments.first,
      event,
      details.date,
    );
    final isOnAir = event.isAllDay
        ? (isFront &&
              _isSameDay(occurrenceDate, DateTime.now()) &&
              !_hasTimeBasedOnAirNow())
        : (isFront && _isOnAirForOccurrence(occurrenceStart, occurrenceEnd));
    final String timeText = event.isAllDay
        ? '${event.from.year}.${event.from.month}.${event.from.day} (하루 종일)'
        : '${_formatTime(event.from)} - ${_formatTime(event.to)}';
    final String tooltipMessage = '${event.eventName}\n$timeText';
    final isRecurring = event.recurrenceRule != null &&
        event.recurrenceRule!.isNotEmpty;
    final content = Tooltip(
      message: tooltipMessage,
      child: Container(
        width: details.bounds.width,
        height: details.bounds.height,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: event.background.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: isOnAir
                  ? Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.live_tv, size: 22, color: Colors.white),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.eventName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      event.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            if (isRecurring)
              Positioned(
                right: 2,
                bottom: 2,
                child: Icon(
                  Icons.autorenew,
                  size: 14,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
    if (isOnAir) {
      return AnimatedBuilder(
        animation: _onAirBlinkAnimation,
        builder: (context, child) =>
            Opacity(opacity: _onAirBlinkAnimation.value, child: content),
      );
    }
    return content;
  }

  /// 선택된 이벤트 우클릭 시: 위로 올리기 / 아래로 내리기 메뉴
  /// 올데이끼리, 비-올데이끼리만 순서 변경 가능(서로 섞이지 않음).
  void _showEventContextMenu(Event event, Offset globalPosition) {
    if (event.isAllDay) {
      _showAllDayContextMenu(event, globalPosition);
      return;
    }
    final overlapping = _events
        .where(
          (e) =>
              e != event &&
              !e.isAllDay &&
              _timeRangesOverlap(event.from, event.to, e.from, e.to),
        )
        .toList();
    final maxO = overlapping.isEmpty
        ? null
        : overlapping
              .map((e) => e.displayOrder ?? 0)
              .reduce((a, b) => a > b ? a : b);
    final minO = overlapping.isEmpty
        ? null
        : overlapping
              .map((e) => e.displayOrder ?? 0)
              .reduce((a, b) => a < b ? a : b);
    final myOrder = event.displayOrder ?? 0;
    final canMoveUp = maxO != null && myOrder <= maxO;
    final canMoveDown = minO != null && myOrder >= minO;

    final canMoveToBottom = minO != null && myOrder > minO;

    final isHorizontalStack = _dayViewsWithHorizontalStack.contains(
      _currentView,
    );
    final upLabel = isHorizontalStack ? '왼쪽으로' : '위로 올리기';
    final downLabel = isHorizontalStack ? '오른쪽으로' : '아래로 내리기';
    final toEndLabel = isHorizontalStack ? '맨 오른쪽으로' : '맨 아래로';
    final upIcon = isHorizontalStack ? Icons.arrow_back : Icons.arrow_upward;
    final downIcon = isHorizontalStack
        ? Icons.arrow_forward
        : Icons.arrow_downward;
    final toEndIcon = isHorizontalStack
        ? Icons.keyboard_double_arrow_right
        : Icons.vertical_align_bottom;

    final items = <PopupMenuItem<void>>[
      if (canMoveUp)
        PopupMenuItem(
          child: ListTile(leading: Icon(upIcon), title: Text(upLabel)),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _moveEventUp(event),
          ),
        ),
      if (canMoveDown)
        PopupMenuItem(
          child: ListTile(leading: Icon(downIcon), title: Text(downLabel)),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _moveEventDown(event),
          ),
        ),
      if (canMoveToBottom)
        PopupMenuItem(
          child: ListTile(leading: Icon(toEndIcon), title: Text(toEndLabel)),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _moveEventToBottom(event),
          ),
        ),
    ];
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('겹치는 일정이 없어 순서를 바꿀 수 없습니다')));
      return;
    }
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: items,
    );
  }

  /// 올데이를 _events 순서대로 (캘린더에 그리는 순서 = 리스트 순서). idx 0 = 화면 위, last = 화면 아래.
  List<Event> _getAllDayInDisplayOrder() {
    return _events.where((e) => e.isAllDay).toList();
  }

  /// 올데이 이벤트 전용 컨텍스트 메뉴. 올데이끼리만 위로/아래로 순서 변경.
  /// 캘린더는 _events 리스트 순서로 그리므로, 리스트 앞=위/ 뒤=아래. 위에 있는 건 '아래로 내리기'만.
  void _showAllDayContextMenu(Event event, Offset globalPosition) {
    final allDay = _getAllDayInDisplayOrder();
    if (allDay.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('하루 종일 일정이 하나뿐이라 순서를 바꿀 수 없습니다')));
      return;
    }
    final idx = allDay.indexOf(event);
    if (idx < 0) return;
    final canMoveUp = idx > 0;
    final canMoveDown = idx < allDay.length - 1;
    final canMoveToBottom = idx == 0 && allDay.length >= 2;
    final items = <PopupMenuItem<void>>[
      if (canMoveUp)
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.arrow_upward),
            title: Text('위로 올리기'),
          ),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _moveAllDayUp(event),
          ),
        ),
      if (canMoveDown)
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.arrow_downward),
            title: Text('아래로 내리기'),
          ),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _moveAllDayDown(event),
          ),
        ),
      if (canMoveToBottom)
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.vertical_align_bottom),
            title: Text('맨 아래로 내리기'),
          ),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _moveAllDayToBottom(event),
          ),
        ),
    ];
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: items,
    );
  }

  void _moveAllDayUp(Event event) {
    final allDay = _getAllDayInDisplayOrder();
    if (allDay.length < 2) return;
    final idx = allDay.indexOf(event);
    if (idx <= 0) return;
    final prev = allDay[idx - 1];
    final prevIdx = _events.indexOf(prev);
    final eventIdx = _events.indexOf(event);
    if (prevIdx < 0 || eventIdx < 0) return;
    _events.removeAt(eventIdx);
    _events.insert(prevIdx, event);
    _applyAllDayDisplayOrderFromListOrder();
    _persistDragOrder(_getAllDayInDisplayOrder());
    if (mounted) setState(() => _lastTappedEvent = null);
  }

  void _moveAllDayDown(Event event) {
    final allDay = _getAllDayInDisplayOrder();
    if (allDay.length < 2) return;
    final idx = allDay.indexOf(event);
    if (idx < 0 || idx >= allDay.length - 1) return;
    final next = allDay[idx + 1];
    final nextIdx = _events.indexOf(next);
    final eventIdx = _events.indexOf(event);
    if (nextIdx < 0 || eventIdx < 0) return;
    _events.removeAt(eventIdx);
    _events.insert(nextIdx, event);
    _applyAllDayDisplayOrderFromListOrder();
    _persistDragOrder(_getAllDayInDisplayOrder());
    if (mounted) setState(() => _lastTappedEvent = null);
  }

  void _moveAllDayToBottom(Event event) {
    final allDay = _getAllDayInDisplayOrder();
    if (allDay.length < 2) return;
    final idx = allDay.indexOf(event);
    if (idx < 0 || idx >= allDay.length - 1) return;
    final last = allDay.last;
    final eventIdx = _events.indexOf(event);
    if (eventIdx < 0) return;
    _events.removeAt(eventIdx);
    final newLastIdx = _events.indexOf(last);
    _events.insert(newLastIdx + 1, event);
    _applyAllDayDisplayOrderFromListOrder();
    _persistDragOrder(_getAllDayInDisplayOrder());
    if (mounted) setState(() => _lastTappedEvent = null);
  }

  /// _events 안 올데이 순서에 맞춰 displayOrder 부여 (앞=작은 값, 뒤=큰 값). 온에어/그리기 순서와 맞추기 위함.
  void _applyAllDayDisplayOrderFromListOrder() {
    final allDay = _getAllDayInDisplayOrder();
    for (var i = 0; i < allDay.length; i++) {
      allDay[i].displayOrder = i;
    }
  }

  void _moveEventUp(Event event) {
    final overlapping = _events
        .where(
          (e) =>
              e != event &&
              !e.isAllDay &&
              _timeRangesOverlap(event.from, event.to, e.from, e.to),
        )
        .toList();
    if (overlapping.isEmpty) return;
    overlapping.add(event);
    overlapping.sort(
      (a, b) => (b.displayOrder ?? 0).compareTo(a.displayOrder ?? 0),
    );
    final idx = overlapping.indexOf(event);
    if (idx <= 0) return;
    overlapping.removeAt(idx);
    overlapping.insert(idx - 1, event);
    var order = 1000 + overlapping.length - 1;
    for (final e in overlapping) {
      e.displayOrder = order--;
    }
    _persistDragOrder(overlapping);
    if (mounted) setState(() => _lastTappedEvent = null);
  }

  void _moveEventDown(Event event) {
    final overlapping = _events
        .where(
          (e) =>
              e != event &&
              !e.isAllDay &&
              _timeRangesOverlap(event.from, event.to, e.from, e.to),
        )
        .toList();
    if (overlapping.isEmpty) return;
    overlapping.add(event);
    overlapping.sort(
      (a, b) => (b.displayOrder ?? 0).compareTo(a.displayOrder ?? 0),
    );
    final idx = overlapping.indexOf(event);
    if (idx < 0 || idx >= overlapping.length - 1) return;
    overlapping.removeAt(idx);
    overlapping.insert(idx + 1, event);
    var order = 1000 + overlapping.length - 1;
    for (final e in overlapping) {
      e.displayOrder = order--;
    }
    _persistDragOrder(overlapping);
    if (mounted) setState(() => _lastTappedEvent = null);
  }

  void _moveEventToBottom(Event event) {
    final overlapping = _events
        .where(
          (e) =>
              e != event &&
              !e.isAllDay &&
              _timeRangesOverlap(event.from, event.to, e.from, e.to),
        )
        .toList();
    if (overlapping.isEmpty) return;
    overlapping.add(event);
    overlapping.sort(
      (a, b) => (b.displayOrder ?? 0).compareTo(a.displayOrder ?? 0),
    );
    overlapping.remove(event);
    overlapping.add(event);
    var order = 1000 + overlapping.length - 1;
    for (final e in overlapping) {
      e.displayOrder = order--;
    }
    _persistDragOrder(overlapping);
    if (mounted) setState(() => _lastTappedEvent = null);
  }

  /// 리사이즈 종료: 새 시작/종료로 Event 갱신 후 DB 저장.
  /// 반복 일정은 시리즈 전체에 같은 시간 패턴 적용(날짜는 시리즈 기준 유지).
  /// Syncfusion은 반복 리사이즈 시 시리즈 + 해당일 예외 발생 두 개를 만들므로,
  /// 시리즈를 찾아 시리즈만 갱신하고 예외 발생은 _events에서 제거해 중복 표시를 막는다.
  void _onAppointmentResizeEnd(AppointmentResizeEndDetails details) {
    final event = _getEventFromAppointment(details.appointment);
    if (event == null || details.startTime == null || details.endTime == null)
      return;
    final start = details.startTime!;
    final end = details.endTime!;

    // 반복 일정 리사이즈 시 details.appointment는 '예외 발생'(단일일)이다. 시리즈를 찾아 시리즈만 수정하고 예외는 제거.
    if (event.recurrenceRule == null || event.recurrenceRule!.isEmpty) {
      Event? series;
      for (final e in _events) {
        if (e != event &&
            e.eventName == event.eventName &&
            e.recurrenceRule != null &&
            e.recurrenceRule!.isNotEmpty) {
          series = e;
          break;
        }
      }
      if (series != null) {
        series.from = DateTime(
          series.from.year,
          series.from.month,
          series.from.day,
          start.hour,
          start.minute,
        );
        series.to = DateTime(
          series.to.year,
          series.to.month,
          series.to.day,
          end.hour,
          end.minute,
        );
        _events.remove(event);
        _persistEventAfterDragOrResize(series);
        return;
      }
    }

    if (event.recurrenceRule != null && event.recurrenceRule!.isNotEmpty) {
      // 반복 리사이즈 시 콜백에 넘어오는 건 예외 발생. 같은 이름·규칙인 다른 한 건(시리즈)이 있으면 시리즈만 갱신하고 예외 제거.
      Event? series;
      for (final e in _events) {
        if (e != event &&
            e.eventName == event.eventName &&
            e.recurrenceRule != null &&
            e.recurrenceRule!.isNotEmpty) {
          series = e;
          break;
        }
      }
      if (series != null) {
        series.from = DateTime(
          series.from.year,
          series.from.month,
          series.from.day,
          start.hour,
          start.minute,
        );
        series.to = DateTime(
          series.to.year,
          series.to.month,
          series.to.day,
          end.hour,
          end.minute,
        );
        _events.remove(event);
        _persistEventAfterDragOrResize(series);
        return;
      }
      event.from = DateTime(
        event.from.year,
        event.from.month,
        event.from.day,
        start.hour,
        start.minute,
      );
      event.to = DateTime(
        event.to.year,
        event.to.month,
        event.to.day,
        end.hour,
        end.minute,
      );
    } else {
      event.from = start;
      event.to = end;
    }
    _persistEventAfterDragOrResize(event);
  }

  Future<void> _persistEventAfterDragOrResize(Event event) async {
    try {
      debugPrint(
        '[DragEnd] persist: updating event id=${event.id} from=${event.from} to=${event.to}',
      );
      await EventRepository.instance.update(event);
      if (!mounted) return;
      _refreshCalendarDisplay();
      debugPrint('[DragEnd] persist: success');
    } catch (e, st) {
      debugPrint('[DragEnd] persist: error=$e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('일정 변경 저장 실패: $e')));
      }
    }
  }

  Future<void> _openEditEventDialog(Event event) async {
    final updated = await showEventEditDialog(
      context: context,
      existingEvent: event,
    );
    if (updated != null && mounted) _updateEvent(event, updated);
  }

  Future<void> _updateEvent(Event oldEvent, Event updatedEvent) async {
    final index = _events.indexOf(oldEvent);
    if (index < 0) return;
    updatedEvent.id = oldEvent.id;
    updatedEvent.planId = oldEvent.planId ?? widget.planId;
    updatedEvent.displayOrder = oldEvent.displayOrder;
    try {
      await EventRepository.instance.update(updatedEvent);
      if (!mounted) return;
      _events[index] = updatedEvent;
      _refreshCalendarDisplay();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('수정 저장 실패: $e')));
      }
    }
  }

  Future<void> _removeEvent(Event event) async {
    try {
      await EventRepository.instance.delete(event);
      if (!mounted) return;
      _events.remove(event);
      _refreshCalendarDisplay();
      _lastTappedEvent = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Future<void> _showDeleteConfirmDialog(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text(
          '"${event.eventName}" 일정을 지우시겠습니까?',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _removeEvent(event);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.delete &&
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_lastTappedEvent == null) return KeyEventResult.ignored;
    _showDeleteConfirmDialog(_lastTappedEvent!);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: InkWell(
            onTap: _editPlanName,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _planName ?? '방송계획',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: '언어 전환 (EN/KO)',
              icon: Consumer(
                builder: (context, ref, _) {
                  final locale = ref.watch(localeProvider);
                  return Text(
                    locale.languageCode == 'ko' ? 'EN' : 'KO',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  );
                },
              ),
              onPressed: () {
                ref.read(localeProvider.notifier).toggle();
              },
            ),
            IconButton(
              tooltip: '라이트/다크 테마 전환',
              icon: Consumer(
                builder: (context, ref, _) {
                  final mode = ref.watch(themeModeProvider);
                  final isDark = mode == ThemeMode.dark;
                  return Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    size: 24,
                  );
                },
              ),
              onPressed: () {
                ref.read(themeModeProvider.notifier).toggle();
              },
            ),
            IconButton(
              tooltip: '캘린더 옵션',
              icon: const Icon(Icons.settings_outlined, size: 24),
              onPressed: _showCalendarOptions,
            ),
            IconButton(
              tooltip: '전체 데이터 JSON 보기',
              icon: const Icon(Icons.data_object, size: 24),
              onPressed: _showAllDataPopup,
            ),
            PopupMenuButton<CalendarView>(
              tooltip: '뷰 선택',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.view_agenda, size: 20),
                    const SizedBox(width: 8),
                    Text(_viewLabels[_currentView] ?? _currentView.name),
                  ],
                ),
              ),
              onSelected: (view) {
                setState(() => _currentView = view);
                _calendarController.view = view;
                if (_viewChangeMovesToToday) {
                  final today = DateTime.now();
                  _calendarController.displayDate = today;
                  _calendarController.selectedDate = today;
                }
              },
              itemBuilder: (context) => CalendarView.values
                  .map(
                    (view) => PopupMenuItem<CalendarView>(
                      value: view,
                      child: Row(
                        children: [
                          if (_currentView == view)
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.check, color: Colors.blue),
                            )
                          else
                            const SizedBox(width: 36),
                          Text(_viewLabels[view] ?? view.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '일정을 불러오지 못했습니다.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loadError!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _loadEvents();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMinMaxDateBar(),
                  Expanded(
                    child: Listener(
                      onPointerDown: (e) {
                        if (e.buttons == 2) {
                          final RenderObject? ro = context.findRenderObject();
                          final Offset globalPos = ro is RenderBox
                              ? ro.localToGlobal(e.localPosition)
                              : e.position;
                          // 우클릭한 위치에 일정이 있으면 그 일정을 선택하고 위/아래 메뉴 표시
                          final details = _calendarController
                              .getCalendarDetailsAtOffset
                              ?.call(e.localPosition);
                          if (details != null &&
                              details.targetElement ==
                                  CalendarElement.appointment &&
                              details.appointments != null &&
                              details.appointments!.isNotEmpty) {
                            final event = _findEventFromTapped(
                              details.appointments!.first,
                            );
                            if (event != null) {
                              setState(() => _lastTappedEvent = event);
                              _showEventContextMenu(event, globalPos);
                              return;
                            }
                          }
                          // 슬롯(빈 셀) 우클릭: 항상 새 이벤트 메뉴. 겹침에서 선택된 일정이 있어도 슬롯을 눌렀으면 날짜 메뉴.
                          if (details != null &&
                              details.targetElement ==
                                  CalendarElement.calendarCell &&
                              details.date != null) {
                            final date = details.date!;
                            _contextMenuDate = date;
                            _calendarController.selectedDate = date;
                            if (mounted) setState(() {});
                            _showContextMenu(date, globalPos);
                            return;
                          }
                          // 그 외(헤더 등)이고, 선택된 일정이 있으면 그 일정 순서 메뉴(올데이/비올데이 각각 해당 메뉴)
                          if (_lastTappedEvent != null) {
                            _showEventContextMenu(_lastTappedEvent!, globalPos);
                          } else {
                            final date =
                                _contextMenuDate ??
                                _calendarController.displayDate ??
                                DateTime.now();
                            _showContextMenu(date, globalPos);
                          }
                        }
                      },
                      child: SfCalendar(
                        key: ValueKey<String>(
                          '$_currentView-$_calendarDataKey',
                        ),
                        controller: _calendarController,
                        dataSource: _eventDataSource,
                        view: _currentView,
                        minDate: _calendarMinDate,
                        maxDate: _calendarMaxDate,
                        //showTodayButton: true,
                        showNavigationArrow: true,
                        showDatePickerButton: true,
                        todayHighlightColor: Colors.blueAccent,
                        /*
                        viewHeaderStyle: ViewHeaderStyle(
                          dateTextStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                          dayTextStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        */
                        currentTimeIndicatorLineWidth: 2,
                        currentTimeIndicatorCircleRadius: 6,
                        currentTimeIndicatorColor: Colors.red,
                        currentTimeIndicatorTextColor: Colors.white,

                        timeSlotViewSettings: TimeSlotViewSettings(
                          timeIntervalWidth: _timeIntervalWidth,
                          timeIntervalHeight: _timeIntervalHeight,
                          timelineAppointmentHeight: _timelineAppointmentHeight,
                          //dateFormat: 'M월 d일',
                          //dayFormat: 'EE',
                        ),
                        monthViewSettings: MonthViewSettings(showAgenda: true),

                        allowDragAndDrop: false,
                        allowAppointmentResize: true,
                        onDragEnd: _onAppointmentDragEnd,
                        onAppointmentResizeEnd: _onAppointmentResizeEnd,
                        appointmentBuilder: _buildAppointmentWithStackOpacity,

                        onTap: (details) {
                          if (details.date != null &&
                              details.targetElement ==
                                  CalendarElement.calendarCell) {
                            _contextMenuDate = details.date;
                          }
                          if (details.targetElement ==
                                  CalendarElement.appointment &&
                              details.appointments != null &&
                              details.appointments!.isNotEmpty) {
                            final tapped = details.appointments!.first;
                            final event = _findEventFromTapped(tapped);
                            if (event != null) {
                              final now = DateTime.now();
                              if (_isSameEvent(_lastTappedEvent, event) &&
                                  _lastTapTime != null &&
                                  now.difference(_lastTapTime!) <
                                      _doubleTapInterval) {
                                _lastTapTime = null;
                                _lastTappedEvent = null;
                                _openEditEventDialog(event);
                              } else {
                                _lastTappedEvent = event;
                                _lastTapTime = now;
                              }
                            }
                          } else {
                            _lastTappedEvent = null;
                          }
                        },
                        onLongPress: (details) {
                          if (details.date != null &&
                              details.targetElement ==
                                  CalendarElement.calendarCell) {
                            final RenderObject? ro = context.findRenderObject();
                            final Offset position = ro is RenderBox
                                ? ro.localToGlobal(ro.size.center(Offset.zero))
                                : const Offset(100, 100);
                            _showContextMenu(details.date!, position);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
        floatingActionButton: _isLoading || _loadError != null
            ? null
            : FloatingActionButton.extended(
                onPressed: _onFabNewEvent,
                icon: const Icon(Icons.add_rounded),
                label: const Text('새 이벤트'),
                tooltip: '새 이벤트 만들기',
              ),
      ),
    );
  }
}
