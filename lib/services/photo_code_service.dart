import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Catatan satu foto yang diambil lewat kamera Foto Mark.
class PhotoRecord {
  final String code;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String address;
  final String? fileSha256;

  const PhotoRecord({
    required this.code,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.address = '',
    this.fileSha256,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'capturedAt': capturedAt.toIso8601String(),
        'lat': latitude,
        'lon': longitude,
        'address': address,
        'sha256': fileSha256,
      };

  factory PhotoRecord.fromJson(Map<String, dynamic> j) => PhotoRecord(
        code: j['code'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        latitude: (j['lat'] as num?)?.toDouble(),
        longitude: (j['lon'] as num?)?.toDouble(),
        address: (j['address'] as String?) ?? '',
        fileSha256: j['sha256'] as String?,
      );
}

/// Kode Foto 14 karakter yang unik untuk SETIAP foto (bukan per sesi aplikasi),
/// plus riwayat lokal untuk pencocokan.
///
/// Batasan yang jujur: riwayat disimpan di HP ini saja. Verifikasi hanya
/// membuktikan "foto/kode ini pernah dibuat oleh aplikasi di HP ini".
/// Ini bukan bukti anti-manipulasi bagi pihak ketiga (itu butuh server).
class PhotoCodeService {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // tanpa I,O,0,1
  static final Random _rng = Random.secure();

  static String generateCode() =>
      List.generate(14, (_) => _alphabet[_rng.nextInt(_alphabet.length)])
          .join();

  static Future<File> _ledgerFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/photo_ledger.json');
  }

  static Future<List<PhotoRecord>> loadAll() async {
    try {
      final f = await _ledgerFile();
      if (!f.existsSync()) return [];
      final data = jsonDecode(await f.readAsString()) as List<dynamic>;
      return data
          .map((e) => PhotoRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(PhotoRecord record) async {
    final all = await loadAll();
    all.add(record);
    final f = await _ledgerFile();
    await f.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()),
        flush: true);
  }

  static Future<String> sha256OfFile(String path) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  static Future<PhotoRecord?> findByCode(String input) async {
    final code = input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.isEmpty) return null;
    final all = await loadAll();
    for (final r in all) {
      if (r.code == code) return r;
    }
    return null;
  }

  static Future<PhotoRecord?> findByFile(String path) async {
    final hash = await sha256OfFile(path);
    final all = await loadAll();
    for (final r in all) {
      if (r.fileSha256 == hash) return r;
    }
    return null;
  }
}
