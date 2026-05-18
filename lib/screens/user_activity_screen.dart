// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../theme/bock_colors.dart';

class UserActivityScreen extends StatefulWidget {
  const UserActivityScreen({super.key});

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  List activity = [];
  bool loading = true;

  Color get _bg => BockColors.bgDark;
  Color get _card => BockColors.cardDark;
  Color get _border => BockColors.borderDark;
  Color get _textPrimary => BockColors.textPrimaryDark;
  Color get _textSecondary => BockColors.textSecondaryDark;

  @override
  void initState() {
    super.initState();
    // FIX: use addPostFrameCallback so the widget tree (and AuthProvider)
    // is fully built before we read the token — avoids null token on cold start
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchActivity());
  }

  Future<void> _fetchActivity() async {
    final auth = context.read<AuthProvider>();

    // FIX: if session hasn't been restored yet, wait for it
    if (!auth.isLoggedIn) {
      await auth.restoreSession();
    }

    final token = auth.token;

    if (token == null) {
      setState(() {
        activity = [];
        loading = false;
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/apps/user/activity'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;
      setState(() {
        activity = res.statusCode == 200 ? jsonDecode(res.body) : [];
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _formatAction(String action) {
    switch (action) {
      case 'apk_updated':
        return 'App Updated';
      case 'uploaded':
        return 'New App Added';
      case 'metadata_updated':
        return 'Details Updated';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'apk_updated':
        return Icons.system_update_rounded;
      case 'uploaded':
        return Icons.cloud_upload_rounded;
      case 'metadata_updated':
        return Icons.edit_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'uploaded':
        return const Color(0xFF4CAF50);
      case 'apk_updated':
        return BockColors.purpleLight;
      case 'metadata_updated':
        return const Color(0xFFF59E0B);
      default:
        return BockColors.textSecondaryDark;
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Recent Activity',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: BockColors.purple),
            )
          : activity.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BockColors.purple.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BockColors.purple.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 40,
                      color: BockColors.purpleLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'App updates and uploads will appear here.',
                    style: TextStyle(fontSize: 13, color: _textSecondary),
                  ),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  itemCount: activity.length,
                  itemBuilder: (_, i) {
                    final log = activity[i];
                    final action = log['action'] as String? ?? '';
                    final appName = log['app_name'] as String? ?? 'Unknown App';
                    final version = log['version'] as String?;
                    final createdAt = log['created_at'] as String? ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _actionColor(
                                  action,
                                ).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _actionIcon(action),
                                size: 18,
                                color: _actionColor(action),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: _textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        _formatAction(action),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _actionColor(action),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (version != null &&
                                          version.isNotEmpty) ...[
                                        Text(
                                          ' · ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _textSecondary,
                                          ),
                                        ),
                                        Text(
                                          'v$version',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              createdAt.isNotEmpty
                                  ? _formatDate(createdAt)
                                  : '',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
