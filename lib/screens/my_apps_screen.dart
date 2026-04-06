import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/app_model.dart';
import '../config/api_config.dart';
import 'app_detail_screen.dart';

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen>
    with SingleTickerProviderStateMixin {
  List<AppModel> apps = [];
  bool loading = true;

  static const _purple = Color(0xFF6A1B9A);

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    loadApps();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> loadApps() async {
    final auth = context.read<AuthProvider>();
    final data = await ApiService.fetchMyApps(auth.token!);
    setState(() {
      apps = data.map((e) => AppModel.fromJson(e)).toList();
      loading = false;
    });
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          "My Apps",
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : apps.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.apps_outlined,
                      size: 48,
                      color: _purple,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No installed apps yet",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Apps you install will appear here",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF000000,
                          ).withValues(alpha: 0.04),
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AppDetailScreen(app: app),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // App icon
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  "${ApiConfig.baseUrl}${app.iconUrl}",
                                  width: 58,
                                  height: 58,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5FAF6),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.apps_rounded,
                                      color: _purple,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      app.developer ?? "Unknown Developer",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _purple,
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
                                            color: const Color(0xFFF5FAF6),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE0EEE5),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.download_rounded,
                                                size: 12,
                                                color: _purple,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "${app.downloadCount} download${app.downloadCount == 1 ? '' : 's'}",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF424242),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (app.version != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            "v${app.version}",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFBDBDBD),
                                            ),
                                          ),
                                        ],
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
                },
              ),
            ),
    );
  }
}
