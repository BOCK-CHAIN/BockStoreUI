import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

class _VersionFile {
  final int id;
  final String url;
  final String label;
  final bool isOld;
  final DateTime? createdAt;

  const _VersionFile({
    required this.id,
    required this.url,
    required this.label,
    required this.isOld,
    this.createdAt,
  });

  factory _VersionFile.fromJson(Map<String, dynamic> j) => _VersionFile(
    id: j['id'] as int,
    url: j['url'] as String,
    label: j['label'] as String? ?? j['url'] as String,
    isOld: j['is_old'] as bool? ?? true,
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String)
        : null,
  );
}

class _VersionGroup {
  final String type;
  final List<_VersionFile> files;

  const _VersionGroup({required this.type, required this.files});

  factory _VersionGroup.fromJson(Map<String, dynamic> j) => _VersionGroup(
    type: j['type'] as String,
    files: (j['files'] as List)
        .map((f) => _VersionFile.fromJson(f as Map<String, dynamic>))
        .toList(),
  );
}

// ─── Public entry-point widget ───────────────────────────────────────────────

class ManageVersionsButton extends StatefulWidget {
  final int appId;
  final String baseUrl;

  /// Optional auth token — pass it if your /versions endpoint is protected.
  final String? authToken;

  const ManageVersionsButton({
    super.key,
    required this.appId,
    required this.baseUrl,
    this.authToken,
  });

  @override
  State<ManageVersionsButton> createState() => _ManageVersionsButtonState();
}

class _ManageVersionsButtonState extends State<ManageVersionsButton> {
 
  List<_VersionGroup>? _groups;

  @override
  void initState() {
    super.initState();
    _fetchVersions();
  }

  Future<void> _fetchVersions() async {
    try {
      final uri = Uri.parse(
        '${widget.baseUrl}/api/apps/${widget.appId}/versions',
      );
      final headers = <String, String>{};
      if (widget.authToken != null) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }
      final response = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = (body['groups'] as List?) ?? [];
        setState(() {
          _groups = raw
              .map((g) => _VersionGroup.fromJson(g as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      // Silently hide the button on error — don't break the app detail screen
      if (mounted) setState(() => _groups = []);
    }
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ManageVersionsSheet(groups: _groups!, baseUrl: widget.baseUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Still loading → show nothing (no layout shift)
    if (_groups == null) return const SizedBox.shrink();
    // No history → hide the button entirely
    if (_groups!.isEmpty) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: _openSheet,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF6A1B9A), // Darker, clearer purple
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(
        Icons.history_rounded,
        size: 16,
        color: Color(0xFF6A1B9A),
      ),
      label: const Text('Manage versions'),
    );
  }
}

// ─── The bottom sheet itself ──────────────────────────────────────────────────

class _ManageVersionsSheet extends StatelessWidget {
  final List<_VersionGroup> groups;
  final String baseUrl;

  const _ManageVersionsSheet({required this.groups, required this.baseUrl});

  static const _typeIconMap = {
    'apk': Icons.android_rounded,
    'exe': Icons.window_rounded,
    'sh': Icons.terminal_rounded,
    'deb': Icons.bug_report_rounded,
    'rpm': Icons.layers_rounded,
    'dmg': Icons.laptop_mac_rounded,
    'zip': Icons.folder_zip_rounded,
  };

  static const _typeLabelMap = {
    'apk': 'Android APK',
    'exe': 'Windows Installer',
    'sh': 'Linux Shell Package',
    'deb': 'Debian Package',
    'rpm': 'RPM Package',
    'dmg': 'macOS Disk Image',
    'zip': 'ZIP Archive',
  };

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown date';
    return DateFormat('d MMM yyyy, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Manage versions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Version groups ─────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: groups.length,
                itemBuilder: (_, gi) {
                  final group = groups[gi];
                  final typeLabel =
                      _typeLabelMap[group.type] ?? group.type.toUpperCase();
                  final typeIcon =
                      _typeIconMap[group.type] ??
                      Icons.insert_drive_file_rounded;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        child: Row(
                          children: [
                            Icon(typeIcon, size: 16, color: cs.primary),
                            const SizedBox(width: 6),
                            Text(
                              typeLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${group.files.length} versions',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Version rows
                      ...group.files.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final file = entry.value;
                        final isCurrent = !file.isOld; // idx == 0

                        return _VersionTile(
                          file: file,
                          isCurrent: isCurrent,
                          versionNumber: group.files.length - idx,
                          // version n, n-1, n-2 … 1
                          formattedDate: _formatDate(file.createdAt),
                          baseUrl: baseUrl,
                        );
                      }),

                      if (gi < groups.length - 1) const Divider(height: 1),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single version row ───────────────────────────────────────────────────────

class _VersionTile extends StatelessWidget {
  final _VersionFile file;
  final bool isCurrent;
  final int versionNumber;
  final String formattedDate;
  final String baseUrl;

  const _VersionTile({
    required this.file,
    required this.isCurrent,
    required this.versionNumber,
    required this.formattedDate,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isCurrent
            ? cs.primaryContainer
            : cs.surfaceContainerHighest,
        child: Text(
          'v$versionNumber',
          style: theme.textTheme.labelSmall?.copyWith(
            color: isCurrent ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              file.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Current',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        formattedDate,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.download_rounded,
          color: isCurrent ? cs.primary : cs.onSurfaceVariant,
          size: 22,
        ),
        tooltip: isCurrent ? 'Download latest' : 'Download this version',
        onPressed: () async {
          final fullUrl = '${baseUrl}${file.url}';
          final uri = Uri.parse(fullUrl);

          try {
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              throw 'Could not launch $fullUrl';
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to open download link')),
            );
          }
        },
      ),
    );
  }
}
