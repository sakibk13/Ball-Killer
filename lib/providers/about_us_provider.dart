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

  Future<String?> addMemory({
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
        final filename = '${DateTime.now().millisecondsSinceEpoch}_$i.${types[i] == 'video' ? 'mp4' : 'jpg'}';
        final ref = _storage.ref().child('memories/$filename');
        
        // Read file as bytes for more reliable upload
        final Uint8List data = await file.readAsBytes();
        final metadata = SettableMetadata(contentType: types[i] == 'video' ? 'video/mp4' : 'image/jpeg');
        
        final uploadTask = await ref.putData(data, metadata);
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
        _isLoading = false;
        notifyListeners();
        return null; // Success
      } else {
        throw 'Failed to save memory details to database.';
      }
    } catch (e) {
      debugPrint('!!! ADD MEMORY ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> deleteMemory(String id) async {
    await _db.deleteMemory(id);
    await fetchMemories();
  }

  Future<String?> updateMemory({
    required String id,
    required String note,
    required List<String> existingUrls,
    required List<String> existingTypes,
    required List<File> newFiles,
    required List<String> newTypes,
    required String adminName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      List<String> finalUrls = List.from(existingUrls);
      List<String> finalTypes = List.from(existingTypes);

      for (int i = 0; i < newFiles.length; i++) {
        final file = newFiles[i];
        final filename = '${DateTime.now().millisecondsSinceEpoch}_update_$i.${newTypes[i] == 'video' ? 'mp4' : 'jpg'}';
        final ref = _storage.ref().child('memories/$filename');
        
        final Uint8List data = await file.readAsBytes();
        final metadata = SettableMetadata(contentType: newTypes[i] == 'video' ? 'video/mp4' : 'image/jpeg');
        
        final uploadTask = await ref.putData(data, metadata);
        final url = await uploadTask.ref.getDownloadURL();
        finalUrls.add(url);
        finalTypes.add(newTypes[i]);
      }

      final memory = Memory(
        id: id,
        note: note,
        mediaUrls: finalUrls,
        mediaTypes: finalTypes,
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
        throw 'Failed to update memory details in database.';
      }
    } catch (e) {
      debugPrint('!!! UPDATE MEMORY ERROR: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }
}
