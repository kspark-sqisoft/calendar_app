import 'dart:async';

import 'package:calendar_app/calendar/event_data_source.dart';
import 'package:calendar_app/calendar/event_repository.dart';
import 'package:calendar_app/plan/broadcast_plan.dart';
import 'package:calendar_app/plan/plan_preview_utils.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

/// 방송 계획 미리보기 팝업: 타임라인 주 기본, 뷰 변경 가능, 겹침 시 재생할 것(젤 아래)만 표시
class PlanPreviewDialog extends StatefulWidget {
  const PlanPreviewDialog({super.key, required this.plan});

  final BroadcastPlan plan;

  @override
  State<PlanPreviewDialog> createState() => _PlanPreviewDialogState();
}

class _PlanPreviewDialogState extends State<PlanPreviewDialog>
    with SingleTickerProviderStateMixin {
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

  List<Event> _filteredEvents = [];
  bool _loading = true;
  String? _error;
  CalendarView _view = CalendarView.timelineWeek;
  late CalendarController _controller;
  late EventDataSource _dataSource;
  double _timeIntervalWidth = 75;
  double _timeIntervalHeight = 60;
  double _timelineAppointmentHeight = 60;

  late AnimationController _onAirBlinkController;
  late Animation<double> _onAirBlinkAnimation;
  Timer? _onAirUpdateTimer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _controller = CalendarController();
    _controller.view = CalendarView.timelineWeek;
    _controller.displayDate = now;
    _controller.selectedDate = now;
    _dataSource = EventDataSource(_filteredEvents);
    _onAirBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _onAirBlinkAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _onAirBlinkController, curve: Curves.easeInOut),
    );
    _onAirUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadSettings();
    _load();
  }

  @override
  void dispose() {
    _onAirUpdateTimer?.cancel();
    _onAirBlinkController.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isOnAirForOccurrence(DateTime start, DateTime end) {
    final now = DateTime.now();
    if (!_isSameDay(start, now)) return false;
    return !now.isBefore(start) && now.isBefore(end);
  }

  /// 오늘 해당 이벤트 회차가 있으면 (시작, 종료) 반환, 없으면 null.
  (DateTime start, DateTime end)? _occurrenceOnToday(Event e) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (e.recurrenceRule == null || e.recurrenceRule!.isEmpty) {
      if (!_isSameDay(e.from, now)) return null;
      if (e.isAllDay) return (e.from, e.to);
      return (
        DateTime(
          today.year,
          today.month,
          today.day,
          e.from.hour,
          e.from.minute,
        ),
        DateTime(today.year, today.month, today.day, e.to.hour, e.to.minute),
      );
    }
    final ex = e.recurrenceExceptionDates;
    if (ex != null &&
        ex.any(
          (d) =>
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day,
        )) {
      return null;
    }
    final r = e.recurrenceRule!.toUpperCase();
    if (r.contains('FREQ=DAILY')) {
      if (e.isAllDay) return (today, today.add(const Duration(days: 1)));
      return (
        DateTime(
          today.year,
          today.month,
          today.day,
          e.from.hour,
          e.from.minute,
        ),
        DateTime(today.year, today.month, today.day, e.to.hour, e.to.minute),
      );
    }
    if (r.contains('FREQ=WEEKLY') && e.from.weekday == now.weekday) {
      if (e.isAllDay) return (today, today.add(const Duration(days: 1)));
      return (
        DateTime(
          today.year,
          today.month,
          today.day,
          e.from.hour,
          e.from.minute,
        ),
        DateTime(today.year, today.month, today.day, e.to.hour, e.to.minute),
      );
    }
    if (r.contains('FREQ=MONTHLY') && e.from.day == now.day) {
      if (e.isAllDay) return (today, today.add(const Duration(days: 1)));
      return (
        DateTime(
          today.year,
          today.month,
          today.day,
          e.from.hour,
          e.from.minute,
        ),
        DateTime(today.year, today.month, today.day, e.to.hour, e.to.minute),
      );
    }
    return null;
  }

  bool _hasTimeBasedOnAirNow() {
    final now = DateTime.now();
    for (final e in _filteredEvents) {
      if (e.isAllDay) continue;
      final occ = _occurrenceOnToday(e);
      if (occ == null) continue;
      if (!now.isBefore(occ.$1) && now.isBefore(occ.$2)) return true;
    }
    return false;
  }

  DateTime _getOccurrenceDate(dynamic appointment, [DateTime? detailsDate]) {
    if (appointment is Appointment) return appointment.startTime;
    if (appointment is Event && detailsDate != null) return detailsDate;
    if (appointment is Event) return appointment.from;
    return DateTime.now();
  }

  (DateTime start, DateTime end) _getOccurrenceTimeRange(
    dynamic appointment,
    Event event,
    DateTime? detailsDate,
  ) {
    if (appointment is Appointment) {
      return (appointment.startTime, appointment.endTime);
    }
    final date = detailsDate ?? event.from;
    if (event.isAllDay) return (event.from, event.to);
    return (
      DateTime(
        date.year,
        date.month,
        date.day,
        event.from.hour,
        event.from.minute,
      ),
      DateTime(date.year, date.month, date.day, event.to.hour, event.to.minute),
    );
  }

  Event? _findEvent(dynamic appointment) {
    if (appointment is Event) {
      final idx = _filteredEvents.indexOf(appointment);
      if (idx >= 0) return appointment;
      if (appointment.id != null) {
        for (final e in _filteredEvents) {
          if (e.id == appointment.id) return e;
        }
      }
      if (appointment.recurrenceRule != null) {
        for (final e in _filteredEvents) {
          if (e.recurrenceRule != null &&
              e.eventName == appointment.eventName) {
            return e;
          }
        }
      }
    }
    return null;
  }

  /// 현재 방송 중인 일정 이름 (시간 기반 또는 오늘 하루종일 중 하나)
  String? get _currentOnAirEventName {
    final now = DateTime.now();
    for (final e in _filteredEvents) {
      if (e.isAllDay) {
        final occ = _occurrenceOnToday(e);
        if (occ != null && !_hasTimeBasedOnAirNow()) return e.eventName;
      } else {
        final occ = _occurrenceOnToday(e);
        if (occ != null && !now.isBefore(occ.$1) && now.isBefore(occ.$2)) {
          return e.eventName;
        }
      }
    }
    return null;
  }

  Widget _buildAppointment(
    BuildContext context,
    CalendarAppointmentDetails details,
  ) {
    if (details.appointments.isEmpty) return const SizedBox.shrink();
    final event = _findEvent(details.appointments.first);
    if (event == null) return const SizedBox.shrink();
    final occurrenceDate = _getOccurrenceDate(
      details.appointments.first,
      details.date,
    );
    final (occurrenceStart, occurrenceEnd) = _getOccurrenceTimeRange(
      details.appointments.first,
      event,
      details.date,
    );
    final isOnAir = event.isAllDay
        ? (_isSameDay(occurrenceDate, DateTime.now()) &&
              !_hasTimeBasedOnAirNow())
        : _isOnAirForOccurrence(occurrenceStart, occurrenceEnd);
    final isRecurring =
        event.recurrenceRule != null && event.recurrenceRule!.isNotEmpty;
    final content = Container(
      width: details.bounds.width,
      height: details.bounds.height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: event.background,
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
              child: Icon(Icons.autorenew, size: 14, color: Colors.white),
            ),
        ],
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

  Future<void> _loadSettings() async {
    try {
      final w = await EventRepository.instance.getTimeIntervalWidth();
      final h = await EventRepository.instance.getTimeIntervalHeight();
      final apptH = await EventRepository.instance
          .getTimelineAppointmentHeight();
      if (mounted) {
        setState(() {
          _timeIntervalWidth = w.toDouble();
          _timeIntervalHeight = h.toDouble();
          _timelineAppointmentHeight = apptH.toDouble();
        });
      }
    } catch (_) {
      // 설정 로드 실패 시 기본값 유지 (75, 60, 60)
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    if (widget.plan.id == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '계획을 불러올 수 없습니다.';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await EventRepository.instance.getAllByPlanId(
        widget.plan.id!,
      );
      final filtered = PlanPreviewUtils.onlyBottomInOverlap(list);
      if (!mounted) return;
      setState(() {
        _filteredEvents = filtered;
        _loading = false;
      });
      _dataSource.appointments = _filteredEvents;
      _dataSource.notifyListeners(
        CalendarDataSourceAction.reset,
        _filteredEvents,
      );
    } catch (e, stackTrace) {
      assert(() {
        // 디버그 빌드에서만 스택 출력
        debugPrint('PlanPreviewDialog._load error: $e\n$stackTrace');
        return true;
      }());
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is Exception
              ? '일정을 불러오지 못했습니다.\n${e.toString()}'
              : '일정을 불러오지 못했습니다.';
        });
      }
    }
  }

  void _setView(CalendarView view) {
    setState(() {
      _view = view;
      _controller.view = view;
    });
  }

  void _goToToday() {
    final today = DateTime.now();
    _controller.displayDate = today;
    _controller.selectedDate = today;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.preview_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.plan.name} · 미리보기',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<CalendarView>(
                    tooltip: '뷰 변경',
                    initialValue: _view,
                    onSelected: _setView,
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
                          Text(_viewLabels[_view] ?? _view.name),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => CalendarView.values
                        .map(
                          (v) => PopupMenuItem<CalendarView>(
                            value: v,
                            child: Row(
                              children: [
                                if (_view == v)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 32),
                                Text(_viewLabels[v] ?? v.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '오늘로 가기',
                    child: TextButton.icon(
                      onPressed: _loading || _error != null ? null : _goToToday,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('오늘로 가기'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '닫기',
                  ),
                ],
              ),
              if (!_loading &&
                  _error == null &&
                  _currentOnAirEventName != null) ...[
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _onAirBlinkAnimation,
                  builder: (context, child) => Opacity(
                    opacity: _onAirBlinkAnimation.value,
                    child: child,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade700, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.live_tv_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '현재 방송 중',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentOnAirEventName!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '불러오는 중…',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SfCalendar(
                          controller: _controller,
                          dataSource: _dataSource,
                          view: _view,
                          minDate: widget.plan.minDate,
                          maxDate: widget.plan.maxDate,
                          showNavigationArrow: true,
                          showDatePickerButton: true,
                          todayHighlightColor: colorScheme.primary,
                          currentTimeIndicatorColor: colorScheme.error,
                          currentTimeIndicatorLineWidth: 2,
                          currentTimeIndicatorCircleRadius: 6,
                          currentTimeIndicatorTextColor: colorScheme.onError,
                          timeSlotViewSettings: TimeSlotViewSettings(
                            timeIntervalWidth: _timeIntervalWidth,
                            timeIntervalHeight: _timeIntervalHeight,
                            timelineAppointmentHeight:
                                _timelineAppointmentHeight,
                          ),
                          monthViewSettings: const MonthViewSettings(
                            showAgenda: true,
                          ),
                          allowDragAndDrop: false,
                          allowAppointmentResize: false,
                          appointmentBuilder: _buildAppointment,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 미리보기 다이얼로그 표시
Future<void> showPlanPreviewDialog(
  BuildContext context, {
  required BroadcastPlan plan,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => PlanPreviewDialog(plan: plan),
  );
}
