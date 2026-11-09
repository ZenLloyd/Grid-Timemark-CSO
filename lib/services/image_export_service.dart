import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class ImageExportService {
  /// Merender widget di dalam [RepaintBoundary] menjadi file PNG beresolusi sangat tinggi (Ultra HD / 2.5K - 4K)
  /// sehingga saat dikirim ke WhatsApp teks watermark / timestamp tetap tajam, terbaca jelas, dan tidak burik.
  static Future<String> captureAndSaveToGallery({
    required GlobalKey boundaryKey,
    required String filePrefix,
    double? pixelRatio,
  }) async {
    final boundaryContext = boundaryKey.currentContext;
    if (boundaryContext == null) {
      throw Exception('Render boundary belum siap.');
    }

    final boundary =
        boundaryContext.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Gagal menemukan objek RenderRepaintBoundary.');
    }

    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw Exception('Izin penyimpanan ke galeri ditolak.');
      }
    }

    // Target resolusi ekspor Full HD / 2K (~2048px) agar sangat tajam di WhatsApp
    // dan aman dari batasan tekstur GPU perangkat Android (seperti Mali/PowerVR).
    final boundaryWidth = boundary.size.width;
    final double targetRatio = pixelRatio ??
        (boundaryWidth > 0 ? (2048.0 / boundaryWidth).clamp(2.5, 5.0) : 4.0);

    // Fallback bertahap jika GPU HP tertentu punya batas tekstur ketat
    ui.Image? image;
    final ratiosToTry = <double>{targetRatio, 4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0}.toList();
    for (final ratio in ratiosToTry) {
      try {
        image = await boundary.toImage(pixelRatio: ratio);
        break;
      } catch (_) {
        // Lanjut ke rasio berikutnya jika gagal
      }
    }

    if (image == null) {
      throw Exception('Memori perangkat penuh saat merender gambar.');
    }

    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Gagal mengonversi gambar ke format PNG.');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final Directory tempDir = await getTemporaryDirectory();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String filePath = '${tempDir.path}/${filePrefix}_$timestamp.png';

    final File file = File(filePath);
    await file.writeAsBytes(pngBytes, flush: true);

    await Gal.putImage(file.path, album: 'Grid & TimeMark');
    return file.path;
  }
}
