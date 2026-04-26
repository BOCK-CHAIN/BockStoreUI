import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return "https://bock-store-backend.vercel.app";
    }

    if (Platform.isAndroid) {
      return "https://bock-store-backend.vercel.app";
    }

    return "https://bock-store-backend.vercel.app";
  }
}
