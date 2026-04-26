// ignore_for_file: unnecessary_underscores, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'app_detail_screen.dart';
import 'admin_upload_screen.dart';
import 'login_screen.dart';
import 'package:play_store_app/config/api_config.dart';
import 'package:play_store_app/config/url_helper.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'my_apps_screen.dart';
import 'admin_logs_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  Timer? _debounce;
  List<AppModel> apps = [];
  bool loading = true;
  String error = "";
  List recentUpdates = [];
  bool loadingUpdates = true;
  bool _isDarkMode = false;
  bool _isSearchOpen = false;
  final TextEditingController _mobileSearchController = TextEditingController();
  late final AnimationController _searchAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _searchWidth = CurvedAnimation(
    parent: _searchAnim,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _searchAnim,
    curve: Curves.easeIn,
  );

  // ── Wishlist state ─────────────────────────────────────────────────────────
  Set<String> _wishlistIds = {};
  static const _kWishlistKey = 'wishlist_ids';

  static const _purple = Color(0xFF6A1B9A);
  static const _bg = Color(0xFFF0F4F0);
  static const _bgDark = Color(0xFF121212);

  static const double _kRailWidth = 64;

  Color get _scaffoldBg => _isDarkMode ? _bgDark : _bg;
  Color get _cardBg => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textPrimary =>
      _isDarkMode ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDarkMode ? const Color(0xFFAAAAAA) : const Color(0xFF757575);
  Color get _appBarBg => _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;

  @override
  void initState() {
    super.initState();
    fetchApps();
    fetchRecentUpdates();
    loadWishlist();
    // ADDED: Login reminder notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthProvider>().isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to access all features.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mobileSearchController.dispose();
    _searchAnim.dispose();
    super.dispose();
  }

  // ── Wishlist methods ───────────────────────────────────────────────────────

  Future<void> loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kWishlistKey) ?? [];
    setState(() {
      _wishlistIds = saved.toSet();
    });
  }

  Future<void> toggleWishlist(int appId) async {
    final id = appId.toString();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_wishlistIds.contains(id)) {
        _wishlistIds.remove(id);
      } else {
        _wishlistIds.add(id);
      }
    });
    await prefs.setStringList(_kWishlistKey, _wishlistIds.toList());
  }

  bool isWishlisted(int appId) => _wishlistIds.contains(appId.toString());

  // ── Existing methods ───────────────────────────────────────────────────────

  Future<bool> isNewApp(int appId) async {
    final prefs = await SharedPreferences.getInstance();
    final seenApps = prefs.getStringList("seen_apps_v1") ?? [];
    if (seenApps.contains(appId.toString())) return false;
    return true;
  }

  Future<void> pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final auth = context.read<AuthProvider>();
      await auth.updateProfileImage(image);
    }
  }

  Future<void> markAppSeen(int appId) async {
    final prefs = await SharedPreferences.getInstance();
    final seenApps = prefs.getStringList("seen_apps_v1") ?? [];
    if (!seenApps.contains(appId.toString())) {
      seenApps.add(appId.toString());
      await prefs.setStringList("seen_apps_v1", seenApps);
    }
  }

  Future<void> fetchApps({String? query}) async {
    try {
      final data = await ApiService.fetchApps(search: query);
      if (!mounted) return;
      setState(() {
        apps = data.map((e) => AppModel.fromJson(e)).toList();
        loading = false;
        error = "";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = "Network error. Is backend running?";
        loading = false;
      });
    }
  }

  Future<void> fetchRecentUpdates() async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/apps/user/activity"),
      );
      final data = jsonDecode(res.body);
      setState(() {
        recentUpdates = data;
        loadingUpdates = false;
      });
    } catch (e) {
      setState(() => loadingUpdates = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.trim().isEmpty) {
        fetchApps();
      } else {
        fetchApps(query: value.trim());
      }
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: _purple, size: 22),
            const SizedBox(width: 8),
            Text(
              "Help",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _helpItem(
              Icons.search_rounded,
              "Search",
              "Use the search bar to find apps by name or category.",
            ),
            const SizedBox(height: 12),
            _helpItem(
              Icons.category_rounded,
              "Categories",
              "Browse all available apps.",
            ),
            const SizedBox(height: 12),
            _helpItem(
              Icons.favorite_rounded,
              "Wishlist",
              "Save apps you want to install later.",
            ),
            const SizedBox(height: 12),
            _helpItem(
              Icons.trending_up_rounded,
              "Top Apps",
              "See the most downloaded apps.",
            ),
            const SizedBox(height: 12),
            _helpItem(
              Icons.person_rounded,
              "Profile",
              "Manage your account and installed apps.",
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _purple, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _textPrimary,
                ),
              ),
              Text(desc, style: TextStyle(fontSize: 12, color: _textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    if (loading) {
      return Scaffold(
        backgroundColor: _scaffoldBg,
        body: const Center(child: CircularProgressIndicator(color: _purple)),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        backgroundColor: _scaffoldBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Color(0xFFBDBDBD),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                error,
                style: TextStyle(fontSize: 15, color: _textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: fetchApps,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
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
      backgroundColor: _scaffoldBg,
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (index) => setState(() => selectedIndex = index),
              backgroundColor: _appBarBg,
              selectedItemColor: _purple,
              unselectedItemColor: _textSecondary,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.category_rounded),
                  label: "Categories",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_rounded),
                  label: "Wishlist",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.trending_up_rounded),
                  label: "Most Downloaded",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: "Profile",
                ),
              ],
            ),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 68 : 62),
        child: Container(
          decoration: BoxDecoration(
            color: _appBarBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 14,
                vertical: isDesktop ? 10 : 8,
              ),
              child: isDesktop
                  ? _buildDesktopAppBar(auth)
                  : _buildMobileAppBar(auth),
            ),
          ),
        ),
      ),
      body: isDesktop
          ? Row(
              children: [
                _buildDesktopSidebar(),
                Expanded(child: apps.isEmpty ? _emptyState() : getMobileBody()),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: getMobileBody(),
              ),
            ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          "No apps found",
          style: TextStyle(fontSize: 16, color: _textSecondary),
        ),
      ],
    ),
  );

  Widget _buildDesktopSidebar() {
    final items = [
      (Icons.category_rounded, "Categories"),
      (Icons.favorite_rounded, "Wishlist"),
      (Icons.trending_up_rounded, "Top"),
      (Icons.person_rounded, "Profile"),
    ];

    return Container(
      width: _kRailWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
          right: BorderSide(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...List.generate(items.length, (index) {
            final (icon, label) = items[index];
            return _RailItem(
              icon: icon,
              label: label,
              isSelected: selectedIndex == index,
              isDarkMode: _isDarkMode,
              onTap: () => setState(() => selectedIndex = index),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDesktopAppBar(AuthProvider auth) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.storefront_rounded, color: _purple, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          "BOCK STORE",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: _searchBar()),
        const SizedBox(width: 12),
        if (auth.isAdmin) ...[
          Tooltip(
            message: "Upload App",
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
                );
                fetchApps();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: _purple,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: "App Activity Logs",
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLogsScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: _purple,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        auth.isLoggedIn
            ? _profileMenu(auth)
            : ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                child: const Text("Sign In"),
              ),
      ],
    );
  }

  Widget _buildMobileAppBar(AuthProvider auth) {
    Widget iconBtn({required IconData icon, required VoidCallback onTap}) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _purple, size: 18),
          ),
        );

    final rightIcons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBtn(
          icon: _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
          onTap: () {
            if (_isSearchOpen) {
              _searchAnim.reverse().then((_) {
                setState(() => _isSearchOpen = false);
                _mobileSearchController.clear();
                fetchApps();
              });
            } else {
              setState(() => _isSearchOpen = true);
              _searchAnim.forward();
            }
          },
        ),
        const SizedBox(width: 6),
        iconBtn(
          icon: _isDarkMode
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          onTap: () => setState(() => _isDarkMode = !_isDarkMode),
        ),
      ],
    );

    return Row(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _searchAnim,
            builder: (context, _) {
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
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _purple.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: _purple,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            "BOCK STORE",
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.4,
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
                          color: _isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF5FAF6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isDarkMode
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFE0EEE5),
                          ),
                        ),
                        child: TextField(
                          controller: _mobileSearchController,
                          autofocus: t == 1.0,
                          style: TextStyle(fontSize: 13, color: _textPrimary),
                          decoration: InputDecoration(
                            hintText: "Search apps...",
                            hintStyle: TextStyle(
                              color: _textSecondary.withOpacity(0.6),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 16,
                              color: _purple,
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
        rightIcons,
      ],
    );
  }

  Widget _searchBar({double height = 40}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5FAF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFE0EEE5),
        ),
      ),
      child: TextField(
        style: TextStyle(fontSize: 13, color: _textPrimary),
        decoration: InputDecoration(
          hintText: "Search apps...",
          hintStyle: TextStyle(
            color: _textSecondary.withOpacity(0.6),
            fontSize: 13,
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 17,
            color: _purple,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _profileMenu(AuthProvider auth) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == "toggle_theme") {
          setState(() => _isDarkMode = !_isDarkMode);
          return;
        }
        if (value == "upload") {
          await pickProfileImage();
        } else if (value == "my_apps") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyAppsScreen()),
          );
        } else if (value == "delete_account") {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Delete Account",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: const Text(
                "Are you sure you want to delete your account?\n\nThis action cannot be undone.",
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context, false),
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
                  child: const Text("Delete"),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );
          if (confirm == true) {
            final success = await context.read<AuthProvider>().deleteAccount();
            if (!mounted) return;
            if (success) Navigator.popUntil(context, (route) => route.isFirst);
          }
        } else if (value == "logout") {
          auth.logout();
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: CircleAvatar(
        radius: 17,
        backgroundColor: _purple.withOpacity(0.15),
        backgroundImage: auth.user?.profileImage != null
            ? NetworkImage(getFullUrl(auth.user!.profileImage))
            : null,
        child: auth.user?.profileImage == null
            ? Text(
                auth.user!.name[0].toUpperCase(),
                style: const TextStyle(
                  color: _purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            : null,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: "upload",
          child: Row(
            children: const [
              Icon(Icons.image_rounded, size: 18, color: _purple),
              SizedBox(width: 10),
              Text("Change Profile Image"),
            ],
          ),
        ),
        PopupMenuItem(
          value: "my_apps",
          child: Row(
            children: const [
              Icon(Icons.apps_rounded, size: 18, color: _purple),
              SizedBox(width: 10),
              Text("My Apps"),
            ],
          ),
        ),
        PopupMenuItem(
          value: "delete_account",
          child: Row(
            children: [
              Icon(
                Icons.delete_forever_rounded,
                size: 18,
                color: Colors.red.shade400,
              ),
              const SizedBox(width: 10),
              Text(
                "Delete Account",
                style: TextStyle(color: Colors.red.shade400),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: "toggle_theme",
          child: Row(
            children: [
              Icon(
                _isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                size: 18,
                color: _purple,
              ),
              const SizedBox(width: 10),
              Text(_isDarkMode ? "Light Mode" : "Dark Mode"),
            ],
          ),
        ),
        PopupMenuItem(
          value: "logout",
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, size: 18, color: Color(0xFF757575)),
              SizedBox(width: 10),
              Text("Logout"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopGrid(double width) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width > 1260
            ? 5
            : width > 960
            ? 4
            : 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.78,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return _AppCard(
          app: app,
          isNewApp: isNewApp,
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

  Widget getMobileBody() {
    switch (selectedIndex) {
      case 0:
        return buildCategories();
      case 1:
        return buildWishlist();
      case 2:
        return buildTopApps();
      case 3:
        return buildProfile();
      default:
        return buildCategories();
    }
  }

  Widget buildCategories() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return _AppListTile(
          app: app,
          isNewApp: isNewApp,
          isDarkMode: _isDarkMode,
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

  // ── Wishlist screen ───────────────────────────────────────────────────────
  Widget buildWishlist() {
    final wishlistedApps = apps.where((app) => isWishlisted(app.id)).toList();

    if (wishlistedApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No items in wishlist",
              style: TextStyle(color: _textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the heart on any app to save it here.",
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: wishlistedApps.length,
      itemBuilder: (context, index) {
        final app = wishlistedApps[index];
        return _AppListTile(
          app: app,
          isNewApp: isNewApp,
          isDarkMode: _isDarkMode,
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

  // ── Most Downloaded ───────────────────────────────────────────────────────
  Widget buildTopApps() {
    if (apps.isEmpty) {
      return Center(
        child: Text(
          "No apps available",
          style: TextStyle(color: _textSecondary, fontSize: 15),
        ),
      );
    }

    final sorted = [...apps]
      ..sort((a, b) => b.downloadCount.compareTo(a.downloadCount));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: _purple,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Most Downloaded",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      "${sorted.length} apps ranked by downloads",
                      style: TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final app = sorted[index];
            final rank = index + 1;

            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.04),
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
                            child: rank <= 3
                                ? _TopBadge(rank: rank)
                                : Text(
                                    "$rank",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
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
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5FAF6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.apps_rounded,
                                  color: _purple,
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
                                  app.developer ?? "Unknown Developer",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _purple,
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
                                      size: 13,
                                      color: _purple,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${app.downloadCount} download${app.downloadCount == 1 ? '' : 's'}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (app.averageRating != null) ...[
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 13,
                                        color: Color(0xFFFFC107),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        app.averageRating!.toStringAsFixed(1),
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
              ),
            );
          }, childCount: sorted.length),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget buildProfile() {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "Sign in to view your profile",
              style: TextStyle(color: _textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
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
                "Sign In",
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
                      radius: 44,
                      backgroundColor: _purple.withOpacity(0.15),
                      backgroundImage: auth.user?.profileImage != null
                          ? NetworkImage(getFullUrl(auth.user!.profileImage))
                          : null,
                      child: auth.user?.profileImage == null
                          ? Text(
                              auth.user!.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: _purple,
                                fontWeight: FontWeight.bold,
                                fontSize: 30,
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
                          color: _purple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 13,
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
              const SizedBox(height: 4),
              if (auth.isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Admin",
                    style: TextStyle(
                      color: _purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _profileTile(Icons.apps_rounded, "My Apps", () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyAppsScreen()),
          );
        }),
        if (auth.isAdmin) ...[
          _profileTile(
            Icons.admin_panel_settings_rounded,
            "Upload App",
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
              );
              fetchApps();
            },
          ),
          _profileTile(Icons.history_rounded, "Activity Logs", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLogsScreen()),
            );
          }),
        ],
        _profileTile(
          Icons.image_rounded,
          "Change Profile Image",
          pickProfileImage,
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        _profileTile(
          Icons.logout_rounded,
          "Logout",
          auth.logout,
          color: Colors.grey.shade600,
        ),
        _profileTile(Icons.delete_forever_rounded, "Delete Account", () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Delete Account",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: const Text(
                "Are you sure you want to delete your account?\n\nThis action cannot be undone.",
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context, false),
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
                  child: const Text("Delete"),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );
          if (confirm == true) {
            final success = await context.read<AuthProvider>().deleteAccount();
            if (!mounted) return;
            if (success) Navigator.popUntil(context, (route) => route.isFirst);
          }
        }, color: Colors.red.shade400),
      ],
    );
  }

  Widget _profileTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final tileColor = color ?? _textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color ?? _purple, size: 20),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tileColor,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: _textSecondary,
          size: 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ── Top rank badge (gold/silver/bronze) ──────────────────────────────────────
class _TopBadge extends StatelessWidget {
  final int rank;
  const _TopBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFB0BEC5),
      const Color(0xFFBF8970),
    ];
    final color = colors[rank - 1];

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          "$rank",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Rail Item ────────────────────────────────────────────────────────────────
class _RailItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hovered = false;
  static const _purple = Color(0xFF6A1B9A);

  @override
  Widget build(BuildContext context) {
    final Color iconColor = widget.isSelected
        ? _purple
        : widget.isDarkMode
        ? const Color(0xFFAAAAAA)
        : const Color(0xFF757575);

    final Color pillBg = widget.isSelected
        ? _purple.withOpacity(0.13)
        : _hovered
        ? _purple.withOpacity(0.07)
        : Colors.transparent;

    return Tooltip(
      message: widget.label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 30,
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(widget.icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: widget.isSelected
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
      ),
    );
  }
}

// ── App Card (desktop grid) ──────────────────────────────────────────────────
class _AppCard extends StatefulWidget {
  final AppModel app;
  final Future<bool> Function(int) isNewApp;
  final bool wishlisted;
  final VoidCallback onWishlistToggle;
  final VoidCallback onTap;

  const _AppCard({
    required this.app,
    required this.isNewApp,
    required this.wishlisted,
    required this.onWishlistToggle,
    required this.onTap,
  });

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _hovered = false;
  static const _purple = Color(0xFF6A1B9A);

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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? _purple.withOpacity(0.12)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _hovered ? 24 : 14,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                              color: const Color(0xFFF5FAF6),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.apps_rounded,
                              color: _purple,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<bool>(
                        future: widget.isNewApp(app.id),
                        builder: (context, snapshot) {
                          final isNew = snapshot.data ?? false;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Column(
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
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      app.category ?? "Unknown",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF757575),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isNew) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _purple,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    "NEW",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
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
                              color: Color(0xFFFFC107),
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                "${app.averageRating!.toStringAsFixed(1)}  ·  ${app.totalReviews}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      else
                        const Text(
                          "No ratings yet",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFBDBDBD),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        "${app.downloadCount} download${app.downloadCount == 1 ? '' : 's'}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFBDBDBD),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          app.description,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF757575),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                              : const Color(0xFFBDBDBD),
                          size: 20,
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

// ── App List Tile (mobile) ───────────────────────────────────────────────────
class _AppListTile extends StatelessWidget {
  final AppModel app;
  final Future<bool> Function(int) isNewApp;
  final VoidCallback onTap;
  final bool isDarkMode;
  final bool wishlisted;
  final VoidCallback onWishlistToggle;

  static const _purple = Color(0xFF6A1B9A);

  const _AppListTile({
    required this.app,
    required this.isNewApp,
    required this.onTap,
    required this.isDarkMode,
    required this.wishlisted,
    required this.onWishlistToggle,
  });

  String getButtonText(AppModel app) {
    if (app.installedVersionCode == null) return "Install";
    if (app.versionCode > app.installedVersionCode!) return "Update";
    return "Open";
  }

  Color get _cardBg => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textPrimary =>
      isDarkMode ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      isDarkMode ? const Color(0xFFAAAAAA) : const Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
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
                      color: const Color(0xFFF5FAF6),
                      child: const Icon(Icons.apps_rounded, color: _purple),
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
                            builder: (context, snapshot) {
                              if (snapshot.data != true) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _purple,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  "NEW",
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
                        app.category ?? "Unknown",
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
                              color: Color(0xFFFFC107),
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
                              "${app.downloadCount} downloads",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFBDBDBD),
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
                          : const Color(0xFFBDBDBD),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    getButtonText(app),
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
