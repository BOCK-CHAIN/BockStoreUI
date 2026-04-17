// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/app_model.dart';
import '../config/api_config.dart';
import '../config/url_helper.dart';
import 'app_detail_screen.dart';

class DeveloperScreen extends StatefulWidget {
  final String developerName;
  final List<AppModel> allApps;

  const DeveloperScreen({
    super.key,
    required this.developerName,
    required this.allApps,
  });

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  static const _purple = Color(0xFF6A1B9A);

  String? developerBio;

  @override
  void initState() {
    super.initState();
    fetchDeveloper();
  }

  Future<void> fetchDeveloper() async {
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/apps/developer?name=${Uri.encodeComponent(widget.developerName)}',
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          developerBio = data['bio'];
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devApps = widget.allApps
        .where(
          (app) =>
              (app.developer ?? '').toLowerCase() ==
              widget.developerName.toLowerCase(),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.developerName,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.developerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      developerBio ?? "No description provided",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: _purple,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Apps by this developer",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            "${devApps.length} app${devApps.length == 1 ? '' : 's'}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: devApps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: _purple.withOpacity(0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.apps_outlined,
                                size: 44,
                                color: _purple,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              "No apps found",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF424242),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "This developer has no other apps in the store.",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: devApps.length,
                        itemBuilder: (context, index) {
                          final app = devApps[index];
                          return _DeveloperAppTile(
                            app: app,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AppDetailScreen(
                                  app: app,
                                  allApps: widget.allApps,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeveloperAppTile extends StatelessWidget {
  final AppModel app;
  final VoidCallback onTap;

  static const _purple = Color(0xFF6A1B9A);

  const _DeveloperAppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    getFullUrl(app.iconUrl),
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5FAF6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.apps_rounded, color: _purple),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.category ?? "Unknown",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (app.averageRating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFC107),
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              app.averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              "${app.downloadCount} download${app.downloadCount == 1 ? '' : 's'}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFBDBDBD),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFBDBDBD),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
