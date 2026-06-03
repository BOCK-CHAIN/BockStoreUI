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
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userStr = prefs.getString(_userKey);

      if (token == null || userStr == null) return null;

      final userMap = jsonDecode(userStr);
      if (userMap is! Map<String, dynamic>) return null;

      return {'token': token, 'user': UserModel.fromJson(userMap)};
    } catch (_) {
      // Corrupted data — clear it so the bad state doesn't persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      return null;
    }
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

    // Determine MIME type
    final ext = image.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';

    // Step 1 — get presigned URL from your backend
    final presignedRes = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/auth/profile-image/presigned-url?fileType=$mimeType',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (presignedRes.statusCode != 200) return null;

    final presignedData = jsonDecode(presignedRes.body);
    final String uploadUrl = presignedData['uploadUrl'];
    final String publicUrl = presignedData['publicUrl'];
    final String key = presignedData['key'];

    // Step 2 — upload directly to S3 (no auth header)
    final bytes = await image.readAsBytes();
    final s3Res = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': mimeType},
      body: bytes,
    );

    if (s3Res.statusCode != 200) return null;

    // Step 3 — tell backend to save the URL
    final confirmRes = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/profile-image'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'publicUrl': publicUrl, 'key': key}),
    );

    if (confirmRes.statusCode != 200) return null;

    // Update cached user in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      final userMap = jsonDecode(userStr);
      userMap['profile_image'] = publicUrl;
      await prefs.setString(_userKey, jsonEncode(userMap));
    }

    return publicUrl;
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
