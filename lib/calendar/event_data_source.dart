import 'package:calendar_app/creta/creta_book.dart';
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
      planId: customData.planId,
      eventName: appointment.subject,
      from: appointment.startTime,
      to: appointment.endTime,
      background: appointment.color,
      isAllDay: appointment.isAllDay,
      recurrenceRule: customData.recurrenceRule,
      recurrenceExceptionDates: customData.recurrenceExceptionDates,
      recurrenceExceptionWeekdays: customData.recurrenceExceptionWeekdays,
      displayOrder: customData.displayOrder,
      cretaBooks: customData.cretaBooks,
    );
  }

  /// 타임라인에서 겹치는 이벤트 순서: 값이 클수록 위에 그림 (온종일 제외).
  /// null이면 0으로 취급해, 드래그한 쪽(-1 또는 1 등)과 비교되도록 함.
  @override
  int? getDisplayOrder(dynamic appointmentData) {
    if (appointmentData is Event) return appointmentData.displayOrder ?? 0;
    return null;
  }
}

class Event {
  Event({
    this.id,
    this.planId,
    required this.eventName,
    required this.from,
    required this.to,
    required this.background,
    required this.isAllDay,
    this.recurrenceRule,
    this.recurrenceExceptionDates,
    this.recurrenceExceptionWeekdays,
    this.displayOrder,
    this.cretaBooks,
  });

  /// DB 저장용 primary key (로컬 저장 시 설정됨)
  int? id;

  /// 방송 계획 ID (어느 계획의 일정인지)
  int? planId;
  String eventName;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;

  /// iCal RRULE: null = 한 번만, 'FREQ=DAILY' = 매일, 'FREQ=WEEKLY' = 매주, 'FREQ=MONTHLY' = 매월
  String? recurrenceRule;

  /// 반복 일정에서 제외할 날짜들 (이 날짜에는 일정이 표시되지 않음) recurrenceRule(반복 일정)이 있을 때만 사용
  List<DateTime>? recurrenceExceptionDates;

  /// 반복 일정에서 제외할 요일 (1=월 … 7=일). 이 요일에는 일정이 표시되지 않음. recurrenceRule이 있을 때만 사용.
  List<int>? recurrenceExceptionWeekdays;

  /// 타임라인에서 겹칠 때 그리는 순서 (큰 값일수록 위). 드래그로 이동한 이벤트가 위로 가도록 사용. 온종일 제외.
  int? displayOrder;

  /// 방송할 크레타북 목록 (멀티 선택)
  List<CretaBook>? cretaBooks;

  @override
  String toString() {
    return 'Event(id: $id, eventName: $eventName, from: $from, to: $to, background: $background, isAllDay: $isAllDay, recurrenceRule: $recurrenceRule, recurrenceExceptionDates: $recurrenceExceptionDates, recurrenceExceptionWeekdays: $recurrenceExceptionWeekdays, displayOrder: $displayOrder, cretaBooks: $cretaBooks)';
  }
}
