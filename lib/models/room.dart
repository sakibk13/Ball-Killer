class Room {
  final String id;
  final String code; // 6-character room code (e.g., SPK13X)
  final String name;
  final String adminPhone;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.code,
    required this.name,
    required this.adminPhone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.toUpperCase(),
      'name': name,
      'adminPhone': adminPhone,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] ?? '',
      code: (map['code'] ?? '').toString().toUpperCase(),
      name: map['name'] ?? '',
      adminPhone: map['adminPhone'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }
}
