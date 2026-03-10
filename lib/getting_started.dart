import 'package:calendar_app/event_data_source.dart';
import 'package:calendar_app/event_edit_dialog.dart';
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

  /// 우클릭 메뉴용: 마지막으로 탭한 셀의 날짜 (우클릭 시 이 날짜에 이벤트 생성)
  DateTime? _contextMenuDate;

  /// 더블클릭 감지: 같은 일정을 짧은 간격에 두 번 탭하면 수정 창
  DateTime? _lastTapTime;
  Event? _lastTappedEvent;
  static const _doubleTapInterval = Duration(milliseconds: 400);

  @override
  void initState() {
    _calendarController = CalendarController();
    _eventDataSource = EventDataSource(_events);
    super.initState();
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

  void _addEvent(Event event) {
    _events.add(event);
    _eventDataSource.notifyListeners(CalendarDataSourceAction.add, <Event>[
      event,
    ]);
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

  Future<void> _openEditEventDialog(Event event) async {
    final updated = await showEventEditDialog(
      context: context,
      existingEvent: event,
    );
    if (updated != null && mounted) _updateEvent(event, updated);
  }

  void _updateEvent(Event oldEvent, Event updatedEvent) {
    final index = _events.indexOf(oldEvent);
    if (index < 0) return;
    _events[index] = updatedEvent;
    _eventDataSource.notifyListeners(
      CalendarDataSourceAction.reset,
      _eventDataSource.appointments!,
    );
  }

  void _removeEvent(Event event) {
    _events.remove(event);
    _eventDataSource.notifyListeners(CalendarDataSourceAction.remove, <Event>[
      event,
    ]);
    _lastTappedEvent = null;
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
        body: Listener(
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
            controller: _calendarController,
            dataSource: _eventDataSource,
            view: CalendarView.timelineDay,
            showTodayButton: true,
            showNavigationArrow: true,
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
                      now.difference(_lastTapTime!) < _doubleTapInterval) {
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
