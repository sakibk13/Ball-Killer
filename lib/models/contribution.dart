
class Contribution {
  final String? id;
  final String? playerId; // New field
  final String name;
  final double taka;
  final DateTime date;
  final String monthYear;
  final String ballTape;
  final int ballCount;
  final int tapeCount;
  final bool isFinePayment; // New field
  final bool isOther; // New field for non-monetary contributions
  final String? photoUrl; // New field for photos of items

  Contribution({
    this.id,
    this.playerId,
    required this.name,
    required this.taka,
    required this.date,
    required this.monthYear,
    required this.ballTape,
    this.ballCount = 0,
    this.tapeCount = 0,
    this.isFinePayment = false, // Default to false
    this.isOther = false, // Default to false
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'name': name,
      'taka': taka,
      'date': date,
      'monthYear': monthYear,
      'ballTape': ballTape,
      'ballCount': ballCount,
      'tapeCount': tapeCount,
      'isFinePayment': isFinePayment,
      'isOther': isOther,
      'photoUrl': photoUrl,
    };
  }

  factory Contribution.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Contribution(
      id: docId,
      playerId: map['playerId'],
      name: map['name'] ?? '',
      taka: (map['taka'] ?? 0).toDouble(),
      date: map['date'] is DateTime ? map['date'] : (map['date'] as dynamic).toDate(),
      monthYear: map['monthYear'] ?? '',
      ballTape: map['ballTape'] ?? '',
      ballCount: map['ballCount'] ?? 0,
      tapeCount: map['tapeCount'] ?? 0,
      isFinePayment: map['isFinePayment'] ?? false,
      isOther: map['isOther'] ?? false,
      photoUrl: map['photoUrl'],
    );
  }
}

