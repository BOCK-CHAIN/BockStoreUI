// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_model.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';
import '../services/download_service.dart';
import '../providers/auth_provider.dart';
import 'admin_upload_screen.dart';
import 'developer_screen.dart';
import 'package:play_store_app/config/api_config.dart';
import 'package:play_store_app/config/url_helper.dart';
import 'package:play_store_app/widgets/manage_versions_sheet.dart';
import '../theme/bock_colors.dart';

class AppDetailScreen extends StatefulWidget {
  final AppModel app;
  final List<AppModel> allApps;

  const AppDetailScreen({
    super.key,
    required this.app,
    this.allApps = const [],
  });

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
  double downloadProgress = 0.0;

  int selectedRating = 0;
  final TextEditingController reviewController = TextEditingController();
  bool submittingRating = false;

  Color get _bg => BockColors.bgDark;
  Color get _card => BockColors.cardDark;
  Color get _border => BockColors.borderDark;
  Color get _surface => BockColors.surfaceDark;
  Color get _textPrimary => BockColors.textPrimaryDark;
  Color get _textSecondary => BockColors.textSecondaryDark;

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

  void _shareApp() {
    Share.share(
      'Check out ${currentApp.name} on Bock Store\nApp ID: ${currentApp.id}',
      subject: currentApp.name,
    );
  }

