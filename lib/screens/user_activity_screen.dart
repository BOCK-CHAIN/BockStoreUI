import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class UserActivityScreen extends StatefulWidget {
  const UserActivityScreen({super.key});

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  List activity = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchActivity();
  }

  Future<void> fetchActivity() async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/user/activity"),
      );

      final data = jsonDecode(res.body);

      setState(() {
        activity = data;
        loading = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() => loading = false);
    }
  }

  String formatAction(String action) {
    switch (action) {
      case "apk_updated":
        return "App Updated";
      case "uploaded":
        return "New App Added";
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recent Activity")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : activity.isEmpty
          ? const Center(child: Text("No recent updates"))
          : ListView.builder(
              itemCount: activity.length,
              itemBuilder: (context, index) {
                final log = activity[index];

                return ListTile(
                  leading: const Icon(Icons.system_update),
                  title: Text(log["app_name"]),
                  subtitle: Text(
                    "${formatAction(log["action"])} • v${log["version"] ?? ""}",
                  ),
                  trailing: Text(log["created_at"].toString().substring(0, 10)),
                );
              },
            ),
    );
  }
}
