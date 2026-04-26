import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  DownloadService._();
  static final instance = DownloadService._();

  final Dio _dio = Dio();

  /// Resolves to: /sdcard/Android/data/com.example.play_store_app/files/apks/
  /// - Writable without WRITE_EXTERNAL_STORAGE on Android 10+
  /// - Covered by <external-files-path> in file_paths.xml
  /// - FileProvider can issue a content:// URI from here for the installer
  Future<Directory> _getApkDirectory() async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw DownloadException(
        'External storage is unavailable. '
        'Ensure the device has external storage mounted.',
      );
    }
    final apkDir = Directory('${dir.path}/apks');
    if (!apkDir.existsSync()) apkDir.createSync(recursive: true);
    return apkDir;
  }

  /// Downloads an APK from [url] (HTTPS only).
  /// [onProgress] is called with values 0.0 → 1.0.
  /// Throws [DownloadException] on any failure.
  Future<File> downloadApk(
    String url, {
    String fileName = 'app.apk',
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
  }) async {
    if (!url.startsWith('https://')) {
      throw DownloadException(
        'Refusing download: URL must use HTTPS.\nGot: $url',
      );
    }

    final dir = await _getApkDirectory();
    final savePath = '${dir.path}/$fileName';

    // Delete any stale/partial file from a previous attempt
    final stale = File(savePath);
    if (stale.existsSync()) {
      stale.deleteSync();
      print('[DownloadService] Deleted stale file: $savePath');
    }

    print('[DownloadService] Downloading → $savePath');
    print('[DownloadService] URL: $url');

    try {
      await _dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 15),
          // No custom Accept header — S3/Cloudinary pre-signed URLs are
          // strict about request headers matching what was signed.
          // Adding Accept causes a 403 on signed URLs.
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = received / total;
            print(
              '[DownloadService] ${(p * 100).toStringAsFixed(1)}% '
              '($received / $total bytes)',
            );
            onProgress?.call(p);
          }
        },
      );
    } on DioException catch (e) {
      if (File(savePath).existsSync()) File(savePath).deleteSync();
      throw DownloadException('Download failed: ${e.message ?? e.type.name}');
    }

    final file = File(savePath);
    if (!file.existsSync()) {
      throw DownloadException('File missing after download: $savePath');
    }

    final kb = (file.lengthSync() / 1024).toStringAsFixed(1);
    print('[DownloadService] Complete → $savePath ($kb KB)');
    return file;
  }

  /// Requests the "Install unknown apps" permission if not already granted.
  Future<bool> requestInstallPermission() async {
    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    print('[DownloadService] Requesting REQUEST_INSTALL_PACKAGES…');
    final result = await Permission.requestInstallPackages.request();
    print('[DownloadService] Permission result: ${result.name}');
    return result.isGranted;
  }

  /// Opens [apkFile] with the Android system package installer.
  Future<void> installApk(File apkFile) async {
    final allowed = await requestInstallPermission();
    if (!allowed) {
      throw DownloadException(
        'Install permission denied.\n'
        'Go to Settings → Apps → Special app access → '
        'Install unknown apps → allow this app.',
      );
    }

    print('[DownloadService] Launching installer: ${apkFile.path}');

    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );

    print(
      '[DownloadService] Installer result: ${result.type} — ${result.message}',
    );

    if (result.type != ResultType.done) {
      throw DownloadException('Could not open installer: ${result.message}');
    }
  }
}

class DownloadException implements Exception {
  final String message;
  const DownloadException(this.message);
  @override
  String toString() => 'DownloadException: $message';
}
