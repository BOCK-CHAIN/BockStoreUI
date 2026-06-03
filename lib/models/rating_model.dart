class RatingModel {
  final int id;
  final int userId;
  final String userName;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;
  final String? profileImage;

  RatingModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    this.profileImage,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      rating: json['rating'],
      reviewText: json['review_text'],
      createdAt: DateTime.parse(json['created_at']),
      profileImage: json['user_profile_image'],
    );
  }
}