  void _openDeveloperScreen() {
    final developer = currentApp.developer;
    if (developer == null || developer.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DeveloperScreen(developerName: developer, allApps: widget.allApps),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _border),
        ),
        title: Text(
          'Delete App',
          style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: Text(
          'This cannot be undone.',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BockColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteApp();
  }

  Future<void> _deleteApp() async {
    final auth = context.read<AuthProvider>();
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/apps/${currentApp.id}'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App deleted'),
          backgroundColor: BockColors.purple,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete'),
          backgroundColor: BockColors.error,
        ),
      );
    }
  }

  Future<void> uninstallApp() async {
    final auth = context.read<AuthProvider>();
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/apps/${currentApp.id}/uninstall'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    if (res.statusCode == 200) {
      await fetchAppDetails();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uninstall failed')));
    }
  }

  void confirmUninstall() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _border),
        ),
        title: Text(
          'Uninstall App',
          style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: Text('Are you sure?', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await uninstallApp();
            },
            child: const Text(
              'Uninstall',
              style: TextStyle(color: BockColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> fetchAppDetails() async {
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/apps/${widget.app.id}'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (!mounted) return;
        setState(() {
          currentApp = AppModel.fromJson(data);
          ratingDistribution.clear();
          if (data['rating_distribution'] != null) {
            for (final item in data['rating_distribution']) {
              ratingDistribution[item['rating']] = item['count'];
            }
          }
          screenshots = (data['screenshots'] as List)
              .map((e) => getFullUrl(e as String))
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

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    if (!kIsWeb && Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt <= 28) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission required'),
                backgroundColor: BockColors.error,
              ),
            );
          return;
        }
      }
    }

    final auth = context.read<AuthProvider>();
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/apps/${currentApp.id}/download?platform=android',
        ),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (res.statusCode != 200)
        throw DownloadException('Backend returned ${res.statusCode}');

      final data = jsonDecode(res.body);
      final String downloadUrl = data['download_url'] as String;
      if (!downloadUrl.startsWith('https://'))
        throw DownloadException('Server returned a non-HTTPS URL');

      if (kIsWeb) {
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download started in your browser.'),
                backgroundColor: BockColors.purple,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          throw DownloadException('Could not open download URL.');
        }
        await fetchAppDetails();
        return;
      }

      final rawSegment = Uri.parse(
        downloadUrl,
      ).pathSegments.last.split('?').first;
      final fileName = rawSegment.isNotEmpty
          ? rawSegment
          : '${currentApp.name.replaceAll(' ', '_')}.apk';

      final apkFile = await DownloadService.instance.downloadApk(
        downloadUrl,
        fileName: fileName,
        onProgress: (p) {
          if (mounted) setState(() => downloadProgress = p);
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download complete — launching installer…'),
          backgroundColor: BockColors.purple,
        ),
      );
      await DownloadService.instance.installApk(apkFile);
      await fetchAppDetails();
    } on DownloadException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: BockColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: BockColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => isDownloading = false);
    }
  }

  Future<void> _handleInstallTap() async {
    if (isDownloading) return;
    final files = currentApp.files;
    if (files.isEmpty) return;
    if (files.length == 1) {
      await _downloadFile(files.first);
    } else {
      _showFilePicker();
    }
  }

  void _showFilePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final latestFiles = currentApp.files
            .where((f) => f['is_old'] != true)
            .toList();
        final oldFiles = currentApp.files
            .where((f) => f['is_old'] == true)
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose download',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...latestFiles.map((file) {
                  final label = file['label'] as String? ?? 'Download';
                  final type = (file['type'] as String? ?? 'other')
                      .toUpperCase();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: BockColors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: BockColors.purple.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          type,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: BockColors.purpleLight,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.download_rounded,
                      color: BockColors.purpleLight,
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _downloadFile(file);
                    },
                  );
                }),
                if (oldFiles.isNotEmpty) ...[
                  Divider(color: _border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.history_rounded, color: _textSecondary),
                    title: Text(
                      'Manage Versions',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: _textSecondary,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ManageVersionsButton(
                          appId: currentApp.id,
                          baseUrl: ApiConfig.baseUrl,
                          authToken: context.read<AuthProvider>().token,
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
      if (!mounted) return;
      setState(() {
        ratings = result;
        userRating = existing;
        if (existing != null) {
          selectedRating = existing.rating;
          reviewController.text = existing.reviewText ?? '';
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
      ).showSnackBar(const SnackBar(content: Text('Please login to rate.')));
      return;
    }
    setState(() => submittingRating = true);
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/apps/${currentApp.id}/rate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
      body: jsonEncode({
        'rating': selectedRating,
        'review_text': reviewController.text.trim(),
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      await fetchAppDetails();
      await fetchRatings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userRating != null ? 'Review updated.' : 'Review submitted.',
          ),
          backgroundColor: BockColors.purple,
        ),
      );
    }
    if (!mounted) return;
    setState(() => submittingRating = false);
  }

  Future<void> deleteRating() async {
    final auth = context.read<AuthProvider>();
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/apps/${currentApp.id}/rate'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    if (res.statusCode == 200) {
      await fetchAppDetails();
      await fetchRatings();
      if (!mounted) return;
      setState(() {
        selectedRating = 0;
        reviewController.clear();
        userRating = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review deleted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // NEW: show edit/delete only to the user who uploaded this app
    final bool isOwner =
        auth.isLoggedIn && currentApp.uploadedBy == auth.currentUserId;

    final apkFile = currentApp.files
        .where((f) => f['type'] == 'apk' && f['is_old'] != true)
        .firstOrNull;
    final bool isInstalled = currentApp.installedVersionCode != null;
    final bool isUpdate =
        isInstalled &&
        currentApp.installedVersionCode != currentApp.versionCode;
    final bool hasFiles = currentApp.files.isNotEmpty;
    final bool tapUninstalls = isInstalled && !isUpdate && apkFile != null;

    String buttonText = !isInstalled || apkFile == null
        ? 'Install'
        : isUpdate
        ? 'Update'
        : 'Uninstall';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: _textPrimary),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            currentApp.name,
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.share_rounded,
                color: BockColors.purpleLight,
              ),
              tooltip: 'Share',
              onPressed: _shareApp,
            ),
            // Edit and Delete only appear for the app's uploader
            if (isOwner) ...[
              IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  color: BockColors.purpleLight,
                ),
                tooltip: 'Edit',
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
                icon: Icon(
                  Icons.delete_rounded,
                  color: BockColors.error.withValues(alpha: 0.8),
                ),
                tooltip: 'Delete',
                onPressed: _confirmDelete,
              ),
            ],
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: _border),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                getFullUrl(currentApp.iconUrl),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentApp.name,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: _openDeveloperScreen,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            currentApp.developer ??
                                                'Unknown Developer',
                                            style: const TextStyle(
                                              color: BockColors.purpleLight,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor:
                                                  BockColors.purpleLight,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 14,
                                          color: BockColors.purpleLight,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 5,
                                    children: [
                                      _chip(
                                        Icons.code_rounded,
                                        'v${currentApp.version ?? 'N/A'}',
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
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: BockColors.purple.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: BockColors.purple.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              _statItem(
                                currentApp.averageRating != null
                                    ? '${currentApp.averageRating}★'
                                    : '—',
                                '${currentApp.totalReviews} reviews',
                              ),
                              _statDivider(),
                              _statItem(
                                '${currentApp.downloadCount}',
                                'Downloads',
                              ),
                              _statDivider(),
                              _statItem(
                                currentApp.ratedFor ?? 'N/A',
                                'Rated for',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (hasFiles) ...[
                          if (!kIsWeb && isDownloading) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: downloadProgress,
                                minHeight: 5,
                                backgroundColor: _border,
                                color: BockColors.purple,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Downloading… ${(downloadProgress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: isDownloading
                                  ? null
                                  : (!kIsWeb && tapUninstalls)
                                  ? confirmUninstall
                                  : _handleInstallTap,
                              icon: isDownloading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      kIsWeb
                                          ? Icons.download_rounded
                                          : Icons.android,
                                      size: 18,
                                    ),
                              label: Text(
                                isDownloading
                                    ? 'Downloading…'
                                    : kIsWeb
                                    ? 'Download'
                                    : tapUninstalls
                                    ? 'Uninstall'
                                    : currentApp.files.length > 1
                                    ? 'Download'
                                    : buttonText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BockColors.purple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _cardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Screenshots'),
                        const SizedBox(height: 14),
                        if (loadingScreenshots)
                          const Center(
                            child: CircularProgressIndicator(
                              color: BockColors.purple,
                            ),
                          )
                        else if (screenshots.isNotEmpty)
                          SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: screenshots.length,
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    screenshots[i],
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            'No screenshots available',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _cardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('About this app'),
                        const SizedBox(height: 10),
                        Text(
                          currentApp.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: _textSecondary,
                            height: 1.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _cardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Rate this app'),
                        const SizedBox(height: 14),
                        Row(
                          children: List.generate(5, (i) {
                            final star = i + 1;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedRating = star),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  star <= selectedRating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: BockColors.star,
                                  size: 34,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: reviewController,
                          maxLines: 3,
                          style: TextStyle(fontSize: 14, color: _textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Write a review (optional)',
                            hintStyle: TextStyle(
                              color: _textSecondary.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: _surface,
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: BockColors.purple,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: submittingRating
                                      ? null
                                      : submitRating,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: BockColors.purple,
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
                                              ? 'Update Review'
                                              : 'Submit Review',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (userRating != null) ...[
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: deleteRating,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: BockColors.error,
                                    side: BorderSide(
                                      color: BockColors.error.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Delete',
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
                  const SizedBox(height: 12),
                  _cardWidget(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Reviews'),
                        const SizedBox(height: 14),
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
                                  width: 24,
                                  child: Text(
                                    '$star',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: BockColors.star,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: count / total,
                                      backgroundColor: _border,
                                      color: BockColors.purple,
                                      minHeight: 5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                        Divider(color: _border),
                        const SizedBox(height: 14),
                        if (loadingRatings)
                          const Center(
                            child: CircularProgressIndicator(
                              color: BockColors.purple,
                            ),
                          )
                        else if (ratings.isEmpty)
                          Text(
                            'No reviews yet',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                            ),
                          )
                        else
                          ...ratings.map((rating) {
                            final date =
                                '${rating.createdAt.day}/${rating.createdAt.month}/${rating.createdAt.year}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: BockColors.purple
                                            .withValues(alpha: 0.2),
                                        backgroundImage:
                                            rating.profileImage != null
                                            ? NetworkImage(
                                                getFullUrl(rating.profileImage),
                                              )
                                            : null,
                                        child: rating.profileImage == null
                                            ? Text(
                                                rating.userName[0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: BockColors.purpleLight,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
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
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: _textPrimary,
                                              ),
                                            ),
                                            Text(
                                              date,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _textSecondary
                                                    .withValues(alpha: 0.7),
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
                                            color: BockColors.star,
                                            size: 13,
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
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _textSecondary,
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
                  const SizedBox(height: 12),
                  _buildHorizontalSection(
                    title:
                        'More by ${currentApp.developer ?? 'this developer'}',
                    apps: widget.allApps
                        .where(
                          (a) =>
                              a.id != currentApp.id &&
                              (a.developer ?? '') ==
                                  (currentApp.developer ?? ''),
                        )
                        .toList(),
                    emptyMsg: 'No other apps by this developer',
                  ),
                  const SizedBox(height: 12),
                  _buildHorizontalSection(
                    title: 'Similar apps',
                    apps: widget.allApps
                        .where(
                          (a) =>
                              a.id != currentApp.id &&
                              (a.category ?? '') ==
                                  (currentApp.category ?? '') &&
                              (a.category ?? '').isNotEmpty,
                        )
                        .toList(),
                    emptyMsg: 'No similar apps found',
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

  Widget _buildHorizontalSection({
    required String title,
    required List<AppModel> apps,
    required String emptyMsg,
  }) {
    return _cardWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          const SizedBox(height: 14),
          if (apps.isEmpty)
            Text(
              emptyMsg,
              style: TextStyle(color: _textSecondary, fontSize: 13),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: apps.length,
                itemBuilder: (_, i) {
                  final app = apps[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AppDetailScreen(app: app, allApps: widget.allApps),
                      ),
                    ),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              getFullUrl(app.iconUrl),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: BockColors.purpleDim.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.apps_rounded,
                                  color: BockColors.purpleLight,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            app.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (app.averageRating != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: BockColors.star,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  app.averageRating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardWidget({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: _textPrimary,
    ),
  );

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: BockColors.purple.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: BockColors.purple.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: BockColors.purpleLight),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _statItem(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
      ],
    ),
  );

  Widget _statDivider() =>
      Container(width: 1, height: 32, color: BockColors.borderDark);
}
