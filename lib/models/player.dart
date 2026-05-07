class Player {
  final String? id;
  final String name;
  final String phone;
  final String password;
  final String photoUrl;
  final int totalLost;

  Player({
    this.id,
    required this.name,
    required this.phone,
    this.password = '',
    this.photoUrl = '',
    this.totalLost = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      'photoUrl': photoUrl,
      'totalLost': totalLost,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Player(
      id: docId ?? map['id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      password: map['password'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      totalLost: map['totalLost'] ?? 0,
    );
  }
}
