class User {
  final String? id;
  final String name;
  final String phone;
  final String password;
  final String photoUrl;
  final bool isAdmin;

  User({
    this.id,
    required this.name,
    required this.phone,
    required this.password,
    this.photoUrl = '',
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      'photoUrl': photoUrl,
      'isAdmin': isAdmin,
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
    );
  }
}
