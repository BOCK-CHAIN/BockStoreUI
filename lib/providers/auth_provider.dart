import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  String? _token;
  bool _loading = false;
  String? _lastHexId;
  String? get lastHexId => _lastHexId;

  UserModel? get user => _user;
  String? get token => _token;
  bool get loading => _loading;

  bool get isLoggedIn => _token != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> restoreSession() async {
    final session = await _authService.restoreSession();
    if (session != null) {
      _token = session['token'];
      _user = session['user'];
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    final success = await _authService.deleteAccount();

    if (success) {
      await logout();
    }

    return success;
  }

  Future<String?> login(String email, String password) async {
    _loading = true;
    notifyListeners();

    final result = await _authService.login(email, password);

    _loading = false;

    if (result['success']) {
      _user = result['user'];
      _token = await _authService.getToken();
      notifyListeners();
      return null;
    } else {
      notifyListeners();
      return result['error'];
    }
  }

  Future<void> updateProfileImage(XFile image) async {
    final newPath = await _authService.uploadProfileImage(image);

    if (newPath != null && _user != null) {
      _user = UserModel(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        role: _user!.role,
        profileImage: newPath,
      );

      notifyListeners();
    }
  }

  Future<String?> register(
    String firstName,
    String lastName,
    String email,
    String password,
    String dob,
    String gender,
  ) async {
    _loading = true;
    notifyListeners();

    final result = await _authService.register(
      firstName,
      lastName,
      email,
      password,
      dob,
      gender,
    );

    _loading = false;

    if (result['success']) {
      _user = result['user'];
      _token = await _authService.getToken();
      _lastHexId = result['hex_id'];
      notifyListeners();
      return null;
    } else {
      notifyListeners();
      return result['error'];
    }
  }

  Future<String?> fetchHexId(String email) async {
    final result = await _authService.getHexId(email);

    if (result['success']) {
      return result['hex_id'];
    } else {
      return result['error'];
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _token = null;
    notifyListeners();
  }
}
