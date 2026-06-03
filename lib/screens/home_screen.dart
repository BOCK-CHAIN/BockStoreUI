// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'app_detail_screen.dart';
import 'admin_upload_screen.dart';
import 'login_screen.dart';
import 'user_activity_screen.dart';
import 'package:bockstore/config/api_config.dart';
import 'package:bockstore/config/url_helper.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'my_apps_screen.dart';
import 'admin_logs_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/bock_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  Timer? _debounce;
  List<AppModel> apps = [];
  bool loading = true;
  String error = '';
  bool _isDark = true;
  List recentUpdates = [];
  bool loadingUpdates = true;

  bool _isSearchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  late final AnimationController _searchAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  Set<String> _wishlistIds = {};
  static const _kWishlistKey = 'wishlist_ids';

  static const double _kRailWidth = 80;

  Color get _bg => _isDark ? BockColors.bgDark : BockColors.bgLight;
  Color get _card => _isDark ? BockColors.cardDark : BockColors.cardLight;
  Color get _surface =>
      _isDark ? BockColors.surfaceDark : BockColors.surfaceLight;
  Color get _border => _isDark ? BockColors.borderDark : BockColors.borderLight;
  Color get _textPrimary =>
      _isDark ? BockColors.textPrimaryDark : BockColors.textPrimaryLight;
  Color get _textSecondary =>
      _isDark ? BockColors.textSecondaryDark : BockColors.textSecondaryLight;

  @override
  void initState() {
    super.initState();
    fetchApps();
    fetchRecentUpdates();
    loadWishlist();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthProvider>().isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sign in to access all features',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: BockColors.purple,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchAnim.dispose();
    super.dispose();
  }

  Future<void> loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
      () => _wishlistIds = (prefs.getStringList(_kWishlistKey) ?? []).toSet(),
    );
  }

  Future<void> toggleWishlist(int appId) async {
    final id = appId.toString();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wishlistIds.contains(id)
          ? _wishlistIds.remove(id)
          : _wishlistIds.add(id);
    });
    await prefs.setStringList(_kWishlistKey, _wishlistIds.toList());
  }

  bool isWishlisted(int id) => _wishlistIds.contains(id.toString());

  Future<bool> isNewApp(int appId) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getStringList('seen_apps_v1') ?? []).contains(
      appId.toString(),
    );
  }

  Future<void> markAppSeen(int appId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList('seen_apps_v1') ?? [];
    if (!seen.contains(appId.toString())) {
      seen.add(appId.toString());
      await prefs.setStringList('seen_apps_v1', seen);
    }
  }

  Future<void> pickProfileImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null)
      await context.read<AuthProvider>().updateProfileImage(image);
  }

  Future<void> fetchApps({String? query}) async {
    try {
      final data = await ApiService.fetchApps(search: query);
      if (!mounted) return;
      setState(() {
        apps = data.map((e) => AppModel.fromJson(e)).toList();
        loading = false;
        error = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Network error. Is backend running?';
        loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      fetchApps(query: value.trim().isEmpty ? null : value.trim());
    });
  }

  Future<void> fetchRecentUpdates() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() => loadingUpdates = false);
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
        recentUpdates = res.statusCode == 200 ? jsonDecode(res.body) : [];
        loadingUpdates = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingUpdates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    if (loading) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(
          child: CircularProgressIndicator(color: BockColors.purple),
        ),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 40,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                error,
                style: TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: fetchApps,
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 64 : 58),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            border: Border(bottom: BorderSide(color: _border, width: 1)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 14,
                vertical: isDesktop ? 10 : 8,
              ),
              child: isDesktop ? _buildDesktopBar(auth) : _buildMobileBar(auth),
            ),
          ),
        ),
      ),
      body: isDesktop
          ? Row(
              children: [
                _buildSidebar(),
                Expanded(child: _getBody(isDesktop: true, width: width)),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: _getBody(isDesktop: false, width: width),
              ),
            ),
    );
  }

  // ── Bottom Nav (mobile) ───────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final (icon, label) = _navItems[i];
              final selected = _selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: selected ? BockColors.purple : _textSecondary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected ? BockColors.purple : _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (selected)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: BockColors.purple,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Sidebar (desktop) ─────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: _kRailWidth,
      decoration: BoxDecoration(
        color: _surface,
        border: Border(right: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...List.generate(_navItems.length, (i) {
            final (icon, label) = _navItems[i];
            final selected = _selectedIndex == i;
            return _SidebarItem(
              icon: icon,
              label: label,
              selected: selected,
              isDark: _isDark,
              onTap: () => setState(() => _selectedIndex = i),
            );
          }),
        ],
      ),
    );
  }

  static const List<(IconData, String)> _navItems = [
    (Icons.category_rounded, 'Categories'),
    (Icons.favorite_rounded, 'Wishlist'),
    (Icons.trending_up_rounded, 'Top'),
    (Icons.person_rounded, 'Profile'),
  ];

  // ── AppBar: Desktop ───────────────────────────────────────────────────────
  Widget _buildDesktopBar(AuthProvider auth) {
    return Row(
      children: [
        const Icon(
          Icons.storefront_rounded,
          color: BockColors.purple,
          size: 22,
        ),
        const SizedBox(width: 10),
        Text(
          'Bock Store',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: _searchBar()),
        const SizedBox(width: 12),
        // Any logged-in user can upload and view their logs
        if (auth.isLoggedIn) ...[
          _iconBtn(
            icon: Icons.cloud_upload_rounded,
            tooltip: 'Upload App',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
              );
              fetchApps();
            },
          ),
          const SizedBox(width: 8),
          _iconBtn(
            icon: Icons.history_rounded,
            tooltip: 'My Upload Logs',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserActivityScreen()),
            ),
          ),
          const SizedBox(width: 10),
        ],
        _iconBtn(
          icon: _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          tooltip: _isDark ? 'Light mode' : 'Dark mode',
          onTap: () => setState(() => _isDark = !_isDark),
        ),
        const SizedBox(width: 10),
        auth.isLoggedIn
            ? _profileMenu(auth)
            : ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BockColors.purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                child: const Text('Sign In'),
              ),
      ],
    );
  }

  // ── AppBar: Mobile ────────────────────────────────────────────────────────
  Widget _buildMobileBar(AuthProvider auth) {
    return Row(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _searchAnim,
            builder: (_, __) {
              final t = _searchAnim.value;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (t < 1.0)
                    Opacity(
                      opacity: (1.0 - t * 2).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: BockColors.purple,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bock Store',
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (t > 0.0)
                    Opacity(
                      opacity: (t * 2 - 1).clamp(0.0, 1.0),
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: t == 1.0,
                          style: TextStyle(fontSize: 13, color: _textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search apps...',
                            hintStyle: TextStyle(
                              color: _textSecondary.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 16,
                              color: BockColors.purple,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        _iconBtn(
          icon: _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
          onTap: () {
            if (_isSearchOpen) {
              _searchAnim.reverse().then((_) {
                setState(() => _isSearchOpen = false);
                _searchCtrl.clear();
                fetchApps();
              });
            } else {
              setState(() => _isSearchOpen = true);
              _searchAnim.forward();
            }
          },
        ),
        const SizedBox(width: 6),
        _iconBtn(
          icon: _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          onTap: () => setState(() => _isDark = !_isDark),
        ),
        const SizedBox(width: 6),
        auth.isLoggedIn
            ? _profileMenu(auth)
            : _iconBtn(
                icon: Icons.person_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: TextField(
        style: TextStyle(fontSize: 13, color: _textPrimary),
        decoration: InputDecoration(
          hintText: 'Search apps...',
          hintStyle: TextStyle(
            color: _textSecondary.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 17,
            color: BockColors.purple,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final w = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: BockColors.purple.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: BockColors.purple.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: BockColors.purpleLight, size: 18),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: w) : w;
  }

  Widget _profileMenu(AuthProvider auth) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'toggle_theme':
            setState(() => _isDark = !_isDark);
          case 'upload':
            await pickProfileImage();
          case 'my_apps':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyAppsScreen()),
            );
          case 'delete_account':
            final ok = await _confirmDialog(
              title: 'Delete Account',
              content: 'This action cannot be undone.',
              confirmLabel: 'Delete',
              danger: true,
            );
            if (ok == true) {
              final success = await context
                  .read<AuthProvider>()
                  .deleteAccount();
              if (!mounted) return;
              if (success) Navigator.popUntil(context, (r) => r.isFirst);
            }
          case 'logout':
            auth.logout();
        }
      },
      color: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _border),
      ),
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: BockColors.purple.withValues(alpha: 0.2),
        backgroundImage: getFullUrl(auth.user?.profileImage).isNotEmpty
            ? NetworkImage(getFullUrl(auth.user!.profileImage))
            : null,
        child: getFullUrl(auth.user?.profileImage).isEmpty
            ? Text(
                auth.user!.name[0].toUpperCase(),
                style: const TextStyle(
                  color: BockColors.purpleLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            : null,
      ),
      itemBuilder: (_) => [
        _menuItem('upload', Icons.image_rounded, 'Change Photo'),
        _menuItem('my_apps', Icons.apps_rounded, 'My Apps'),
        _menuItem(
          'toggle_theme',
          _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          _isDark ? 'Light Mode' : 'Dark Mode',
        ),
        _menuItem(
          'delete_account',
          Icons.delete_forever_rounded,
          'Delete Account',
          danger: true,
        ),
        _menuItem('logout', Icons.logout_rounded, 'Logout', muted: true),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool danger = false,
    bool muted = false,
  }) {
    final color = danger
        ? BockColors.error
        : (muted ? _textSecondary : _textPrimary);
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: danger ? BockColors.error : BockColors.purple,
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _border),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: Text(content, style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? BockColors.error : BockColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ── Body Router ───────────────────────────────────────────────────────────
  Widget _getBody({bool isDesktop = false, double width = 0}) {
    switch (_selectedIndex) {
      case 0:
        return isDesktop ? _buildDesktopGrid(width) : _buildBrowse();
      case 1:
        return _buildWishlist();
      case 2:
        return _buildTopApps();
      case 3:
        return _buildProfile();
      default:
        return isDesktop ? _buildDesktopGrid(width) : _buildBrowse();
    }
  }

  Widget _buildDesktopGrid(double width) {
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: _textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No apps found',
              style: TextStyle(fontSize: 15, color: _textSecondary),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width > 1260
            ? 5
            : width > 960
            ? 4
            : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: apps.length,
      itemBuilder: (_, i) {
        final app = apps[i];
        return _AppCard(
          app: app,
          isNewApp: isNewApp,
          isDark: _isDark,
          wishlisted: isWishlisted(app.id),
          onWishlistToggle: () => toggleWishlist(app.id),
          onTap: () async {
            await markAppSeen(app.id);
            final deleted = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AppDetailScreen(app: app, allApps: apps),
              ),
            );
            if (deleted == true) fetchApps();
          },
        );
      },
    );
  }

  Widget _buildBrowse() {
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: _textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No apps found',
              style: TextStyle(fontSize: 15, color: _textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: apps.length,
      itemBuilder: (context, i) {
        final app = apps[i];
        return _AppListTile(
          app: app,
          isNewApp: isNewApp,
          isDark: _isDark,
          wishlisted: isWishlisted(app.id),
          onWishlistToggle: () => toggleWishlist(app.id),
          onTap: () async {
            await markAppSeen(app.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AppDetailScreen(app: app, allApps: apps),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWishlist() {
    final wish = apps.where((a) => isWishlisted(a.id)).toList();
    if (wish.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 56,
              color: _textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No saved apps',
              style: TextStyle(fontSize: 16, color: _textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the heart on any app to save it here.',
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: wish.length,
      itemBuilder: (context, i) {
        final app = wish[i];
        return _AppListTile(
          app: app,
          isNewApp: isNewApp,
          isDark: _isDark,
          wishlisted: true,
          onWishlistToggle: () => toggleWishlist(app.id),
          onTap: () async {
            await markAppSeen(app.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AppDetailScreen(app: app, allApps: apps),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopApps() {
    final sorted = [...apps]
      ..sort((a, b) => b.downloadCount.compareTo(a.downloadCount));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BockColors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: BockColors.purple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: BockColors.purpleLight,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Most Downloaded',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      '${sorted.length} apps ranked by downloads',
                      style: TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            final app = sorted[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
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
                    onTap: () async {
                      await markAppSeen(app.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AppDetailScreen(app: app, allApps: apps),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: i < 3
                                ? _RankBadge(rank: i + 1)
                                : Text(
                                    '${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textSecondary,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              getFullUrl(app.iconUrl),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: BockColors.purpleDim.withValues(
                                    alpha: 0.3,
                                  ),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  app.developer ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: BockColors.purpleLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.download_rounded,
                                      size: 12,
                                      color: BockColors.purple,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${app.downloadCount} downloads',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    if (app.averageRating != null) ...[
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 12,
                                        color: BockColors.star,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        app.averageRating!.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _textSecondary,
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
                            color: _textSecondary.withValues(alpha: 0.5),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }, childCount: sorted.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildProfile() {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: BockColors.purple.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: BockColors.purple.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 44,
                color: BockColors.purpleLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to view profile',
              style: TextStyle(fontSize: 15, color: _textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BockColors.purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: pickProfileImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: BockColors.purple.withValues(alpha: 0.2),
                      backgroundImage:
                          getFullUrl(auth.user?.profileImage).isNotEmpty
                          ? NetworkImage(getFullUrl(auth.user!.profileImage))
                          : null,
                      child: getFullUrl(auth.user?.profileImage).isEmpty
                          ? Text(
                              auth.user!.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: BockColors.purpleLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: BockColors.purple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                auth.user!.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _profileTile(
          Icons.apps_rounded,
          'My Apps',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyAppsScreen()),
          ),
        ),
        // Any logged-in user can upload and view their own logs
        _profileTile(Icons.cloud_upload_rounded, 'Upload App', () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
          );
          fetchApps();
        }),
        _profileTile(
          Icons.history_rounded,
          'My Upload Logs',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserActivityScreen()),
          ),
        ),
        _profileTile(
          Icons.image_rounded,
          'Change Profile Photo',
          pickProfileImage,
        ),
        Divider(color: _border, height: 24),
        _profileTile(Icons.logout_rounded, 'Logout', auth.logout, muted: true),
        _profileTile(Icons.delete_forever_rounded, 'Delete Account', () async {
          final ok = await _confirmDialog(
            title: 'Delete Account',
            content: 'This cannot be undone.',
            confirmLabel: 'Delete',
            danger: true,
          );
          if (ok == true) {
            final success = await context.read<AuthProvider>().deleteAccount();
            if (!mounted) return;
            if (success) Navigator.popUntil(context, (r) => r.isFirst);
          }
        }, danger: true),
      ],
    );
  }

  Widget _profileTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
    bool muted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: danger ? BockColors.error : BockColors.purple,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: danger
                ? BockColors.error
                : (muted ? _textSecondary : _textPrimary),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: _textSecondary.withValues(alpha: 0.5),
          size: 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ── Sidebar Item ──────────────────────────────────────────────────────────────
class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.selected
        ? BockColors.purple
        : widget.isDark
        ? BockColors.textSecondaryDark
        : BockColors.textSecondaryLight;

    return Tooltip(
      message: widget.label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? BockColors.purple.withValues(alpha: 0.18)
                        : _hovered
                        ? BockColors.purple.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: widget.selected
                        ? Border.all(
                            color: BockColors.purple.withValues(alpha: 0.35),
                          )
                        : null,
                  ),
                  child: Icon(widget.icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rank Badge ────────────────────────────────────────────────────────────────
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = [BockColors.gold, BockColors.silver, BockColors.bronze];
    final c = colors[rank - 1];
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 1.5),
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c),
        ),
      ),
    );
  }
}

// ── App List Tile ─────────────────────────────────────────────────────────────
class _AppListTile extends StatelessWidget {
  final AppModel app;
  final Future<bool> Function(int) isNewApp;
  final VoidCallback onTap;
  final bool isDark;
  final bool wishlisted;
  final VoidCallback onWishlistToggle;

  const _AppListTile({
    required this.app,
    required this.isNewApp,
    required this.onTap,
    required this.isDark,
    required this.wishlisted,
    required this.onWishlistToggle,
  });

  Color get _card => isDark ? BockColors.cardDark : BockColors.cardLight;
  Color get _border => isDark ? BockColors.borderDark : BockColors.borderLight;
  Color get _textPrimary =>
      isDark ? BockColors.textPrimaryDark : BockColors.textPrimaryLight;
  Color get _textSecondary =>
      isDark ? BockColors.textSecondaryDark : BockColors.textSecondaryLight;

  String _buttonText() {
    if (app.installedVersionCode == null) return 'Install';
    if (app.versionCode > app.installedVersionCode!) return 'Update';
    return 'Open';
  }

  @override
  Widget build(BuildContext context) {
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              app.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          FutureBuilder<bool>(
                            future: isNewApp(app.id),
                            builder: (_, snap) {
                              if (snap.data != true)
                                return const SizedBox.shrink();
                              return Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: BockColors.purple,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.category ?? 'Unknown',
                        style: TextStyle(fontSize: 11, color: _textSecondary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        app.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                          height: 1.4,
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
                            const SizedBox(width: 2),
                            Text(
                              app.averageRating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              '${app.downloadCount} downloads',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onWishlistToggle,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      wishlisted
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(wishlisted),
                      color: wishlisted
                          ? Colors.redAccent
                          : _textSecondary.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: BockColors.purple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _buttonText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── App Card (desktop grid) ───────────────────────────────────────────────────
class _AppCard extends StatefulWidget {
  final AppModel app;
  final Future<bool> Function(int) isNewApp;
  final bool isDark;
  final bool wishlisted;
  final VoidCallback onWishlistToggle;
  final VoidCallback onTap;

  const _AppCard({
    required this.app,
    required this.isNewApp,
    required this.isDark,
    required this.wishlisted,
    required this.onWishlistToggle,
    required this.onTap,
  });

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _hovered = false;

  Color get _card => widget.isDark ? BockColors.cardDark : BockColors.cardLight;
  Color get _border =>
      widget.isDark ? BockColors.borderDark : BockColors.borderLight;
  Color get _textPrimary =>
      widget.isDark ? BockColors.textPrimaryDark : BockColors.textPrimaryLight;
  Color get _textSecondary => widget.isDark
      ? BockColors.textSecondaryDark
      : BockColors.textSecondaryLight;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? BockColors.purple.withValues(alpha: 0.5)
                : _border,
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: BockColors.purple.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          getFullUrl(app.iconUrl),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: BockColors.purpleDim.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.apps_rounded,
                              color: BockColors.purpleLight,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<bool>(
                        future: widget.isNewApp(app.id),
                        builder: (_, snap) {
                          final isNew = snap.data ?? false;
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      app.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: _textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (isNew) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: BockColors.purple,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                app.category ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 5),
                      if (app.averageRating != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: BockColors.star,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${app.averageRating!.toStringAsFixed(1)}  ·  ${app.totalReviews}',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'No ratings yet',
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        '${app.downloadCount} download${app.downloadCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          app.description,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Wishlist heart
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: widget.onWishlistToggle,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          widget.wishlisted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          key: ValueKey(widget.wishlisted),
                          color: widget.wishlisted
                              ? Colors.redAccent
                              : _textSecondary.withValues(alpha: 0.4),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
