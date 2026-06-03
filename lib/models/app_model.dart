class AppModel {
  final int id;
  final String name;
  final String description;
  final String iconUrl;
  final String? version;
  final String? size;
  final String? developer;
  final String? ratedFor;
  final String packageName;
  final int versionCode;
  final String? createdAt;
  final double? averageRating;
  final int totalReviews;
  final int downloadCount;
  final int? installedVersionCode;
  final List<Map<String, dynamic>> files;
  final String? category;
  final int? uploadedBy; // NEW: owner of this app

  AppModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.packageName,
    required this.versionCode,
    this.version,
    this.size,
    this.installedVersionCode,
    this.developer,
    this.ratedFor,
    this.createdAt,
    this.averageRating,
    this.totalReviews = 0,
    this.downloadCount = 0,
    this.files = const [],
    this.category,
    this.uploadedBy,
  });

  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? "",
      iconUrl: json['icon_url'] ?? "",
      version: json['version'],
      size: json['size'],
      developer: json['developer'],
      ratedFor: json['rated_for'],
      averageRating: json['average_rating'] != null
          ? (json['average_rating'] as num).toDouble()
          : null,
      totalReviews: json['total_reviews'] ?? 0,
      downloadCount: json['download_count'] ?? 0,
      packageName: json['package_name'],
      createdAt: json['created_at'],
      versionCode: json['version_code'] ?? 0,
      installedVersionCode: json["installed_version_code"] != null
          ? int.tryParse(json["installed_version_code"].toString())
          : null,
      files: (json['files'] as List<dynamic>? ?? [])
          .map((f) => Map<String, dynamic>.from(f as Map))
          .toList(),
      category: json['category'],
      uploadedBy: json['uploaded_by'] != null
          ? int.tryParse(json['uploaded_by'].toString())
          : null,
    );
  }
}
