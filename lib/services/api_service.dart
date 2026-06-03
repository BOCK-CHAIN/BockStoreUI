import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bockstore/config/api_config.dart';

class ApiService {
  static Future<Map<String, String>> _getHeaders({
    bool requiresAuth = false,
  }) async {
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<void> uninstallApp(int appId, String token) async {
    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/api/apps/$appId/uninstall"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      throw Exception("Uninstall failed");
    }
  }

  static Future<List<dynamic>> fetchMyApps(String token) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/apps/my-apps'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load my apps");
    }
  }

  static Future<List<dynamic>> fetchApps({String? search}) async {
    String url = '${ApiConfig.baseUrl}/api/apps';

    if (search != null && search.isNotEmpty) {
      url += '?search=$search';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load apps');
    }
  }

  static Future<http.Response> protectedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return await http.post(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: await _getHeaders(requiresAuth: true),
      body: jsonEncode(body),
    );
  }

  static Future<Map<String, dynamic>> getPresignedUrl({
    required String fileName,
    required String fileType,
    required String folder,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/presigned-url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fileName': fileName,
        'fileType': fileType,
        'folder': folder,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Failed to get presigned URL: ${res.body}');
    }
  }

  static Future<String> uploadFileToS3({
    required String uploadUrl,
    required String fileUrl,
    required List<int> fileBytes,
    required String fileType,
  }) async {
    final res = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': fileType},
      body: fileBytes,
    );

    if (res.statusCode != 200) {
      throw Exception('S3 upload failed: ${res.statusCode}');
    }

    return fileUrl;
  }
}
