import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';

class RoomProvider extends ChangeNotifier {
  String _currentRoomCode = 'SPK13';
  String _currentRoomName = 'Main Club Room';
  Room? _currentRoom;
  List<Room> _allRooms = [];
  bool _isLoading = false;

  String get currentRoomCode => _currentRoomCode.toUpperCase();
  String get currentRoomName => _currentRoomName;
  Room get currentRoom => _currentRoom ?? Room(
    id: 'spk13_default',
    code: 'SPK13',
    name: 'Main Club Room',
    adminPhone: '01832465446',
    createdAt: DateTime.now(),
    bkash1Number: '01724293453',
    bkash1Qr: 'assets/1.jpeg',
    bkash2Number: '01832465446',
    bkash2Qr: 'assets/2.jpeg',
  );
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
      _allRooms = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Room.fromMap(data);
      }).toList();

      // Ensure default room SPK13 exists in Firestore
      bool hasSPK13 = _allRooms.any((r) => r.code == 'SPK13');
      if (!hasSPK13) {
        final defaultRoom = Room(
          id: 'spk13_default',
          code: 'SPK13',
          name: 'Main Club Room',
          adminPhone: '01832465446',
          createdAt: DateTime.now(),
          bkash1Number: '01724293453',
          bkash1Qr: 'assets/1.jpeg',
          bkash2Number: '01832465446',
          bkash2Qr: 'assets/2.jpeg',
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
        _currentRoom = _allRooms.firstWhere((r) => r.code == 'SPK13', orElse: () => _allRooms.first);
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
            bkash1Number: '01724293453',
            bkash1Qr: 'assets/1.jpeg',
            bkash2Number: '01832465446',
            bkash2Qr: 'assets/2.jpeg',
          )
        ];
        _currentRoom = _allRooms.first;
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
        bkash1Number: '01724293453',
        bkash1Qr: 'assets/1.jpeg',
        bkash2Number: '01832465446',
        bkash2Qr: 'assets/2.jpeg',
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

  Future<bool> updateRoomPaymentDetails({
    required String roomId,
    required String bkash1Number,
    required String bkash1Name,
    required String bkash1Qr,
    required String bkash2Number,
    required String bkash2Name,
    required String bkash2Qr,
    required String bankName,
    required String bankAccountName,
    required String bankAccountNumber,
    required String routingNumber,
    required String bankBranch,
    required String bankLogo,
    required String noticeText,
    required String referenceNote,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updatedMap = {
        'bkash1Number': bkash1Number,
        'bkash1Name': bkash1Name,
        'bkash1Qr': bkash1Qr,
        'bkash2Number': bkash2Number,
        'bkash2Name': bkash2Name,
        'bkash2Qr': bkash2Qr,
        'bankName': bankName,
        'bankAccountName': bankAccountName,
        'bankAccountNumber': bankAccountNumber,
        'routingNumber': routingNumber,
        'bankBranch': bankBranch,
        'bankLogo': bankLogo,
        'noticeText': noticeText,
        'referenceNote': referenceNote,
      };

      await FirebaseFirestore.instance.collection('rooms').doc(roomId).set(updatedMap, SetOptions(merge: true));

      int idx = _allRooms.indexWhere((r) => r.id == roomId);
      if (idx != -1) {
        _allRooms[idx] = _allRooms[idx].copyWith(
          bkash1Number: bkash1Number,
          bkash1Name: bkash1Name,
          bkash1Qr: bkash1Qr,
          bkash2Number: bkash2Number,
          bkash2Name: bkash2Name,
          bkash2Qr: bkash2Qr,
          bankName: bankName,
          bankAccountName: bankAccountName,
          bankAccountNumber: bankAccountNumber,
          routingNumber: routingNumber,
          bankBranch: bankBranch,
          bankLogo: bankLogo,
          noticeText: noticeText,
          referenceNote: referenceNote,
        );
        if (_currentRoom?.id == roomId || _currentRoom?.code == _allRooms[idx].code) {
          _currentRoom = _allRooms[idx];
        }
      }

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
