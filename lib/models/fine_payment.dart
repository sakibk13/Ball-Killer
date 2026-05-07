import 'package:cloud_firestore/cloud_firestore.dart';

class FinePayment {
  final String? id;
  final String playerId;
  final String playerName;
  final double amountPaid;
  final DateTime date;
  final String? note;
  final String monthYear; // Format: MMMM yyyy

  FinePayment({
    this.id,
    required this.playerId,
    required this.playerName,
    required this.amountPaid,
    required this.date,
    this.note,
    required this.monthYear,
  });

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'amountPaid': amountPaid,
      'date': Timestamp.fromDate(date),
      'note': note,
      'monthYear': monthYear,
    };
  }

  factory FinePayment.fromMap(Map<String, dynamic> map, {String? docId}) {
    return FinePayment(
      id: docId,
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? '',
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
      monthYear: map['monthYear'] ?? '',
    );
  }
}
