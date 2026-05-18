// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/app_model.dart';
import '../config/api_config.dart';
import '../config/url_helper.dart';
import 'app_detail_screen.dart';
import '../theme/bock_colors.dart';

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
  String? developerBio;

  Color get _bg => BockColors.bgDark;
  Color get _card => BockColors.cardDark;
  Color get _border => BockColors.borderDark;
  Color get _textPrimary => BockColors.textPrimaryDark;
  Color get _textSecondary => BockColors.textSecondaryDark;

  @override
  void initState() {
    super.initState();
    _fetchDeveloper();
  }

  Future<void> _fetchDeveloper() async {
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/apps/developer?name=${Uri.encodeComponent(widget.developerName)}',
        ),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => developerBio = data['bio']);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final devApps = widget.allApps
        .where(
          (a) =>
              (a.developer ?? '').toLowerCase() ==
              widget.developerName.toLowerCase(),
        )
        .toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: BockColors.surfaceDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.developerName,
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Developer info card ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: BockColors.purple.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: BockColors.purple.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.developerName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: BockColors.purpleLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.developerName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              developerBio ?? 'No bio provided',
                              style: TextStyle(
                                fontSize: 13,
                                color: _textSecondary,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Apps header ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: BockColors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: BockColors.purple.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.apps_rounded,
                        color: BockColors.purpleLight,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apps by this developer',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          '${devApps.length} app${devApps.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── App list ───────────────────────────────────────────────
              Expanded(
                child: devApps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: BockColors.purple.withValues(
                                  alpha: 0.08,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: BockColors.purple.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.apps_outlined,
                                size: 40,
                                color: BockColors.purpleLight,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No apps found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This developer has no apps in the store.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: devApps.length,
                        itemBuilder: (_, i) {
                          final app = devApps[i];
                          return _DevAppTile(
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

class _DevAppTile extends StatelessWidget {
  final AppModel app;
  final VoidCallback onTap;

  const _DevAppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: BockColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BockColors.borderDark),
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
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, _) => Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: BockColors.purpleDim.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.apps_rounded,
                        color: BockColors.purpleLight,
                      ),
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
                          color: BockColors.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.category ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 11,
                          color: BockColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (app.averageRating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: BockColors.star,
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              app.averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                color: BockColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              '${app.downloadCount} download${app.downloadCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: BockColors.textSecondaryDark.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: BockColors.textSecondaryDark.withValues(alpha: 0.4),
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
