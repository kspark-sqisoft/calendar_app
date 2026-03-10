import 'package:calendar_app/event_data_source.dart';
import 'package:calendar_app/event_edit_dialog.dart';
import 'package:calendar_app/event_repository.dart';
import 'package:calendar_app/extensions/string_color_extension.dart';
import 'package:calendar_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class GettingStarted extends StatefulWidget {
  const GettingStarted({super.key});

  @override
  State<GettingStarted> createState() => _GettingStartedState();
}

class _GettingStartedState extends State<GettingStarted> {
  late CalendarController _calendarController;
  late EventDataSource _eventDataSource;
  final List<Event> _events = [];
  bool _isLoading = true;
  String? _loadError;

  /// 우클릭 메뉴용: 마지막으로 탭한 셀의 날짜 (우클릭 시 이 날짜에 이벤트 생성)
  DateTime? _contextMenuDate;

  /// 더블클릭 감지: 같은 일정을 짧은 간격에 두 번 탭하면 수정 창
  DateTime? _lastTapTime;
  Event? _lastTappedEvent;
  static const _doubleTapInterval = Duration(milliseconds: 400);

  /// 현재 캘린더 뷰 (기본: timelineDay)
  CalendarView _currentView = CalendarView.timelineDay;

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
    _calendarController = CalendarController();
    _calendarController.view = CalendarView.timelineDay;
    _eventDataSource = EventDataSource(_events);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final list = await EventRepository.instance.getAll();
      logger.d('Loaded events: $list'.toGreen);
      if (mounted) {
        setState(() {
          _events.clear();
          _events.addAll(list);
          _isLoading = false;
          _loadError = null;
        });
        _eventDataSource.notifyListeners(
          CalendarDataSourceAction.reset,
          _eventDataSource.appointments!,
        );
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
    final initialFrom = DateTime(date.year, date.month, date.day, date.hour, 0);
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
              if (event != null && mounted) _addEvent(event);
            });
          },
        ),
      ],
    );
  }

  Future<void> _addEvent(Event event) async {
    try {
      final saved = await EventRepository.instance.insert(event);
      if (!mounted) return;
      _events.add(saved);
      _eventDataSource.notifyListeners(CalendarDataSourceAction.add, <Event>[
        saved,
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  /// 탭한 요소에서 우리 Event 찾기 (Syncfusion이 Appointment로 넘기면 _events에서 매칭)
  Event? _findEventFromTapped(dynamic tapped) {
    if (tapped is Event) return tapped;
    if (tapped is Appointment) {
      for (final e in _events) {
        if (e.from == tapped.startTime &&
            e.to == tapped.endTime &&
            e.eventName == tapped.subject) {
          return e;
        }
      }
    }
    return null;
  }

  /// 드래그/리사이즈 콜백에서 appointment → Event 변환 (동일 참조 또는 매칭)
  Event? _getEventFromAppointment(dynamic appointment) {
    if (appointment is Event) return appointment;
    return _findEventFromTapped(appointment);
  }

  /// 드래그 종료: 새 시간으로 Event 갱신 후 DB 저장
  void _onAppointmentDragEnd(AppointmentDragEndDetails details) {
    final event = _getEventFromAppointment(details.appointment);
    if (event == null || details.droppingTime == null) return;
    final duration = event.to.difference(event.from);
    final newFrom = details.droppingTime!;
    final newTo = newFrom.add(duration);
    event.from = newFrom;
    event.to = newTo;
    _persistEventAfterDragOrResize(event);
  }

  /// 리사이즈 종료: 새 시작/종료로 Event 갱신 후 DB 저장
  void _onAppointmentResizeEnd(AppointmentResizeEndDetails details) {
    final event = _getEventFromAppointment(details.appointment);
    if (event == null || details.startTime == null || details.endTime == null) return;
    event.from = details.startTime!;
    event.to = details.endTime!;
    _persistEventAfterDragOrResize(event);
  }

  Future<void> _persistEventAfterDragOrResize(Event event) async {
    try {
      await EventRepository.instance.update(event);
      if (!mounted) return;
      _eventDataSource.notifyListeners(
        CalendarDataSourceAction.reset,
        _eventDataSource.appointments!,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일정 변경 저장 실패: $e')),
        );
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
    try {
      await EventRepository.instance.update(updatedEvent);
      if (!mounted) return;
      _events[index] = updatedEvent;
      _eventDataSource.notifyListeners(
        CalendarDataSourceAction.reset,
        _eventDataSource.appointments!,
      );
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
      _eventDataSource.notifyListeners(CalendarDataSourceAction.remove, <Event>[
        event,
      ]);
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
          title: const Text('캘린더'),
          actions: [
            PopupMenuButton<CalendarView>(
              tooltip: '뷰 선택',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            : Listener(
                onPointerDown: (event) {
                  if (event.buttons == 2) {
                    final date =
                        _contextMenuDate ??
                        _calendarController.displayDate ??
                        DateTime.now();
                    _showContextMenu(date, event.position);
                  }
                },
                child: SfCalendar(
                  key: ValueKey<CalendarView>(_currentView),
                  controller: _calendarController,
                  dataSource: _eventDataSource,
                  view: _currentView,
                  showTodayButton: true,
                  showNavigationArrow: true,
                  todayHighlightColor: Colors.blueAccent,
                  allowDragAndDrop: true,
                  allowAppointmentResize: true,
                  onDragEnd: _onAppointmentDragEnd,
                  onAppointmentResizeEnd: _onAppointmentResizeEnd,

                  onTap: (details) {
                    if (details.date != null &&
                        details.targetElement == CalendarElement.calendarCell) {
                      _contextMenuDate = details.date;
                    }
                    if (details.targetElement == CalendarElement.appointment &&
                        details.appointments != null &&
                        details.appointments!.isNotEmpty) {
                      final tapped = details.appointments!.first;
                      final event = _findEventFromTapped(tapped);
                      if (event != null) {
                        final now = DateTime.now();
                        if (_lastTappedEvent == event &&
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
                        details.targetElement == CalendarElement.calendarCell) {
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
    );
  }
}
