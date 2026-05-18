// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../config/url_helper.dart';
import 'app_detail_screen.dart';
import '../theme/bock_colors.dart';

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen>
    with SingleTickerProviderStateMixin {
  List<AppModel> apps = [];
  bool loading = true;
  String error = '';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  Color get _bg => BockColors.bgDark;
  Color get _card => BockColors.cardDark;
  Color get _border => BockColors.borderDark;
  Color get _textPrimary => BockColors.textPrimaryDark;
  Color get _textSecondary => BockColors.textSecondaryDark;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadApps();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final auth = context.read<AuthProvider>();
      final data = await ApiService.fetchMyApps(auth.token!);
      if (!mounted) return;
      setState(() {
        apps = data.map((e) => AppModel.fromJson(e)).toList();
        loading = false;
      });
      _animCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Failed to load apps. Please try again.';
      });
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
          'My Apps',
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
          : error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BockColors.error.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BockColors.error.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: BockColors.error.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error,
                    style: TextStyle(fontSize: 14, color: _textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadApps,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BockColors.purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : apps.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: BockColors.purple.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BockColors.purple.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Icon(
                      Icons.apps_outlined,
                      size: 44,
                      color: BockColors.purpleLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No installed apps yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Apps you install will appear here.',
                    style: TextStyle(fontSize: 13, color: _textSecondary),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                itemCount: apps.length,
                itemBuilder: (_, i) {
                  final app = apps[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AppDetailScreen(app: app, allApps: apps),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.network(
                                  getFullUrl(app.iconUrl),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: BockColors.purpleDim.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(
                                      Icons.apps_rounded,
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
                                      app.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: _textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      app.developer ?? 'Unknown Developer',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: BockColors.purpleLight,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: BockColors.purple.withValues(
                                              alpha: 0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: BockColors.purple
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.download_rounded,
                                                size: 11,
                                                color: BockColors.purpleLight,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${app.downloadCount} download${app.downloadCount == 1 ? '' : 's'}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: BockColors.purpleLight,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (app.version != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            'v${app.version}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _textSecondary.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: _textSecondary.withValues(alpha: 0.4),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
