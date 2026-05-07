import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/player.dart';
import '../models/ball_record.dart';
import '../models/contribution.dart';
import '../models/inventory.dart';
import '../models/fine_payment.dart';
import '../models/fund.dart';
import '../models/audit_log.dart';
import '../services/cloud_sync_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final bool _isConnected = true;
  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    return true;
  }

  // Fine Payment operations
  Future<List<FinePayment>> getFinePayments() async {
    try {
      final snap = await _db.collection('fine_payments').orderBy('date', descending: true).get();
      return snap.docs.map((doc) => FinePayment.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET FINE PAYMENTS ERROR: $e');
      return [];
    }
  }

  Future<bool> addFinePayment(FinePayment payment) async {
    try {
      await _db.collection('fine_payments').add(payment.toMap());
      return true;
    } catch (e) {
      debugPrint('!!! ADD FINE PAYMENT ERROR: $e');
      return false;
    }
  }

  Future<void> deleteFinePayment(String id) async {
    try {
      await _db.collection('fine_payments').doc(id).delete();
    } catch (e) {
      debugPrint('!!! DELETE FINE PAYMENT ERROR: $e');
    }
  }

  // Fund operations
  Future<List<Fund>> getFunds() async {
    try {
      final snap = await _db.collection('funds').orderBy('date', descending: true).get();
      return snap.docs.map((doc) => Fund.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET FUNDS ERROR: $e');
      return [];
    }
  }

  Future<bool> addFund(Fund fund) async {
    try {
      await _db.collection('funds').add(fund.toMap());
      return true;
    } catch (e) {
      debugPrint('!!! ADD FUND ERROR: $e');
      return false;
    }
  }

  Future<bool> updateFund(Fund fund) async {
    try {
      if (fund.id == null) return false;
      await _db.collection('funds').doc(fund.id!).update(fund.toMap());
      return true;
    } catch (e) {
      debugPrint('!!! UPDATE FUND ERROR: $e');
      return false;
    }
  }

  Future<void> deleteFund(String id) async {
    try {
      await _db.collection('funds').doc(id).delete();
    } catch (e) {
      debugPrint('!!! DELETE FUND ERROR: $e');
    }
  }

  // Inventory operations
  Future<List<Inventory>> getInventory() async {
    try {
      final snap = await _db.collection('inventory').orderBy('date', descending: true).get();
      return snap.docs.map((doc) => Inventory.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET INVENTORY ERROR: $e');
      return [];
    }
  }

  Future<bool> addInventory(Inventory inventory) async {
    try {
      await _db.collection('inventory').add(inventory.toMap());
      return true;
    } catch (e) {
      debugPrint('!!! ADD INVENTORY ERROR: $e');
      return false;
    }
  }

  Future<bool> updateInventory(Inventory inventory) async {
    try {
      if (inventory.id == null) return false;
      await _db.collection('inventory').doc(inventory.id!).update(inventory.toMap());
      return true;
    } catch (e) {
      debugPrint('!!! UPDATE INVENTORY ERROR: $e');
      return false;
    }
  }

  Future<void> deleteInventory(String id) async {
    try {
      await _db.collection('inventory').doc(id).delete();
    } catch (e) {
      debugPrint('!!! DELETE INVENTORY ERROR: $e');
    }
  }

  // Contribution operations
  Future<List<Contribution>> getContributions() async {
    try {
      final snap = await _db.collection('contributions').orderBy('date', descending: true).get();
      return snap.docs.map((doc) => Contribution.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET CONTRIBUTIONS ERROR: $e');
      return [];
    }
  }

  Future<bool> addContribution(Contribution contribution) async {
    try {
      await _db.collection('contributions').add(contribution.toMap());
      return true;
    } catch (e) {
      debugPrint('!!! ADD CONTRIBUTION ERROR: $e');
      return false;
    }
  }

  Future<bool> updateContribution(Contribution contribution) async {
    try {
      if (contribution.id == null) return false;
      await _db.collection('contributions').doc(contribution.id!).update(contribution.toMap());
      return true;
    } catch (e) {
      debugPrint('!!! UPDATE CONTRIBUTION ERROR: $e');
      return false;
    }
  }

  Future<void> deleteContribution(String id) async {
    try {
      await _db.collection('contributions').doc(id).delete();
    } catch (e) {
      debugPrint('!!! DELETE CONTRIBUTION ERROR: $e');
    }
  }

  // User operations
  Future<User?> login(String phone, String password) async {
    try {
      final snap = await _db.collection('users')
          .where('phone', isEqualTo: phone)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final user = User.fromMap(snap.docs.first.data(), docId: snap.docs.first.id);
        
        // Check for approval (Master admin always allowed)
        if (user.status != 'approved' && phone != '01832465446') {
          throw 'Your account is ${user.status}. Please wait for admin approval.';
        }
        
        return user;
      }
    } catch (e) {
      debugPrint('!!! LOGIN ERROR: $e');
      rethrow; // Pass error up to UI
    }
    return null;
  }

  Future<bool> register(User user) async {
    try {
      // 1. Check if user already exists in 'users' collection
      final existingUser = await _db.collection('users').where('phone', isEqualTo: user.phone).limit(1).get();
      if (existingUser.docs.isNotEmpty) {
        debugPrint('!!! REGISTRATION: User already exists in login system');
        throw 'Phone number already registered. Try a new number.';
      }
      
      // 2. Create the user entry as PENDING (except master admin)
      final status = user.phone == '01832465446' ? 'approved' : 'pending';
      final newUser = User(
        name: user.name,
        phone: user.phone,
        password: user.password,
        photoUrl: user.photoUrl,
        isAdmin: user.phone == '01832465446',
        status: status,
      );

      await _db.collection('users').add(newUser.toMap());
      
      // We no longer automatically add to players until approved
      
      // SYNC TO GOOGLE SHEETS
      CloudSyncService.syncSingleUser(
        name: user.name,
        phone: user.phone,
        password: user.password,
      );

      return true;
    } catch (e) {
      debugPrint('!!! REGISTRATION ERROR: $e');
      rethrow; 
    }
  }

  Future<List<User>> getPendingUsers() async {
    try {
      final snap = await _db.collection('users').where('status', isEqualTo: 'pending').get();
      return snap.docs.map((doc) => User.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET PENDING USERS ERROR: $e');
      return [];
    }
  }

  Future<bool> updateUserStatus(String userId, String status) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      await _db.collection('users').doc(userId).update({'status': status});
      
      if (status == 'approved') {
        // Automatically create/link a player upon approval
        final player = Player(
          name: userData['name'],
          phone: userData['phone'],
          password: userData['password'],
          photoUrl: userData['photoUrl'] ?? '',
        );
        await addOrUpdatePlayer(player);
      }
      
      return true;
    } catch (e) {
      debugPrint('!!! UPDATE USER STATUS ERROR: $e');
      return false;
    }
  }

  // Player operations
  Future<List<Player>> getPlayers() async {
    try {
      final snap = await _db.collection('players').get();
      return snap.docs.map((doc) => Player.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET PLAYERS ERROR: $e');
      return [];
    }
  }

  Future<Player?> addOrUpdatePlayer(Player player) async {
    try {
      // 1. Check if player already exists in 'players'
      final snap = await _db.collection('players').where('phone', isEqualTo: player.phone).limit(1).get();
      
      if (snap.docs.isNotEmpty || player.id != null) {
        final id = player.id ?? snap.docs.first.id;
        final updateData = {
          'name': player.name,
          'phone': player.phone,
          'password': player.password,
          'photoUrl': player.photoUrl,
        };
        
        await _db.collection('players').doc(id).update(updateData);
        
        // SYNC: Also update the login user record if it exists
        final userSnap = await _db.collection('users').where('phone', isEqualTo: player.phone).limit(1).get();
        if (userSnap.docs.isNotEmpty) {
          await _db.collection('users').doc(userSnap.docs.first.id).update(updateData);
        }
        
        final updated = await _db.collection('players').doc(id).get();
        
        // SYNC TO GOOGLE SHEETS
        CloudSyncService.syncSingleUser(
          name: player.name,
          phone: player.phone,
          password: player.password,
        );

        return updated.exists ? Player.fromMap(updated.data()!, docId: id) : null;
      } else {
        // 2. NEW PLAYER: Check if a USER already exists with this phone/name to link data
        final userSnap = await _db.collection('users').where('phone', isEqualTo: player.phone).limit(1).get();
        
        Map<String, dynamic> finalPlayerMap = player.toMap();
        if (userSnap.docs.isNotEmpty) {
           final userData = userSnap.docs.first.data();
           finalPlayerMap['password'] = userData['password'] ?? player.password;
           finalPlayerMap['photoUrl'] = userData['photoUrl'] ?? player.photoUrl;
           finalPlayerMap['name'] = userData['name'] ?? player.name;
        }

        final docRef = await _db.collection('players').add(finalPlayerMap);
        final result = await docRef.get();
        
        // SYNC TO GOOGLE SHEETS
        CloudSyncService.syncSingleUser(
          name: finalPlayerMap['name'],
          phone: finalPlayerMap['phone'],
          password: finalPlayerMap['password'],
        );

        return Player.fromMap(result.data()!, docId: result.id);
      }
    } catch (e) {
      debugPrint('!!! ADD/UPDATE PLAYER ERROR: $e');
    }
    return null;
  }

  Future<bool> updatePlayer(Player player) async {
    try {
      if (player.id == null) return false;
      final updateData = {
        'name': player.name,
        'phone': player.phone,
        'password': player.password,
        'photoUrl': player.photoUrl,
      };

      await _db.collection('players').doc(player.id!).update(updateData);

      // SYNC: Also update the login user record if it exists
      final userSnap = await _db.collection('users').where('phone', isEqualTo: player.phone).limit(1).get();
      if (userSnap.docs.isNotEmpty) {
        await _db.collection('users').doc(userSnap.docs.first.id).update(updateData);
      }
      
      return true;
    } catch (e) {
      debugPrint('!!! UPDATE PLAYER ERROR: $e');
      return false;
    }
  }

  Future<bool> updatePlayerTotalLost(String playerId, int newTotal) async {
    try {
      await _db.collection('players').doc(playerId).update({
        'totalLost': newTotal,
      });
      return true;
    } catch (e) {
      debugPrint('!!! UPDATE PLAYER TOTAL LOST ERROR: $e');
      return false;
    }
  }

  Future<bool> deletePlayer(String id, String phone) async {
    try {
      // 1. Delete from players
      await _db.collection('players').doc(id).delete();
      
      // 2. Delete from users if they exist
      final userSnap = await _db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
      if (userSnap.docs.isNotEmpty) {
        await _db.collection('users').doc(userSnap.docs.first.id).delete();
      }
      return true;
    } catch (e) {
      debugPrint('!!! DELETE PLAYER ERROR: $e');
      return false;
    }
  }

  Future<Player?> getPlayerByName(String name) async {
    try {
      final snap = await _db.collection('players').where('name', isEqualTo: name).limit(1).get();
      if (snap.docs.isNotEmpty) return Player.fromMap(snap.docs.first.data(), docId: snap.docs.first.id);
    } catch (e) {
      debugPrint('!!! GET PLAYER BY NAME ERROR: $e');
    }
    return null;
  }

  // Record operations
  Future<void> addRecord(BallRecord record) async {
    try {
      await _db.collection('records').add(record.toMap());
      await _db.collection('players').doc(record.playerId).update({
        'totalLost': FieldValue.increment(record.lostCount)
      });
    } catch (e) {
      debugPrint('!!! ADD RECORD ERROR: $e');
    }
  }

  Future<void> updateRecord(BallRecord record, int oldCount) async {
    try {
      if (record.id == null) return;
      await _db.collection('records').doc(record.id!).update(record.toMap());
      
      // Adjust player's totalLost: remove old count, add new count
      int diff = record.lostCount - oldCount;
      if (diff != 0) {
        await _db.collection('players').doc(record.playerId).update({
          'totalLost': FieldValue.increment(diff)
        });
      }
    } catch (e) {
      debugPrint('!!! UPDATE RECORD ERROR: $e');
    }
  }

  Future<List<BallRecord>> getRecords() async {
    try {
      final snap = await _db.collection('records').orderBy('date', descending: true).get();
      return snap.docs.map((doc) => BallRecord.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET RECORDS ERROR: $e');
      return [];
    }
  }

  Future<List<BallRecord>> getTodayRecords() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final snap = await _db.collection('records')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      return snap.docs.map((doc) => BallRecord.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET TODAY RECORDS ERROR: $e');
      return [];
    }
  }

  Future<void> deleteRecord(String recordId, String playerId, int lostCount) async {
    try {
      await _db.collection('records').doc(recordId).delete();
      await _db.collection('players').doc(playerId).update({
        'totalLost': FieldValue.increment(-lostCount)
      });
    } catch (e) {
      debugPrint('!!! DELETE RECORD ERROR: $e');
    }
  }

  // AUDIT LOGS
  Future<void> addAuditLog(AuditLog log) async {
    try {
      await _db.collection('audit_logs').add(log.toMap());
    } catch (e) {
      debugPrint('!!! ADD AUDIT LOG ERROR: $e');
    }
  }

  Future<List<AuditLog>> getAuditLogs() async {
    try {
      final snap = await _db.collection('audit_logs').orderBy('timestamp', descending: true).limit(100).get();
      return snap.docs.map((doc) => AuditLog.fromMap(doc.data(), docId: doc.id)).toList();
    } catch (e) {
      debugPrint('!!! GET AUDIT LOGS ERROR: $e');
      return [];
    }
  }

  // PROFILE MANAGEMENT
  Future<bool> updateUserProfile(String phone, {String? name, String? photoUrl, String? newPhone}) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;
      if (newPhone != null) updateData['phone'] = newPhone;

      if (updateData.isEmpty) return true;

      // Update in users collection
      final userSnap = await _db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
      if (userSnap.docs.isNotEmpty) {
        await _db.collection('users').doc(userSnap.docs.first.id).update(updateData);
      }

      // Update in players collection
      final playerSnap = await _db.collection('players').where('phone', isEqualTo: phone).limit(1).get();
      if (playerSnap.docs.isNotEmpty) {
        await _db.collection('players').doc(playerSnap.docs.first.id).update(updateData);
      }

      // SYNC TO GOOGLE SHEETS
      if (userSnap.docs.isNotEmpty) {
        final fullData = userSnap.docs.first.data();
        CloudSyncService.syncSingleUser(
          name: name ?? fullData['name'],
          phone: newPhone ?? phone,
          password: fullData['password'],
        );
      }
      
      return true;
    } catch (e) {
      debugPrint('!!! UPDATE PROFILE ERROR: $e');
      return false;
    }
  }

  Future<bool> updatePassword(String phone, String newPassword) async {
    try {
      // Update in users
      final userSnap = await _db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
      if (userSnap.docs.isNotEmpty) {
        await _db.collection('users').doc(userSnap.docs.first.id).update({'password': newPassword});
      }

      // Update in players
      final playerSnap = await _db.collection('players').where('phone', isEqualTo: phone).limit(1).get();
      if (playerSnap.docs.isNotEmpty) {
        await _db.collection('players').doc(playerSnap.docs.first.id).update({'password': newPassword});
      }

      // SYNC TO GOOGLE SHEETS
      if (userSnap.docs.isNotEmpty) {
        CloudSyncService.syncSingleUser(
          name: userSnap.docs.first.data()['name'],
          phone: phone,
          password: newPassword,
        );
      }
      
      return true;
    } catch (e) {
      debugPrint('!!! UPDATE PASSWORD ERROR: $e');
      return false;
    }
  }
}
