import 'package:cloud_firestore/cloud_firestore.dart';

class Memory {
  final String? id;
  final String note;
  final List<String> mediaUrls; // Now stores base64 strings
  final DateTime date;
  final String adminName;

  Memory({
    this.id,
    required this.note,
    required this.mediaUrls,
    required this.date,
    required this.adminName,
  });

  Map<String, dynamic> toMap() {
    return {
      'note': note,
      'mediaUrls': mediaUrls,
      'date': Timestamp.fromDate(date),
      'adminName': adminName,
    };
  }

  factory Memory.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Memory(
      id: docId,
      note: map['note'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      date: (map['date'] as Timestamp).toDate(),
      adminName: map['adminName'] ?? 'Admin',
    );
  }
}
