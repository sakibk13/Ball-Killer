import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';

class RoomProvider extends ChangeNotifier {
  String _currentRoomCode = 'SPK13';
  String _currentRoomName = 'Default Room';
  Room? _currentRoom;
  List<Room> _allRooms = [];
  bool _isLoading = false;

  String get currentRoomCode => _currentRoomCode.toUpperCase();
  String get currentRoomName => _currentRoomName;
  Room? get currentRoom => _currentRoom;
  List<Room> get allRooms => _allRooms;
  bool get isLoading => _isLoading;

  RoomProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentRoomCode = (prefs.getString('active_room_code') ?? 'SPK13').toUpperCase();
      await fetchAllRooms();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllRooms() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('rooms').get();
      _allRooms = snapshot.docs.map((doc) => Room.fromMap(doc.data())).toList();

      // Ensure default room SPK13 exists in Firestore
      bool hasSPK13 = _allRooms.any((r) => r.code == 'SPK13');
      if (!hasSPK13) {
        final defaultRoom = Room(
          id: 'spk13_default',
          code: 'SPK13',
          name: 'Main Club Room',
          adminPhone: '01832465446',
          createdAt: DateTime.now(),
        );
        await FirebaseFirestore.instance.collection('rooms').doc('spk13_default').set(defaultRoom.toMap());
        _allRooms.add(defaultRoom);
      }

      try {
        _currentRoom = _allRooms.firstWhere((r) => r.code == _currentRoomCode);
        _currentRoomName = _currentRoom?.name ?? 'Room $_currentRoomCode';
      } catch (_) {
        _currentRoomCode = 'SPK13';
        _currentRoomName = 'Main Club Room';
      }
    } catch (e) {
      // Offline fallback
      if (_allRooms.isEmpty) {
        _allRooms = [
          Room(
            id: 'spk13_default',
            code: 'SPK13',
            name: 'Main Club Room',
            adminPhone: '01832465446',
            createdAt: DateTime.now(),
          )
        ];
      }
    }
    notifyListeners();
  }

  Future<bool> joinRoom(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length < 3) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await fetchAllRooms();
      final roomMatch = _allRooms.firstWhere(
        (r) => r.code == cleanCode,
        orElse: () => Room(id: '', code: '', name: '', adminPhone: '', createdAt: DateTime.now()),
      );

      if (roomMatch.code.isNotEmpty) {
        _currentRoomCode = cleanCode;
        _currentRoomName = roomMatch.name;
        _currentRoom = roomMatch;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_room_code', cleanCode);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> createRoom({
    required String code,
    required String name,
    required String adminPhone,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != 6) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await fetchAllRooms();
      bool exists = _allRooms.any((r) => r.code == cleanCode);
      if (exists) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final docRef = FirebaseFirestore.instance.collection('rooms').doc();
      final newRoom = Room(
        id: docRef.id,
        code: cleanCode,
        name: name,
        adminPhone: adminPhone,
        createdAt: DateTime.now(),
      );

      await docRef.set(newRoom.toMap());
      _allRooms.add(newRoom);
      _currentRoomCode = cleanCode;
      _currentRoomName = name;
      _currentRoom = newRoom;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_room_code', cleanCode);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> switchRoom(String code) async {
    await joinRoom(code);
  }
}
