import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../theme/bock_colors.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  List logs = [];
  bool loading = true;

  Future<void> fetchLogs() async {
    final auth = context.read<AuthProvider>();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/app-logs'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json',
      },
    );
    final data = jsonDecode(res.body);
    setState(() {
      logs = res.statusCode == 200 ? data : [];
      loading = false;
    });
  }

  Map<String, List<dynamic>> get _grouped {
    final map = <String, List<dynamic>>{};
    for (final log in logs) {
      (map[log['app_name'] as String] ??= []).add(log);
    }
    return map;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'uploaded':
        return Icons.cloud_upload_rounded;
      case 'apk_updated':
        return Icons.system_update_rounded;
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
        return const Color(0xFF7C3AED);
      case 'metadata_updated':
        return const Color(0xFFF59E0B);
      default:
        return BockColors.textSecondaryDark;
    }
  }

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BockColors.bgDark,
      appBar: AppBar(
        backgroundColor: BockColors.surfaceDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: BockColors.textPrimaryDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Upload Logs',
          style: TextStyle(
            color: BockColors.textPrimaryDark,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: BockColors.borderDark),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: BockColors.purple),
            )
          : logs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BockColors.purple.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BockColors.purple.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 40,
                      color: BockColors.purpleLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No activity logs yet',
                    style: TextStyle(
                      fontSize: 15,
                      color: BockColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _grouped.entries.map((entry) {
                    return _AppLogCard(
                      appName: entry.key,
                      latestAction: entry.value.first['action'] as String,
                      logs: entry.value,
                      formatDate: _formatDate,
                      actionIcon: _actionIcon,
                      actionColor: _actionColor,
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}

class _AppLogCard extends StatefulWidget {
  final String appName;
  final String latestAction;
  final List<dynamic> logs;
  final String Function(String) formatDate;
  final IconData Function(String) actionIcon;
  final Color Function(String) actionColor;

  const _AppLogCard({
    required this.appName,
    required this.latestAction,
    required this.logs,
    required this.formatDate,
    required this.actionIcon,
    required this.actionColor,
  });

  @override
  State<_AppLogCard> createState() => _AppLogCardState();
}

class _AppLogCardState extends State<_AppLogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: BockColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BockColors.borderDark),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(_expanded ? 0 : 16),
              bottomRight: Radius.circular(_expanded ? 0 : 16),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: BockColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: BockColors.purple.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.apps_rounded,
                      color: BockColors.purpleLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.appName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: BockColors.textPrimaryDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.logs.length} event${widget.logs.length == 1 ? '' : 's'}  ·  ${widget.latestAction.replaceAll('_', ' ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: BockColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: BockColors.purpleLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: BockColors.borderDark),
            ...widget.logs.asMap().entries.map((e) {
              final i = e.key;
              final log = e.value;
              final action = log['action'] as String;
              final version = log['version'] ?? '—';
              final date = widget.formatDate(log['created_at'] as String);
              final isLast = i == widget.logs.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: widget
                                .actionColor(action)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.actionIcon(action),
                            size: 16,
                            color: widget.actionColor(action),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: widget.actionColor(action),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'v$version',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: BockColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            color: BockColors.textSecondaryDark.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 64,
                      color: BockColors.borderDark,
                    ),
                ],
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
