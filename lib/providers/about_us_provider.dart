import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/memory.dart';
import '../services/database_service.dart';

class AboutUsProvider with ChangeNotifier {
  List<Memory> _memories = [];
  bool _isLoading = false;

  List<Memory> get memories => _memories;
  bool get isLoading => _isLoading;

  final DatabaseService _db = DatabaseService();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> fetchMemories() async {
    _isLoading = true;
    notifyListeners();
    _memories = await _db.getMemories();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addMemory({
    required String note,
    required List<File> files,
    required List<String> types,
    required String adminName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      List<String> urls = [];
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final ref = _storage.ref().child('memories/${DateTime.now().millisecondsSinceEpoch}_$i');
        final uploadTask = await ref.putFile(file);
        final url = await uploadTask.ref.getDownloadURL();
        urls.add(url);
      }

      final memory = Memory(
        note: note,
        mediaUrls: urls,
        mediaTypes: types,
        date: DateTime.now(),
        adminName: adminName,
      );

      final success = await _db.addMemory(memory);
      if (success) {
        await fetchMemories();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('!!! ADD MEMORY ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteMemory(String id) async {
    await _db.deleteMemory(id);
    await fetchMemories();
  }
}
