import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  List logs = [];
  bool loading = true;

  static const _purple = Color(0xFF6A1B9A);

  Future fetchLogs() async {
    final auth = context.read<AuthProvider>();

    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/admin/app-logs"),
      headers: {
        "Authorization": "Bearer ${auth.token}",
        "Content-Type": "application/json",
      },
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      setState(() {
        logs = data;
        loading = false;
      });
    } else {
      debugPrint(data.toString());
      setState(() {
        loading = false;
      });
    }
  }

  /// Groups flat log list into { appName -> [log, log, ...] }
  Map<String, List<dynamic>> get _grouped {
    final Map<String, List<dynamic>> map = {};
    for (final log in logs) {
      final name = log["app_name"] as String;
      (map[name] ??= []).add(log);
    }
    return map;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}/"
          "${dt.month.toString().padLeft(2, '0')}/"
          "${dt.year}  "
          "${dt.hour.toString().padLeft(2, '0')}:"
          "${dt.minute.toString().padLeft(2, '0')}";
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
        return Colors.green.shade600;
      case 'apk_updated':
        return Colors.blue.shade600;
      case 'metadata_updated':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade500;
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
          "App Activity Logs",
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : logs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 56,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No activity logs yet",
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
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
                    final appName = entry.key;
                    final appLogs = entry.value;
                    final latestAction = appLogs.first["action"] as String;

                    return _AppLogCard(
                      appName: appName,
                      latestAction: latestAction,
                      logs: appLogs,
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

// ── Expandable app log card ───────────────────────────────────────────────────
class _AppLogCard extends StatefulWidget {
  final String appName;
  final String latestAction;
  final List<dynamic> logs;
  final String Function(String) formatDate;
  final IconData Function(String) actionIcon;
  final Color Function(String) actionColor;

  static const _purple = Color(0xFF6A1B9A);

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

  static const _purple = Color(0xFF6A1B9A);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        children: [
          // ── App header row (always visible) ─────────────────────────
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
                  // App icon placeholder
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.apps_rounded,
                      color: _purple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // App name + summary
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.appName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "${widget.logs.length} event${widget.logs.length == 1 ? '' : 's'}  ·  latest: ${widget.latestAction.replaceAll('_', ' ')}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expand chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _purple,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded log entries ──────────────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            ...widget.logs.asMap().entries.map((e) {
              final i = e.key;
              final log = e.value;
              final action = log["action"] as String;
              final version = log["version"] ?? "—";
              final date = widget.formatDate(log["created_at"] as String);
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
                        // Timeline dot + icon
                        Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: widget
                                    .actionColor(action)
                                    .withOpacity(0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.actionIcon(action),
                                size: 16,
                                color: widget.actionColor(action),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Action + version
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
                                "v$version",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Date
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFBDBDBD),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 64, color: Colors.grey.shade100),
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
