import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLog {
  final String? id;
  final String adminName;
  final String action; // e.g., 'EDIT_LOSS', 'ADD_FUND', 'DELETE_RECORD'
  final String details; // e.g., 'Changed Fardin loss from 5 to 3'
  final DateTime timestamp;

  AuditLog({
    this.id,
    required this.adminName,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'adminName': adminName,
      'action': action,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AuditLog(
      id: docId,
      adminName: map['adminName'] ?? 'Admin',
      action: map['action'] ?? 'UNKNOWN',
      details: map['details'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
