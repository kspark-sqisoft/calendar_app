/// 방송 계획 (이름 + 캘린더 표시 기간 + 지정 디바이스 목록)
class BroadcastPlan {
  BroadcastPlan({
    this.id,
    required this.name,
    required this.minDate,
    required this.maxDate,
    List<int>? deviceIds,
  }) : deviceIds = deviceIds ?? [];

  int? id;
  String name;
  DateTime minDate;
  DateTime maxDate;

  /// 방송할 디바이스 ID 목록 (여러 개 지정 가능)
  List<int> deviceIds;

  BroadcastPlan copyWith({
    int? id,
    String? name,
    DateTime? minDate,
    DateTime? maxDate,
    List<int>? deviceIds,
  }) {
    return BroadcastPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      minDate: minDate ?? this.minDate,
      maxDate: maxDate ?? this.maxDate,
      deviceIds: deviceIds ?? this.deviceIds,
    );
  }

  @override
  String toString() =>
      'BroadcastPlan(id: $id, name: $name, minDate: $minDate, maxDate: $maxDate, deviceIds: $deviceIds)';
}
