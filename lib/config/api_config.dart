import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }

    if (Platform.isAndroid) {
      const emulatorHost = "10.0.2.2";

      final host = emulatorHost;
      return "http://$host:3000";
    }

    return "http://localhost:3000";
  }
}
