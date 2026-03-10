import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class EventDataSource extends CalendarDataSource {
  EventDataSource(List<Event> source) {
    appointments = source;
  }
  @override
  DateTime getStartTime(int index) {
    return appointments![index].from;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments![index].to;
  }

  @override
  String getSubject(int index) {
    return appointments![index].eventName;
  }

  @override
  Color getColor(int index) {
    return appointments![index].background;
  }

  @override
  bool isAllDay(int index) {
    return appointments![index].isAllDay;
  }

  @override
  String? getRecurrenceRule(int index) {
    return appointments![index].recurrenceRule;
  }

  @override
  List<DateTime>? getRecurrenceExceptionDates(int index) {
    return appointments![index].recurrenceExceptionDates;
  }
}

class Event {
  Event({
    required this.eventName,
    required this.from,
    required this.to,
    required this.background,
    required this.isAllDay,
    this.recurrenceRule,
    this.recurrenceExceptionDates,
  });

  String eventName;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;

  /// iCal RRULE: null = 한 번만, 'FREQ=DAILY' = 매일, 'FREQ=WEEKLY' = 매주, 'FREQ=MONTHLY' = 매월
  String? recurrenceRule;

  /// 반복 일정에서 제외할 날짜들 (이 날짜에는 일정이 표시되지 않음) recurrenceRule(반복 일정)이 있을 때만 사용
  List<DateTime>? recurrenceExceptionDates;
}
