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

class _PlanPreviewDialogState extends State<PlanPreviewDialog> {
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

  @override
  void initState() {
    super.initState();
    _controller = CalendarController();
    _controller.view = CalendarView.timelineWeek;
    _dataSource = EventDataSource(_filteredEvents);
    _loadSettings();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final w = await EventRepository.instance.getTimeIntervalWidth();
    final h = await EventRepository.instance.getTimeIntervalHeight();
    final apptH = await EventRepository.instance.getTimelineAppointmentHeight();
    if (mounted) {
      setState(() {
        _timeIntervalWidth = w.toDouble();
        _timeIntervalHeight = h.toDouble();
        _timelineAppointmentHeight = apptH.toDouble();
      });
    }
  }

  Future<void> _load() async {
    if (widget.plan.id == null) {
      setState(() {
        _loading = false;
        _error = '계획을 불러올 수 없습니다.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await EventRepository.instance.getAllByPlanId(widget.plan.id!);
      final filtered = PlanPreviewUtils.onlyBottomInOverlap(list);
      if (mounted) {
        setState(() {
          _filteredEvents = filtered;
          _loading = false;
        });
        _dataSource.appointments = _filteredEvents;
        _dataSource.notifyListeners(CalendarDataSourceAction.reset, _filteredEvents);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.preview_rounded, color: colorScheme.primary, size: 28),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                    child: Icon(Icons.check, color: Colors.blue, size: 20),
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
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '닫기',
                  ),
                ],
              ),
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
                                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
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
                              timeSlotViewSettings: TimeSlotViewSettings(
                                timeIntervalWidth: _timeIntervalWidth,
                                timeIntervalHeight: _timeIntervalHeight,
                                timelineAppointmentHeight: _timelineAppointmentHeight,
                              ),
                              monthViewSettings: const MonthViewSettings(showAgenda: true),
                              allowDragAndDrop: false,
                              allowAppointmentResize: false,
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
Future<void> showPlanPreviewDialog(BuildContext context, {required BroadcastPlan plan}) {
  return showDialog<void>(
    context: context,
    builder: (context) => PlanPreviewDialog(plan: plan),
  );
}
