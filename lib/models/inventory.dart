import 'package:cloud_firestore/cloud_firestore.dart';

class Inventory {
  final String? id;
  final DateTime date;
  final int ballsBrought;
  final int tapesBrought;
  final int ballsTaken;
  final int ballsReturned; // New field
  final int totalLost; // Manual input
  final int uninteniollyLost; // Manual input
  final int playerLost; // Calculated: totalLost - uninteniollyLost
  final int totalStock; // For manual stock resets
  final bool isStockUpdate;
  final String monthYear;
  final String recordedBy;
  final String note;

  Inventory({
    this.id,
    required this.date,
    this.ballsBrought = 0,
    this.tapesBrought = 0,
    this.ballsTaken = 0,
    this.ballsReturned = 0, // Default to 0
    this.totalLost = 0,
    this.uninteniollyLost = 0,
    this.playerLost = 0,
    this.totalStock = 0,
    this.isStockUpdate = false,
    required this.monthYear,
    required this.recordedBy,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'ballsBrought': ballsBrought,
      'tapesBrought': tapesBrought,
      'ballsTaken': ballsTaken,
      'ballsReturned': ballsReturned, // Add to map
      'totalLost': totalLost,
      'uninteniollyLost': uninteniollyLost,
      'playerLost': playerLost,
      'totalStock': totalStock,
      'isStockUpdate': isStockUpdate,
      'monthYear': monthYear,
      'recordedBy': recordedBy,
      'note': note,
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Inventory(
      id: docId ?? map['id'],
      date: (map['date'] as Timestamp).toDate(),
      ballsBrought: map['ballsBrought'] ?? 0,
      tapesBrought: map['tapesBrought'] ?? 0,
      ballsTaken: map['ballsTaken'] ?? 0,
      ballsReturned: map['ballsReturned'] ?? 0, // Read from map
      totalLost: map['totalLost'] ?? 0,
      uninteniollyLost: map['uninteniollyLost'] ?? 0,
      playerLost: map['playerLost'] ?? 0,
      totalStock: map['totalStock'] ?? 0,
      isStockUpdate: map['isStockUpdate'] ?? false,
      monthYear: map['monthYear'] ?? '',
      recordedBy: map['recordedBy'] ?? '',
      note: map['note'] ?? '',
    );
  }
}
