/// 방송 계획 (이름 + 캘린더 표시 기간)
class BroadcastPlan {
  BroadcastPlan({
    this.id,
    required this.name,
    required this.minDate,
    required this.maxDate,
  });

  int? id;
  String name;
  DateTime minDate;
  DateTime maxDate;

  BroadcastPlan copyWith({
    int? id,
    String? name,
    DateTime? minDate,
    DateTime? maxDate,
  }) {
    return BroadcastPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      minDate: minDate ?? this.minDate,
      maxDate: maxDate ?? this.maxDate,
    );
  }

  @override
  String toString() =>
      'BroadcastPlan(id: $id, name: $name, minDate: $minDate, maxDate: $maxDate)';
}
