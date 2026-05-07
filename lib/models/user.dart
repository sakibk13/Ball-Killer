class User {
  final String? id;
  final String name;
  final String phone;
  final String password;
  final String photoUrl;
  final bool isAdmin;
  final String status; // 'pending', 'approved', 'rejected'

  User({
    this.id,
    required this.name,
    required this.phone,
    required this.password,
    this.photoUrl = '',
    this.isAdmin = false,
    this.status = 'approved',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      'photoUrl': photoUrl,
      'isAdmin': isAdmin,
      'status': status,
    };
  }

  factory User.fromMap(Map<String, dynamic> map, {String? docId}) {
    return User(
      id: docId ?? map['id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      password: map['password'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      status: map['status'] ?? 'approved',
    );
  }
}
