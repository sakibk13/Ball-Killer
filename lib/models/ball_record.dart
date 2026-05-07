import 'package:cloud_firestore/cloud_firestore.dart';

class BallRecord {
  final String? id;
  final String playerId;
  final String playerName;
  final int lostCount;
  final DateTime date;
  final String monthYear;
  final String recordedBy;
  final String note;

  BallRecord({
    this.id,
    required this.playerId,
    required this.playerName,
    required this.lostCount,
    required this.date,
    required this.monthYear,
    required this.recordedBy,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'lostCount': lostCount,
      'date': Timestamp.fromDate(date),
      'monthYear': monthYear,
      'recordedBy': recordedBy,
      'note': note,
    };
  }

  factory BallRecord.fromMap(Map<String, dynamic> map, {String? docId}) {
    return BallRecord(
      id: docId ?? map['id'],
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? '',
      lostCount: map['lostCount'] ?? 0,
      date: (map['date'] as Timestamp).toDate(),
      monthYear: map['monthYear'] ?? '',
      recordedBy: map['recordedBy'] ?? '',
      note: map['note'] ?? '',
    );
  }
}
