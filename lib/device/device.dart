/// 디바이스 모델 (로컬 DB 저장)
class Device {
  Device({
    this.id,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int? id;
  String name;
  DateTime createdAt;

  Device copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Device(id: $id, name: $name, createdAt: $createdAt)';
}
