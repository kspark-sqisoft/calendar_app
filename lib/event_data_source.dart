import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class EventDataSource extends CalendarDataSource<Event> {
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

  /// 드래그/리사이즈 후 라이브러리가 Syncfusion Appointment → 우리 Event 로 변환할 때 호출
  @override
  Event? convertAppointmentToObject(Event customData, Appointment appointment) {
    return Event(
      id: customData.id,
      eventName: appointment.subject,
      from: appointment.startTime,
      to: appointment.endTime,
      background: appointment.color,
      isAllDay: appointment.isAllDay,
      recurrenceRule: customData.recurrenceRule,
      recurrenceExceptionDates: customData.recurrenceExceptionDates,
    );
  }
}

class Event {
  Event({
    this.id,
    required this.eventName,
    required this.from,
    required this.to,
    required this.background,
    required this.isAllDay,
    this.recurrenceRule,
    this.recurrenceExceptionDates,
  });

  /// DB 저장용 primary key (로컬 저장 시 설정됨)
  int? id;
  String eventName;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;

  /// iCal RRULE: null = 한 번만, 'FREQ=DAILY' = 매일, 'FREQ=WEEKLY' = 매주, 'FREQ=MONTHLY' = 매월
  String? recurrenceRule;

  /// 반복 일정에서 제외할 날짜들 (이 날짜에는 일정이 표시되지 않음) recurrenceRule(반복 일정)이 있을 때만 사용
  List<DateTime>? recurrenceExceptionDates;

  @override
  String toString() {
    return 'Event(id: $id, eventName: $eventName, from: $from, to: $to, background: $background, isAllDay: $isAllDay, recurrenceRule: $recurrenceRule, recurrenceExceptionDates: $recurrenceExceptionDates)';
  }
}
