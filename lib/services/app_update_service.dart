import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const String kCurrentAppVersion = '1.1.6';
const int kCurrentBuildNumber = 10;

const String kVersionJsonUrl =
    'https://raw.githubusercontent.com/ZenLloyd/Grid-Timemark-CSO/main/version.json';
const String kDefaultApkDownloadUrl =
    'https://github.com/ZenLloyd/Grid-Timemark-CSO/raw/main/Grid_TimeMark_alpha.apk';

class UpdateChangelogItem {
  final String title;
  final String description;

  const UpdateChangelogItem({
    required this.title,
    required this.description,
  });

  factory UpdateChangelogItem.fromJson(Map<String, dynamic> json) {
    return UpdateChangelogItem(
      title: (json['title'] as String?)?.trim() ?? 'Pembaruan',
      description: (json['description'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
      };
}

class AppUpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String apkUrl;
  final String releaseDate;
  final bool forceUpdate;
  final List<UpdateChangelogItem> changelog;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.apkUrl,
    this.releaseDate = '',
    this.forceUpdate = false,
    required this.changelog,
  });

  bool get isUpdateAvailable {
    if (latestBuildNumber > kCurrentBuildNumber) return true;
    return compareSemver(latestVersion, kCurrentAppVersion) > 0;
  }

  static int compareSemver(String a, String b) {
    final cleanA = a.replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanB = b.replaceAll(RegExp(r'[^0-9.]'), '');
    final partsA =
        cleanA.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB =
        cleanB.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final maxLen =
        partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < maxLen; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawList = json['changelog'];
    final List<UpdateChangelogItem> parsedChangelog = [];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          parsedChangelog.add(UpdateChangelogItem.fromJson(item));
        } else if (item is String && item.trim().isNotEmpty) {
          parsedChangelog.add(
            UpdateChangelogItem(title: item.trim(), description: ''),
          );
        }
      }
    }

    return AppUpdateInfo(
      latestVersion:
          (json['version'] as String?)?.trim() ?? kCurrentAppVersion,
      latestBuildNumber:
          (json['buildNumber'] as num?)?.toInt() ?? kCurrentBuildNumber,
      apkUrl: (json['apkUrl'] as String?)?.trim().isNotEmpty == true
          ? (json['apkUrl'] as String).trim()
          : kDefaultApkDownloadUrl,
      releaseDate: (json['releaseDate'] as String?)?.trim() ?? '',
      forceUpdate: (json['forceUpdate'] as bool?) ?? false,
      changelog: parsedChangelog,
    );
  }
}

class AppUpdateService {
  static const MethodChannel _channel =
      MethodChannel('id.tim.grid_and_timemark/updater');

  /// Memeriksa version.json terbaru dari GitHub repository.
  static Future<AppUpdateInfo?> checkForUpdate({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final uri = Uri.parse(
        '$kVersionJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store');
      request.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return AppUpdateInfo.fromJson(decoded);
      }
      return null;
    } catch (e) {
      debugPrint('Gagal memeriksa update: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Mengunduh file APK pembaruan langsung di dalam aplikasi dengan progress bar real-time.
  static Future<String> downloadApk({
    required String url,
    required void Function(int receivedBytes, int totalBytes) onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      final uri = Uri.parse(
        url.contains('?')
            ? '$url&t=${DateTime.now().millisecondsSinceEpoch}'
            : '$url?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
          'Gagal mengunduh APK (HTTP ${response.statusCode})',
        );
      }

      final totalBytes = response.contentLength;
      final tempDir = await getTemporaryDirectory();
      final outFile = File('${tempDir.path}/Grid_TimeMark_update.apk');
      if (await outFile.exists()) {
        await outFile.delete();
      }

      final fileSink = outFile.openWrite();
      sink = fileSink;
      int receivedBytes = 0;

      await for (final chunk in response) {
        if (isCancelled != null && isCancelled()) {
          await fileSink.close();
          sink = null;
          if (await outFile.exists()) {
            await outFile.delete();
          }
          throw Exception('Unduhan dibatalkan');
        }
        fileSink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }

      await fileSink.flush();
      await fileSink.close();
      sink = null;

      final stat = await outFile.stat();
      if (stat.size < 1024) {
        throw Exception('File APK yang diunduh tidak valid atau korup');
      }

      return outFile.path;
    } finally {
      await sink?.close();
      client.close();
    }
  }

  /// Memicu Android Package Installer untuk memasang file APK yang sudah diunduh.
  static Future<String> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Auto-install APK hanya didukung di Android');
    }
    final res = await _channel.invokeMethod<String>(
      'installApk',
      {'filePath': filePath},
    );
    return res ?? 'UNKNOWN';
  }
}
