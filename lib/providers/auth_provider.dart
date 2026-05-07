import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/database_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAdmin => _currentUser?.phone == '01832465446';
  bool get isGuest => _currentUser?.phone == 'guest_user';

  Future<void> loginAsGuest() async {
    _isLoading = true;
    notifyListeners();
    
    // Create a dummy guest user
    _currentUser = User(
      name: 'Guest User',
      phone: 'guest_user',
      password: '',
      isAdmin: false,
    );
    
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final user = await DatabaseService().login(phone, password);
      if (user != null) {
        _currentUser = user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone', phone);
        await prefs.setString('password', password);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login Error: $e');
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> refreshUser() async {
    if (_currentUser == null || isGuest) return;
    try {
      final updatedUser = await DatabaseService().login(_currentUser!.phone, _currentUser!.password);
      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh User Error: $e');
    }
  }

  Future<bool> register(String name, String phone, String password) async {
    if (name.isEmpty || phone.isEmpty || password.length < 4) {
      debugPrint('Validation Error: Name, Phone or Password too short');
      return false;
    }

    _isLoading = true;
    notifyListeners();
    
    try {
      final db = DatabaseService();
      // Ensure connection is active
      await db.connect(); 

      final user = User(
        name: name,
        phone: phone,
        password: password,
        isAdmin: phone == '01832465446',
      );
      
      final success = await db.register(user);
      
      if (success) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        debugPrint('DB Registration returned false (User might already exist)');
      }
    } catch (e) {
      debugPrint('Registration Error Details: $e');
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('phone')) return;
    
    final phone = prefs.getString('phone')!;
    final password = prefs.getString('password')!;
    
    await login(phone, password);
  }

  void logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone');
    await prefs.remove('password');
    notifyListeners();
  }

  Future<bool> updateProfile({String? name, String? photoUrl}) async {
    if (_currentUser == null) return false;
    final success = await DatabaseService().updateUserProfile(_currentUser!.phone, name: name, photoUrl: photoUrl);
    if (success) {
      await refreshUser();
    }
    return success;
  }

  Future<bool> updatePassword(String newPassword) async {
    if (_currentUser == null) return false;
    final success = await DatabaseService().updatePassword(_currentUser!.phone, newPassword);
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('password', newPassword);
      await refreshUser();
    }
    return success;
  }
}
