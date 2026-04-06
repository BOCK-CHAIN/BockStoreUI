import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../utils/hex_id.dart';

class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  Future<Map<String, dynamic>> login(String hexId, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'hex_id': hexId, 'password': password}),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      await _saveToken(data['token']);
      await _saveUser(data['user']);
      return {'success': true, 'user': UserModel.fromJson(data['user'])};
    } else {
      return {'success': false, 'error': data['error'] ?? 'Login failed.'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<Map<String, dynamic>?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userStr = prefs.getString(_userKey);

    if (token == null || userStr == null) return null;

    return {'token': token, 'user': UserModel.fromJson(jsonDecode(userStr))};
  }

  Future<Map<String, dynamic>> register(
    String firstName,
    String lastName,
    String email,
    String password,
    String dob,
    String gender,
  ) async {
    final hexId = generateHexId(
      email,
      password,
      firstName,
      lastName,
      dob,
      gender,
    );
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'dob': dob,
        'gender': gender,
        'hex_id': hexId,
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 201 || res.statusCode == 200) {
      await _saveToken(data['token']);
      await _saveUser(data['user']);
      return {
        'success': true,
        'user': UserModel.fromJson(data['user']),
        'hex_id': data['hex_id'],
      };
    } else {
      return {
        'success': false,
        'error': data['error'] ?? 'Registration failed.',
      };
    }
  }

  Future<String?> uploadProfileImage(XFile image) async {
    final token = await getToken();

    var request = http.MultipartRequest(
      "PUT",
      Uri.parse("${ApiConfig.baseUrl}/api/auth/profile-image"),
    );

    request.headers["Authorization"] = "Bearer $token";

    if (kIsWeb) {
      Uint8List bytes = await image.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          "profile_image",
          bytes,
          filename: image.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath("profile_image", image.path),
      );
    }

    final response = await request.send();

    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      final data = jsonDecode(res.body);

      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(_userKey);

      if (userStr != null) {
        final userMap = jsonDecode(userStr);
        userMap["profile_image"] = data["profile_image"];

        await prefs.setString(_userKey, jsonEncode(userMap));
      }

      return data["profile_image"];
    }

    return null;
  }

  Future<bool> deleteAccount() async {
    final token = await getToken();

    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/delete-account'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getHexId(String email) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-hexid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      return {'success': true, 'hex_id': data['hex_id']};
    } else {
      return {'success': false, 'error': data['error']};
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }
}
