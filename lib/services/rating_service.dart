import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/rating_model.dart';

class RatingService {
  Future<List<RatingModel>> getRatings(int appId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/apps/$appId/ratings'),
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final List reviews = decoded['data']['reviews'];

      return reviews.map((e) => RatingModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load ratings');
    }
  }

  Future<void> submitRating({
    required int appId,
    required String token,
    required int rating,
    String? reviewText,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/apps/$appId/rate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'rating': rating,
        if (reviewText != null && reviewText.isNotEmpty)
          'review_text': reviewText,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to submit rating');
    }
  }

  Future<void> deleteRating({required int appId, required String token}) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/apps/$appId/rate'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to delete rating');
    }
  }
}
