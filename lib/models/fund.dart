import 'package:cloud_firestore/cloud_firestore.dart';

class Fund {
  final String? id;
  final String? playerId; // Added field
  final String name;
  final double amount;
  final DateTime date;
  final String? note;
  final String type; // 'INCOME' or 'EXPENSE'

  Fund({
    this.id,
    this.playerId,
    required this.name,
    required this.amount,
    required this.date,
    this.note,
    this.type = 'INCOME',
  });

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'name': name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'type': type,
    };
  }

  factory Fund.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Fund(
      id: docId,
      playerId: map['playerId'],
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
      type: map['type'] ?? 'INCOME',
    );
  }
}
