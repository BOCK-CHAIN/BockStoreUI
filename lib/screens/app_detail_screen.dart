// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';
import '../providers/auth_provider.dart';
import 'admin_upload_screen.dart';
import 'package:play_store_app/config/api_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppDetailScreen extends StatefulWidget {
  final AppModel app;

  const AppDetailScreen({super.key, required this.app});

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  late AppModel currentApp;

  final RatingService _ratingService = RatingService();

  List<String> screenshots = [];
  bool loadingScreenshots = true;

  Map<int, int> ratingDistribution = {};
  List<RatingModel> ratings = [];
  bool loadingRatings = true;

  RatingModel? userRating;

  bool isDownloading = false;

  int selectedRating = 0;
  TextEditingController reviewController = TextEditingController();
  bool submittingRating = false;

  static const _purple = Color(0xFF6A1B9A);

  @override
  void initState() {
    super.initState();
    currentApp = widget.app;
    fetchAppDetails();
    fetchRatings();
  }

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Delete App",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          "Are you sure you want to delete this app? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteApp();
  }

  Future<void> _deleteApp() async {
    final auth = context.read<AuthProvider>();
    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/api/admin/apps/${currentApp.id}"),
      headers: {"Authorization": "Bearer ${auth.token}"},
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("App deleted successfully"),
          backgroundColor: _purple,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to delete app"),
          backgroundColor: Color(0xFFE53935),
        ),
      );
    }
  }

  Future<void> uninstallApp() async {
    final auth = context.read<AuthProvider>();

    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/api/apps/${currentApp.id}/uninstall"),
      headers: {"Authorization": "Bearer ${auth.token}"},
    );

    if (response.statusCode == 200) {
      await fetchAppDetails(); // VERY IMPORTANT
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Uninstall failed")));
    }
  }

  void confirmUninstall() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Uninstall App"),
        content: const Text("Are you sure you want to uninstall?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await uninstallApp();
            },
            child: const Text("Uninstall"),
          ),
        ],
      ),
    );
  }

  Future<void> fetchAppDetails() async {
    try {
      final auth = context.read<AuthProvider>();

      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/apps/${widget.app.id}"),
        headers: {"Authorization": "Bearer ${auth.token}"},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (!mounted) return;
        setState(() {
          currentApp = AppModel.fromJson(data);
          ratingDistribution.clear();
          if (data["rating_distribution"] != null) {
            for (final item in data["rating_distribution"]) {
              ratingDistribution[item["rating"]] = item["count"];
            }
          }
          screenshots = (data["screenshots"] as List)
              .map((e) => "${ApiConfig.baseUrl}$e")
              .toList();
          loadingScreenshots = false;
        });
      } else {
        if (!mounted) return;
        setState(() => loadingScreenshots = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingScreenshots = false);
    }
  }

  Future<void> installApp() async {
    if (isDownloading) return;

    setState(() => isDownloading = true);

    final auth = context.read<AuthProvider>();

    try {
      final response = await http.get(
        Uri.parse(
          "${ApiConfig.baseUrl}/api/apps/${currentApp.id}/download?platform=android",
        ),
        headers: {"Authorization": "Bearer ${auth.token}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final downloadUrl = data["download_url"];

        final uri = Uri.parse(downloadUrl);

        bool launched;

        if (kIsWeb) {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        if (!launched && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Download failed")));
        } else {
          await fetchAppDetails();
        }
      } else {
        throw Exception("Download API failed");
      }
    } catch (e) {
      print("Download error: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Download failed")));
      }
    }

    setState(() => isDownloading = false);
  }

  Future<void> downloadFile(String platform) async {
    final auth = context.read<AuthProvider>();

    try {
      final response = await http.get(
        Uri.parse(
          "${ApiConfig.baseUrl}/api/apps/${currentApp.id}/download?platform=$platform",
        ),
        headers: {"Authorization": "Bearer ${auth.token}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data["download_url"];

        final uri = Uri.parse(url);

        if (kIsWeb) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        throw Exception("Download failed");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Download failed")));
    }
  }

  Future<void> fetchRatings() async {
    try {
      final result = await _ratingService.getRatings(currentApp.id);
      final auth = context.read<AuthProvider>();
      RatingModel? existing;
      if (auth.user?.id != null) {
        try {
          existing = result.firstWhere((r) => r.userId == auth.user!.id);
        } catch (_) {}
      }
      setState(() {
        ratings = result;
        userRating = existing;
        if (existing != null) {
          selectedRating = existing.rating;
          reviewController.text = existing.reviewText ?? "";
        }
        loadingRatings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingRatings = false);
    }
  }

  Future<void> submitRating() async {
    if (selectedRating == 0) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login to rate.")));
      return;
    }
    setState(() => submittingRating = true);
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/api/apps/${currentApp.id}/rate"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${auth.token}",
      },
      body: jsonEncode({
        "rating": selectedRating,
        "review_text": reviewController.text.trim(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      await fetchAppDetails();
      await fetchRatings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userRating != null ? "Review updated." : "Review submitted.",
          ),
          backgroundColor: _purple,
        ),
      );
    }
    setState(() => submittingRating = false);
  }

  Future<void> deleteRating() async {
    final auth = context.read<AuthProvider>();
    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/api/apps/${currentApp.id}/rate"),
      headers: {"Authorization": "Bearer ${auth.token}"},
    );
    if (response.statusCode == 200) {
      await fetchAppDetails();
      await fetchRatings();
      setState(() {
        selectedRating = 0;
        reviewController.clear();
        userRating = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Review deleted.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    bool isInstalled = currentApp.installedVersionCode != null;

    bool isUpdate =
        isInstalled &&
        currentApp.installedVersionCode != currentApp.versionCode;

    String buttonText;

    if (!isInstalled) {
      buttonText = "Install";
    } else if (isUpdate) {
      buttonText = "Update";
    } else {
      buttonText = "Uninstall";
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F0),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1A1A1A),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            currentApp.name,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          actions: [
            if (auth.isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: _purple),
                tooltip: "Edit",
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminUploadScreen(app: currentApp),
                    ),
                  );
                  if (result == true && mounted) {
                    fetchAppDetails();
                    fetchRatings();
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.delete_rounded, color: Colors.red.shade400),
                tooltip: "Delete",
                onPressed: _confirmDelete,
              ),
            ],
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero card ──────────────────────────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                "${ApiConfig.baseUrl}${currentApp.iconUrl}",
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentApp.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentApp.developer ?? "Unknown Developer",
                                    style: const TextStyle(
                                      color: _purple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _chip(
                                        Icons.code_rounded,
                                        "v${currentApp.version ?? 'N/A'}",
                                      ),
                                      _chip(
                                        Icons.storage_rounded,
                                        currentApp.size ?? 'N/A',
                                      ),
                                      if (currentApp.createdAt != null)
                                        _chip(
                                          Icons.update_rounded,
                                          currentApp.createdAt!
                                              .split('T')
                                              .first,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Stats row
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5FAF6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE0EEE5)),
                          ),
                          child: Row(
                            children: [
                              _statItem(
                                currentApp.averageRating != null
                                    ? "${currentApp.averageRating}★"
                                    : "—",
                                "${currentApp.totalReviews} reviews",
                              ),
                              _statDivider(),
                              _statItem(
                                "${currentApp.downloadCount}",
                                "Downloads",
                              ),
                              _statDivider(),
                              _statItem(
                                currentApp.ratedFor ?? "N/A",
                                "Rated for",
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        Column(
                          children: [
                            if (currentApp.androidUrl != null &&
                                currentApp.androidUrl!.isNotEmpty)
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: isDownloading
                                      ? null
                                      : (!isInstalled)
                                      ? installApp
                                      : (isUpdate)
                                      ? installApp
                                      : () => confirmUninstall(),
                                  icon: isDownloading
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.android, size: 20),
                                  label: Text(
                                    isDownloading
                                        ? "Downloading..."
                                        : buttonText,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _purple,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),

                            if (currentApp.windowsUrl != null &&
                                currentApp.windowsUrl!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => downloadFile("windows"),
                                  icon: const Icon(Icons.window),
                                  label: const Text(
                                    "Download for Windows",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            if (currentApp.linuxUrl != null &&
                                currentApp.linuxUrl!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => downloadFile("linux"),
                                  icon: const Icon(Icons.code),
                                  label: const Text(
                                    "Download for Linux",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black87,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Screenshots ────────────────────────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Screenshots"),
                        const SizedBox(height: 16),
                        if (loadingScreenshots)
                          const Center(
                            child: CircularProgressIndicator(color: _purple),
                          )
                        else if (screenshots.isNotEmpty)
                          SizedBox(
                            height: 240,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: screenshots.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    screenshots[index],
                                    width: 130,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            "No screenshots available",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── About ──────────────────────────────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("About this app"),
                        const SizedBox(height: 12),
                        Text(
                          currentApp.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF424242),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Rate this app ──────────────────────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Rate this app"),
                        const SizedBox(height: 14),

                        // Star picker
                        Row(
                          children: List.generate(5, (index) {
                            final starIndex = index + 1;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedRating = starIndex),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  starIndex <= selectedRating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: const Color(0xFFFFC107),
                                  size: 36,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: reviewController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Write a review (optional)",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5FAF6),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _purple,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: submittingRating
                                      ? null
                                      : submitRating,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _purple,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: submittingRating
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          userRating != null
                                              ? "Update Review"
                                              : "Submit Review",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (userRating != null) ...[
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: deleteRating,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade400,
                                    side: BorderSide(
                                      color: Colors.red.shade200,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Rating Distribution + Reviews ──────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Reviews"),
                        const SizedBox(height: 16),

                        // Distribution
                        ...List.generate(5, (i) {
                          final star = 5 - i;
                          final total = currentApp.totalReviews == 0
                              ? 1
                              : currentApp.totalReviews;
                          final count = ratingDistribution[star] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    "$star",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFFFFC107),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: count / total,
                                      backgroundColor: Colors.grey.shade100,
                                      color: _purple,
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    "$count",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade100),
                        const SizedBox(height: 16),

                        if (loadingRatings)
                          const Center(
                            child: CircularProgressIndicator(color: _purple),
                          )
                        else if (ratings.isEmpty)
                          Text(
                            "No reviews yet",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          )
                        else
                          ...ratings.map((rating) {
                            final formattedDate =
                                "${rating.createdAt.day}/${rating.createdAt.month}/${rating.createdAt.year}";
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FBF9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE8F5E9),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: _purple.withOpacity(
                                          0.15,
                                        ),
                                        backgroundImage:
                                            rating.profileImage != null
                                            ? NetworkImage(
                                                "${ApiConfig.baseUrl}${rating.profileImage}",
                                              )
                                            : null,
                                        child: rating.profileImage == null
                                            ? Text(
                                                rating.userName[0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: _purple,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rating.userName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFBDBDBD),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            i < rating.rating
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            color: const Color(0xFFFFC107),
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (rating.reviewText != null &&
                                      rating.reviewText!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      rating.reviewText!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF424242),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0EEE5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6A1B9A)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF424242),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 36, color: const Color(0xFFE0EEE5));
  }
}
