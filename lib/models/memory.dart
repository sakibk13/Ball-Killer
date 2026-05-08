import 'package:cloud_firestore/cloud_firestore.dart';

class Memory {
  final String? id;
  final String note;
  final List<String> mediaUrls;
  final List<String> mediaTypes; // 'image' or 'video'
  final DateTime date;
  final String adminName;

  Memory({
    this.id,
    required this.note,
    required this.mediaUrls,
    required this.mediaTypes,
    required this.date,
    required this.adminName,
  });

  Map<String, dynamic> toMap() {
    return {
      'note': note,
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes,
      'date': Timestamp.fromDate(date),
      'adminName': adminName,
    };
  }

  factory Memory.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Memory(
      id: docId,
      note: map['note'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(map['mediaTypes'] ?? []),
      date: (map['date'] as Timestamp).toDate(),
      adminName: map['adminName'] ?? 'Admin',
    );
  }
}
