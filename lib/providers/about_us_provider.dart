import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../services/database_service.dart';

class AboutUsProvider with ChangeNotifier {
  List<Memory> _memories = [];
  bool _isLoading = false;

  List<Memory> get memories => _memories;
  bool get isLoading => _isLoading;

  final DatabaseService _db = DatabaseService();

  Future<void> fetchMemories() async {
    _isLoading = true;
    notifyListeners();
    _memories = await _db.getMemories();
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> addMemory({
    required String note,
    required List<File> files,
    required String adminName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      List<String> base64Images = [];
      for (var file in files) {
        final bytes = await file.readAsBytes();
        // Base64 encoding for database storage
        base64Images.add(base64Encode(bytes));
      }

      final memory = Memory(
        note: note,
        mediaUrls: base64Images,
        date: DateTime.now(),
        adminName: adminName,
      );

      final success = await _db.addMemory(memory);
      if (success) {
        await fetchMemories();
        _isLoading = false;
        notifyListeners();
        return null; 
      } else {
        throw 'Database save failed.';
      }
    } catch (e) {
      debugPrint('!!! ADD MEMORY ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> deleteMemory(String id) async {
    try {
      await _db.deleteMemory(id);
      await fetchMemories();
    } catch (e) {
      debugPrint('!!! DELETE MEMORY ERROR: $e');
    }
  }

  Future<String?> updateMemory({
    required String id,
    required String note,
    required List<String> existingBase64,
    required List<File> newFiles,
    required String adminName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      List<String> finalBase64 = List.from(existingBase64);

      for (var file in newFiles) {
        final bytes = await file.readAsBytes();
        finalBase64.add(base64Encode(bytes));
      }

      final memory = Memory(
        id: id,
        note: note,
        mediaUrls: finalBase64,
        date: DateTime.now(),
        adminName: adminName,
      );

      final success = await _db.updateMemory(memory);
      if (success) {
        await fetchMemories();
        _isLoading = false;
        notifyListeners();
        return null;
      } else {
        throw 'Database update failed.';
      }
    } catch (e) {
      debugPrint('!!! UPDATE MEMORY ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }
}
