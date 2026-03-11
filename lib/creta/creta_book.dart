/// 크레타북 모델 (로컬 DB 저장)
class CretaBook {
  CretaBook({
    this.id,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int? id;
  String name;
  DateTime createdAt;

  CretaBook copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
  }) {
    return CretaBook(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'CretaBook(id: $id, name: $name, createdAt: $createdAt)';
}
