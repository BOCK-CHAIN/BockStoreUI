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

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("App Activity Logs")),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, i) {
          final log = logs[i];

          return ListTile(
            leading: const Icon(Icons.history),
            title: Text(log["app_name"]),
            subtitle: Text("${log["action"]} - v${log["version"]}"),
            trailing: Text(log["created_at"]),
          );
        },
      ),
    );
  }
}
