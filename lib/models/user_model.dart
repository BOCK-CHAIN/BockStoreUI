class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? profileImage;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profileImage,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] ?? '';
    final lastName = json['last_name'] ?? '';

    return UserModel(
      id: json['id'],
      name: "$firstName $lastName",
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      profileImage: json['profile_image'],
    );
  }

  bool get isAdmin => role == 'admin';
}
