import 'package:cloud_firestore/cloud_firestore.dart';

class UnintentionalRecord {
  final String? id;
  final int lostCount;
  final DateTime date;
  final String monthYear;
  final String recordedBy;
  final String note;
  final DateTime? createdAt;

  UnintentionalRecord({
    this.id,
    required this.lostCount,
    required this.date,
    required this.monthYear,
    required this.recordedBy,
    this.note = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'lostCount': lostCount,
      'date': Timestamp.fromDate(date),
      'monthYear': monthYear,
      'recordedBy': recordedBy,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  factory UnintentionalRecord.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    }

    return UnintentionalRecord(
      id: docId ?? map['id'],
      lostCount: map['lostCount'] ?? 0,
      date: parsedDate,
      monthYear: map['monthYear'] ?? '',
      recordedBy: map['recordedBy'] ?? '',
      note: map['note'] ?? '',
      createdAt: parsedCreatedAt,
    );
  }
}
