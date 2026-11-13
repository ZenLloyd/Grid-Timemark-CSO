import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_settings_service.dart';
import '../services/image_export_service.dart';
import '../widgets/theme_toggle_button.dart';

/// Menyimpan data file foto beserta state transformasi individual (putar, zoom, flip, pan, fit, kunci, ukuran sel)
class GridPhotoEntry {
  XFile file;
  int quarterTurns; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool flipHorizontal;
  bool flipVertical;
  bool isLocked;
  BoxFit fitMode; // BoxFit.cover ('Isi') atau BoxFit.contain ('Paskan')
  double scale;
  double rotation; // Rotasi bebas interaktif (radian) dengan 2 jari persis video
  Offset panOffset;
  int? customCrossSpan; // Override lebar kolom (1..12) saat garis batas digeser
  double? customMainSpan; // Override tinggi baris saat garis batas digeser
  String? filterId; // Filter individual per foto (opsional)

  // State awal saat gestur cubit (pinch), putar (rotate), atau geser (pan) dimulai
  double startScale = 1.0;
  double startRotation = 0.0;
  Offset startPan = Offset.zero;
  Offset startFocalPoint = Offset.zero;

  GridPhotoEntry({
    required this.file,
    this.quarterTurns = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.isLocked = false,
    this.fitMode = BoxFit.cover,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.panOffset = Offset.zero,
    this.customCrossSpan,
    this.customMainSpan,
    this.filterId,
  });

  void rotateRight() {
    if (isLocked) return;
    quarterTurns = (quarterTurns + 1) % 4;
  }

  void rotateLeft() {
    if (isLocked) return;
    quarterTurns = (quarterTurns - 1 + 4) % 4;
  }

  void toggleFlipHorizontal() {
    if (isLocked) return;
    flipHorizontal = !flipHorizontal;
  }

  void toggleFlipVertical() {
    if (isLocked) return;
    flipVertical = !flipVertical;
  }

  void toggleFitMode() {
    if (isLocked) return;
    fitMode = (fitMode == BoxFit.cover) ? BoxFit.contain : BoxFit.cover;
    scale = 1.0;
    rotation = 0.0;
    panOffset = Offset.zero;
  }

  void setZoom(double newScale) {
    if (isLocked) return;
    scale = newScale.clamp(0.15, 6.0);
  }

  void nudge(double dx, double dy) {
    if (isLocked) return;
    panOffset = Offset(
      panOffset.dx + dx,
      panOffset.dy + dy,
    );
  }

  void resetTransform() {
    quarterTurns = 0;
    flipHorizontal = false;
    flipVertical = false;
    fitMode = BoxFit.cover;
    scale = 1.0;
    rotation = 0.0;
    panOffset = Offset.zero;
    customCrossSpan = null;
    customMainSpan = null;
  }

  void dispose() {}
}

class CollageFontOption {
  final String id;
  final String label;
  final String? fontFamily;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final double letterSpacing;

  const CollageFontOption({
    required this.id,
    required this.label,
    this.fontFamily,
    this.fontWeight = FontWeight.normal,
    this.fontStyle = FontStyle.normal,
    this.letterSpacing = 0.0,
  });

  TextStyle applyTo(TextStyle base) {
    return base.copyWith(
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
    );
  }
}

/// Model Teks Overlay di atas Kolase (Fitur "Teks Aa" di Video 2: 01:14 - 02:04)
class CollageTextOverlay {
  String text;
  Offset position; // Koordinat relatif di kanvas
  String fontFamily;
  Color textColor;
  Color? backgroundColor;
  Color? strokeColor;
  bool hasShadow;
  bool isNeon;
  double fontSize;
  double opacity;

  CollageTextOverlay({
    required this.text,
    this.position = const Offset(80, 120),
    this.fontFamily = 'sans_bold',
    this.textColor = Colors.white,
    this.backgroundColor,
    this.strokeColor,
    this.hasShadow = true,
    this.isNeon = false,
    this.fontSize = 22.0,
    this.opacity = 1.0,
  });
}

/// Model Preset Koleksi Gaya Teks (100% Gratis Tanpa Iklan / Tanpa Mahkota Pro)
class TextStylePreset {
  final String name;
  final String category; // Kancing, Simpel, Mood, Neon
  final Color textColor;
  final Color? backgroundColor;
  final Color? strokeColor;
  final bool isNeon;
  final bool hasShadow;

  const TextStylePreset({
    required this.name,
    required this.category,
    required this.textColor,
    this.backgroundColor,
    this.strokeColor,
    this.isNeon = false,
    this.hasShadow = false,
  });
}

const List<TextStylePreset> kFreeTextPresets = [
  TextStylePreset(
    name: 'Kancing Putih',
    category: 'Kancing',
    textColor: Color(0xFF111315),
    backgroundColor: Colors.white,
  ),
  TextStylePreset(
    name: 'Kancing Emerald',
    category: 'Kancing',
    textColor: Colors.white,
    backgroundColor: Color(0xFF10B981),
  ),
  TextStylePreset(
    name: 'Kancing Hitam',
    category: 'Kancing',
    textColor: Colors.white,
    backgroundColor: Color(0xFF111315),
  ),
  TextStylePreset(
    name: 'Kancing Kuning',
    category: 'Kancing',
    textColor: Color(0xFF111315),
    backgroundColor: Color(0xFFFACC15),
  ),
  TextStylePreset(
    name: 'Neon Biru',
    category: 'Neon',
    textColor: Colors.white,
    strokeColor: Color(0xFF38BDF8),
    isNeon: true,
    hasShadow: true,
  ),
  TextStylePreset(
    name: 'Neon Pink',
    category: 'Neon',
    textColor: Colors.white,
    strokeColor: Color(0xFFF43F5E),
    isNeon: true,
    hasShadow: true,
  ),
  TextStylePreset(
    name: 'Neon Hijau',
    category: 'Neon',
    textColor: Colors.white,
    strokeColor: Color(0xFF10B981),
    isNeon: true,
    hasShadow: true,
  ),
  TextStylePreset(
    name: 'Outline Tegas',
    category: 'Simpel',
    textColor: Colors.white,
    strokeColor: Color(0xFF111315),
    hasShadow: true,
  ),
  TextStylePreset(
    name: 'Mood Senja',
    category: 'Mood',
    textColor: Color(0xFFFEF3C7),
    backgroundColor: Color(0xFF7C2D12),
  ),
];

/// Model Stiker / Label Overlay (Fitur "Stiker" di Video 2: 02:20)
class CollageStickerOverlay {
  String label;
  Offset position;
  double scale;

  CollageStickerOverlay({
    required this.label,
    this.position = const Offset(110, 110),
    this.scale = 1.0,
  });
}

/// Model Foto dalam Foto / PIP (Fitur "Tambahkan -> Foto dalam Foto" di Video 2: 02:24)
class CollagePipOverlay {
  final XFile file;
  Offset position;
  double size;

  CollagePipOverlay({
    required this.file,
    this.position = const Offset(90, 90),
    this.size = 110.0,
  });
}

/// Model Goresan Kuas Menggambar Bebas (Fitur "Gambar" di Video 2: 02:25 - 02:38)
class FreehandStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool isNeon;
  final bool isEraser;

  FreehandStroke({
    required this.points,
    required this.color,
    this.strokeWidth = 6.0,
    this.opacity = 1.0,
    this.isNeon = false,
    this.isEraser = false,
  });
}

/// Model Filter Warna (Fitur "Filter" di Video 2: 02:06 - 02:17)
class CollageColorFilterSpec {
  final String id;
  final String name;
  final List<double> matrix;

  const CollageColorFilterSpec({
    required this.id,
    required this.name,
    required this.matrix,
  });
}

const List<CollageColorFilterSpec> kColorFilters = [
  CollageColorFilterSpec(
    id: 'none',
    name: 'Original',
    matrix: [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
  CollageColorFilterSpec(
    id: 'bright',
    name: 'Bright',
    matrix: [
      1.15, 0, 0, 0, 12,
      0, 1.15, 0, 0, 12,
      0, 0, 1.15, 0, 12,
      0, 0, 0, 1, 0,
    ],
  ),
  CollageColorFilterSpec(
    id: 'story',
    name: 'Story',
    matrix: [
      1.1, 0.05, 0, 0, 8,
      0, 1.05, 0.05, 0, 4,
      0, 0, 0.95, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
  CollageColorFilterSpec(
    id: 'warm',
    name: 'Warm',
    matrix: [
      1.15, 0, 0, 0, 15,
      0, 1.05, 0, 0, 5,
      0, 0, 0.85, 0, -10,
      0, 0, 0, 1, 0,
    ],
  ),
  CollageColorFilterSpec(
    id: 'dew',
    name: 'Dew',
    matrix: [
      0.9, 0, 0, 0, 0,
      0, 1.08, 0, 0, 8,
      0, 0, 1.18, 0, 14,
      0, 0, 0, 1, 0,
    ],
  ),
  CollageColorFilterSpec(
    id: 'cocoa',
    name: 'Cocoa',
    matrix: [
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
  CollageColorFilterSpec(
    id: 'grape',
    name: 'Grape',
    matrix: [
      1.08, 0, 0.12, 0, 6,
      0, 0.92, 0.05, 0, 0,
      0.10, 0, 1.18, 0, 12,
      0, 0, 0, 1, 0,
    ],
  ),
  CollageColorFilterSpec(
    id: 'bw',
    name: 'B&W',
    matrix: [
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
];

/// Definisi ukuran 1 kotak foto pada sistem grid 12-kolom
class GridCellSpan {
  final int crossAxisSpan; // 1..12
  final double mainAxisSpan;

  const GridCellSpan(this.crossAxisSpan, this.mainAxisSpan);
}

/// Spesifikasi 1 Template Tata Letak yang menyesuaikan jumlah foto N
class GridTemplateSpec {
  final String id;
  final String name;
  final bool isRowFirst;
  final List<List<int>> groups;
  final List<double>? defaultGroupWeights;
  final List<List<double>>? defaultItemWeights;
  final int crossAxisCount;
  final List<GridCellSpan> cells;

  const GridTemplateSpec({
    required this.id,
    required this.name,
    this.isRowFirst = true,
    required this.groups,
    this.defaultGroupWeights,
    this.defaultItemWeights,
    this.crossAxisCount = 12,
    required this.cells,
  });

  /// Menghitung total tinggi nominal seluruh baris dalam template (standar 12.0)
  double get totalNominalHeight {
    double totalH = 0.0;
    double currentRowH = 0.0;
    int currentCols = 0;
    for (final cell in cells) {
      currentCols += cell.crossAxisSpan;
      if (cell.mainAxisSpan > currentRowH) {
        currentRowH = cell.mainAxisSpan;
      }
      if (currentCols >= crossAxisCount) {
        totalH += currentRowH;
        currentCols = 0;
        currentRowH = 0.0;
      }
    }
    if (currentCols > 0) {
      totalH += currentRowH;
    }
    return totalH > 0.1 ? totalH : 12.0;
  }
}

/// Pilihan Rasio Kanvas (Persis tab "Rasio" di video GridArt: IG 1:1, IG 4:5, 5:4, 3:4, 9:16, 16:9, A4, dll.)
class AspectRatioOption {
  final String label;
  final double ratio; // width / height

  const AspectRatioOption(this.label, this.ratio);
}

const List<AspectRatioOption> kAspectRatios = [
  AspectRatioOption('IG 1:1', 1.0),
  AspectRatioOption('IG 4:5', 4 / 5),
  AspectRatioOption('5:4', 5 / 4),
  AspectRatioOption('3:4', 3 / 4),
  AspectRatioOption('4:3', 4 / 3),
  AspectRatioOption('2:3', 2 / 3),
  AspectRatioOption('3:2', 3 / 2),
  AspectRatioOption('9:16', 9 / 16),
  AspectRatioOption('16:9', 16 / 9),
  AspectRatioOption('A4', 1 / 1.414),
];

/// Generator 10+ Variasi Tata Letak (Wireframe Grid) Berdasarkan Jumlah Foto (1 s.d. 50 Foto)
class GridTemplateCatalog {
  static List<GridTemplateSpec> forPhotoCount(int count) {
    if (count <= 0) return const [];

    switch (count) {
      case 1:
        return [
          _createRowGridSpec(id: '1_1x1', name: 'Penuh', rowCounts: [1]),
        ];

      case 2:
        return [
          _createRowGridSpec(id: '2_1x2', name: '2 Kolom', rowCounts: [2]),
          _createRowGridSpec(id: '2_2x1', name: '2 Baris', rowCounts: [1, 1]),
          _createRowGridSpec(id: '2_top_big', name: 'Atas Besar', rowCounts: [1, 1], defaultGroupWeights: [1.6, 1.0]),
          _createRowGridSpec(id: '2_bot_big', name: 'Bawah Besar', rowCounts: [1, 1], defaultGroupWeights: [1.0, 1.6]),
          _createRowGridSpec(id: '2_left_big', name: 'Kiri Besar', rowCounts: [2], defaultItemWeights: [[1.6, 1.0]]),
          _createRowGridSpec(id: '2_right_big', name: 'Kanan Besar', rowCounts: [2], defaultItemWeights: [[1.0, 1.6]]),
        ];

      case 3:
        return [
          _createRowGridSpec(id: '3_1_2', name: '1 Atas 2 Bawah', rowCounts: [1, 2]),
          _createRowGridSpec(id: '3_2_1', name: '2 Atas 1 Bawah', rowCounts: [2, 1]),
          _createRowGridSpec(id: '3_1x3', name: '3 Kolom', rowCounts: [3]),
          _createRowGridSpec(id: '3_3x1', name: '3 Baris', rowCounts: [1, 1, 1]),
          _createColGridSpec(id: '3_l1_r2', name: '1 Kiri 2 Kanan', colCounts: [1, 2]),
          _createColGridSpec(id: '3_l2_r1', name: '2 Kiri 1 Kanan', colCounts: [2, 1]),
          _createRowGridSpec(id: '3_hero', name: 'Banner Utama', rowCounts: [1, 2], defaultGroupWeights: [1.6, 1.0]),
        ];

      case 4:
        return [
          _createRowGridSpec(id: '4_2x2', name: 'Grid 2x2', rowCounts: [2, 2]),
          _createRowGridSpec(id: '4_1_3', name: '1 Atas 3 Bawah', rowCounts: [1, 3], defaultGroupWeights: [1.4, 1.0]),
          _createRowGridSpec(id: '4_3_1', name: '3 Atas 1 Bawah', rowCounts: [3, 1], defaultGroupWeights: [1.0, 1.4]),
          _createColGridSpec(id: '4_l1_r3', name: '1 Kiri 3 Kanan', colCounts: [1, 3], defaultGroupWeights: [1.4, 1.0]),
          _createColGridSpec(id: '4_l3_r1', name: '3 Kiri 1 Kanan', colCounts: [3, 1], defaultGroupWeights: [1.0, 1.4]),
          _createRowGridSpec(id: '4_1x4', name: '4 Kolom', rowCounts: [4]),
          _createRowGridSpec(id: '4_4x1', name: '4 Baris', rowCounts: [1, 1, 1, 1]),
        ];

      case 5:
        return [
          _createRowGridSpec(id: '5_2_3', name: '2 Atas 3 Bawah', rowCounts: [2, 3]),
          _createRowGridSpec(id: '5_3_2', name: '3 Atas 2 Bawah', rowCounts: [3, 2]),
          _createRowGridSpec(id: '5_1_4', name: '1 Atas 4 Bawah', rowCounts: [1, 4], defaultGroupWeights: [1.5, 1.0]),
          _createRowGridSpec(id: '5_4_1', name: '4 Atas 1 Bawah', rowCounts: [4, 1], defaultGroupWeights: [1.0, 1.5]),
          _createRowGridSpec(id: '5_1_3_1', name: 'Tengah 3', rowCounts: [1, 3, 1]),
          _createRowGridSpec(id: '5_2_1_2', name: 'Tengah Besar', rowCounts: [2, 1, 2], defaultGroupWeights: [1.0, 1.5, 1.0]),
          _createColGridSpec(id: '5_l1_r4', name: '1 Kiri 4 Kanan', colCounts: [1, 4], defaultGroupWeights: [1.5, 1.0]),
          _createRowGridSpec(id: '5_1x5', name: '5 Kolom', rowCounts: [5]),
          _createRowGridSpec(id: '5_5x1', name: '5 Baris', rowCounts: [1, 1, 1, 1, 1]),
        ];

      case 6:
        return [
          _createRowGridSpec(id: '6_2x3', name: 'Grid 2x3', rowCounts: [3, 3]),
          _createRowGridSpec(id: '6_3x2', name: 'Grid 3x2', rowCounts: [2, 2, 2]),
          _createRowGridSpec(id: '6_1_5', name: '1 Atas 5 Bawah', rowCounts: [1, 5], defaultGroupWeights: [1.5, 1.0]),
          _createRowGridSpec(id: '6_2_4', name: '2 Atas 4 Bawah', rowCounts: [2, 4]),
          _createRowGridSpec(id: '6_4_2', name: '4 Atas 2 Bawah', rowCounts: [4, 2]),
          _createRowGridSpec(id: '6_1_4_1', name: 'Tengah 4', rowCounts: [1, 4, 1]),
          _createRowGridSpec(id: '6_1x6', name: '6 Kolom', rowCounts: [6]),
          _createRowGridSpec(id: '6_6x1', name: '6 Baris', rowCounts: [1, 1, 1, 1, 1, 1]),
        ];

      case 7:
        return [
          _createRowGridSpec(id: '7_3_4', name: '3 Atas 4 Bawah', rowCounts: [3, 4]),
          _createRowGridSpec(id: '7_4_3', name: '4 Atas 3 Bawah', rowCounts: [4, 3]),
          _createRowGridSpec(id: '7_2_3_2', name: 'Simetris 3 Baris', rowCounts: [2, 3, 2]),
          _createRowGridSpec(id: '7_1_3_3', name: '1 Atas 6 Bawah', rowCounts: [1, 3, 3], defaultGroupWeights: [1.4, 1.0, 1.0]),
          _createRowGridSpec(id: '7_3_1_3', name: 'Tengah Utama', rowCounts: [3, 1, 3], defaultGroupWeights: [1.0, 1.4, 1.0]),
          _createRowGridSpec(id: '7_2_2_3', name: '3 Baris A', rowCounts: [2, 2, 3]),
          _createRowGridSpec(id: '7_3_2_2', name: '3 Baris B', rowCounts: [3, 2, 2]),
        ];

      case 8:
        return [
          _createRowGridSpec(id: '8_2x4', name: 'Grid 2x4', rowCounts: [4, 4]),
          _createRowGridSpec(id: '8_4x2', name: 'Grid 4x2', rowCounts: [2, 2, 2, 2]),
          _createRowGridSpec(id: '8_3_2_3', name: 'Simetris 3 Baris', rowCounts: [3, 2, 3]),
          _createRowGridSpec(id: '8_2_4_2', name: 'Tengah 4', rowCounts: [2, 4, 2]),
          _createRowGridSpec(id: '8_1_3_4', name: '1 Atas 7 Bawah', rowCounts: [1, 3, 4], defaultGroupWeights: [1.4, 1.0, 1.0]),
          _createRowGridSpec(id: '8_3_3_2', name: '3 Baris A', rowCounts: [3, 3, 2]),
          _createRowGridSpec(id: '8_2_3_3', name: '3 Baris B', rowCounts: [2, 3, 3]),
        ];

      case 9:
        return [
          _createRowGridSpec(id: '9_3x3', name: 'Grid 3x3', rowCounts: [3, 3, 3]),
          _createRowGridSpec(id: '9_4_5', name: '4 Atas 5 Bawah', rowCounts: [4, 5]),
          _createRowGridSpec(id: '9_5_4', name: '5 Atas 4 Bawah', rowCounts: [5, 4]),
          _createRowGridSpec(id: '9_1_4_4', name: '1 Atas 8 Bawah', rowCounts: [1, 4, 4], defaultGroupWeights: [1.4, 1.0, 1.0]),
          _createRowGridSpec(id: '9_2_5_2', name: 'Tengah 5', rowCounts: [2, 5, 2]),
          _createRowGridSpec(id: '9_2_3_2_2', name: '4 Baris', rowCounts: [2, 3, 2, 2]),
          _createRowGridSpec(id: '9_3_3_3_c', name: 'Tengah Besar', rowCounts: [3, 3, 3], defaultGroupWeights: [1.0, 1.4, 1.0]),
        ];

      case 10:
        return [
          _createRowGridSpec(id: '10_2x5', name: 'Grid 2x5', rowCounts: [5, 5]),
          _createRowGridSpec(id: '10_5x2', name: 'Grid 5x2', rowCounts: [2, 2, 2, 2, 2]),
          _createRowGridSpec(id: '10_3_4_3', name: 'Simetris 3 Baris', rowCounts: [3, 4, 3]),
          _createRowGridSpec(id: '10_4_2_4', name: 'Tengah 2', rowCounts: [4, 2, 4]),
          _createRowGridSpec(id: '10_3_2_2_3', name: 'Simetris 4 Baris', rowCounts: [3, 2, 2, 3]),
          _createRowGridSpec(id: '10_1_3_3_3', name: '1 Atas 9 Bawah', rowCounts: [1, 3, 3, 3], defaultGroupWeights: [1.4, 1.0, 1.0, 1.0]),
        ];

      case 11:
        return [
          _createRowGridSpec(id: '11_4_3_4', name: 'Simetris 3 Baris', rowCounts: [4, 3, 4]),
          _createRowGridSpec(id: '11_3_5_3', name: 'Tengah 5', rowCounts: [3, 5, 3]),
          _createRowGridSpec(id: '11_3_3_3_2', name: '4 Baris A', rowCounts: [3, 3, 3, 2]),
          _createRowGridSpec(id: '11_2_3_3_3', name: '4 Baris B', rowCounts: [2, 3, 3, 3]),
          _createRowGridSpec(id: '11_1_5_5', name: '1 Atas 10 Bawah', rowCounts: [1, 5, 5], defaultGroupWeights: [1.4, 1.0, 1.0]),
          _createRowGridSpec(id: '11_3_4_4', name: '3 Baris A', rowCounts: [3, 4, 4]),
          _createRowGridSpec(id: '11_4_4_3', name: '3 Baris B', rowCounts: [4, 4, 3]),
        ];

      case 12:
        return [
          _createRowGridSpec(id: '12_3x4', name: 'Grid 3x4', rowCounts: [4, 4, 4]),
          _createRowGridSpec(id: '12_4x3', name: 'Grid 4x3', rowCounts: [3, 3, 3, 3]),
          _createRowGridSpec(id: '12_2x6', name: 'Grid 2x6', rowCounts: [6, 6]),
          _createRowGridSpec(id: '12_6x2', name: 'Grid 6x2', rowCounts: [2, 2, 2, 2, 2, 2]),
          _createRowGridSpec(id: '12_3_6_3', name: 'Tengah 6', rowCounts: [3, 6, 3]),
          _createRowGridSpec(id: '12_1_4_4_3', name: '1 Atas 11 Bawah', rowCounts: [1, 4, 4, 3], defaultGroupWeights: [1.4, 1.0, 1.0, 1.0]),
        ];

      case 13:
        return [
          _createRowGridSpec(id: '13_3_4_3_3', name: '4 Baris A', rowCounts: [3, 4, 3, 3]),
          _createRowGridSpec(id: '13_4_3_3_3', name: '4 Baris B', rowCounts: [4, 3, 3, 3]),
          _createRowGridSpec(id: '13_3_3_4_3', name: '4 Baris C', rowCounts: [3, 3, 4, 3]),
          _createRowGridSpec(id: '13_4_5_4', name: 'Simetris 3 Baris', rowCounts: [4, 5, 4]),
          _createRowGridSpec(id: '13_1_4_4_4', name: '1 Atas 12 Bawah', rowCounts: [1, 4, 4, 4], defaultGroupWeights: [1.4, 1.0, 1.0, 1.0]),
        ];

      case 14:
        return [
          _createRowGridSpec(id: '14_2x7', name: 'Grid 2x7', rowCounts: [7, 7]),
          _createRowGridSpec(id: '14_4_3_3_4', name: 'Simetris 4 Baris', rowCounts: [4, 3, 3, 4]),
          _createRowGridSpec(id: '14_3_4_4_3', name: '4 Baris Tengah', rowCounts: [3, 4, 4, 3]),
          _createRowGridSpec(id: '14_5_4_5', name: 'Simetris 3 Baris', rowCounts: [5, 4, 5]),
          _createRowGridSpec(id: '14_4_4_3_3', name: '4 Baris Rapi', rowCounts: [4, 4, 3, 3]),
          _createRowGridSpec(id: '14_1_4_5_4', name: '1 Atas 13 Bawah', rowCounts: [1, 4, 5, 4], defaultGroupWeights: [1.4, 1.0, 1.0, 1.0]),
        ];

      case 15:
        return [
          _createRowGridSpec(id: '15_3x5', name: 'Grid 3x5', rowCounts: [5, 5, 5]),
          _createRowGridSpec(id: '15_5x3', name: 'Grid 5x3', rowCounts: [3, 3, 3, 3, 3]),
          _createRowGridSpec(id: '15_4_4_4_3', name: '4 Baris A', rowCounts: [4, 4, 4, 3]),
          _createRowGridSpec(id: '15_3_4_4_4', name: '4 Baris B', rowCounts: [3, 4, 4, 4]),
          _createRowGridSpec(id: '15_4_3_4_4', name: '4 Baris C', rowCounts: [4, 3, 4, 4]),
          _createRowGridSpec(id: '15_1_5_5_4', name: '1 Atas 14 Bawah', rowCounts: [1, 5, 5, 4], defaultGroupWeights: [1.4, 1.0, 1.0, 1.0]),
        ];

      case 16:
        return [
          _createRowGridSpec(id: '16_4x4', name: 'Grid 4x4', rowCounts: [4, 4, 4, 4]),
          _createRowGridSpec(id: '16_2x8', name: 'Grid 2x8', rowCounts: [8, 8]),
          _createRowGridSpec(id: '16_8x2', name: 'Grid 8x2', rowCounts: [2, 2, 2, 2, 2, 2, 2, 2]),
          _createRowGridSpec(id: '16_5_6_5', name: 'Simetris 3 Baris', rowCounts: [5, 6, 5]),
          _createRowGridSpec(id: '16_1_5_5_5', name: '1 Atas 15 Bawah', rowCounts: [1, 5, 5, 5], defaultGroupWeights: [1.4, 1.0, 1.0, 1.0]),
        ];

      case 17:
        return [
          _createRowGridSpec(id: '17_4_5_4_4', name: '4 Baris A', rowCounts: [4, 5, 4, 4]),
          _createRowGridSpec(id: '17_4_4_5_4', name: '4 Baris B', rowCounts: [4, 4, 5, 4]),
          _createRowGridSpec(id: '17_5_4_4_4', name: '4 Baris C', rowCounts: [5, 4, 4, 4]),
          _createRowGridSpec(id: '17_3_4_3_4_3', name: 'Simetris 5 Baris', rowCounts: [3, 4, 3, 4, 3]),
          _createRowGridSpec(id: '17_1_4x4', name: '1 Atas 16 Bawah', rowCounts: [1, 4, 4, 4, 4], defaultGroupWeights: [1.4, 1.0, 1.0, 1.0, 1.0]),
        ];

      case 18:
        return [
          _createRowGridSpec(id: '18_3x6', name: 'Grid 3x6', rowCounts: [6, 6, 6]),
          _createRowGridSpec(id: '18_6x3', name: 'Grid 6x3', rowCounts: [3, 3, 3, 3, 3, 3]),
          _createRowGridSpec(id: '18_2x9', name: 'Grid 2x9', rowCounts: [9, 9]),
          _createRowGridSpec(id: '18_5_4_5_4', name: '4 Baris A', rowCounts: [5, 4, 5, 4]),
          _createRowGridSpec(id: '18_4_5_4_5', name: '4 Baris B', rowCounts: [4, 5, 4, 5]),
          _createRowGridSpec(id: '18_4_4_3_4_3', name: '5 Baris', rowCounts: [4, 4, 3, 4, 3]),
        ];

      case 19:
        return [
          _createRowGridSpec(id: '19_5_5_5_4', name: '4 Baris A', rowCounts: [5, 5, 5, 4]),
          _createRowGridSpec(id: '19_4_5_5_5', name: '4 Baris B', rowCounts: [4, 5, 5, 5]),
          _createRowGridSpec(id: '19_5_4_5_5', name: '4 Baris C', rowCounts: [5, 4, 5, 5]),
          _createRowGridSpec(id: '19_4_4_4_4_3', name: '5 Baris', rowCounts: [4, 4, 4, 4, 3]),
        ];

      case 20:
        return [
          _createRowGridSpec(id: '20_4x5', name: 'Grid 4x5', rowCounts: [5, 5, 5, 5]),
          _createRowGridSpec(id: '20_5x4', name: 'Grid 5x4', rowCounts: [4, 4, 4, 4, 4]),
          _createRowGridSpec(id: '20_2x10', name: 'Grid 2x10', rowCounts: [10, 10]),
          _createRowGridSpec(id: '20_6_4_6_4', name: '4 Baris A', rowCounts: [6, 4, 6, 4]),
          _createRowGridSpec(id: '20_4_6_4_6', name: '4 Baris B', rowCounts: [4, 6, 4, 6]),
          _createRowGridSpec(id: '20_1_5x4', name: '1 Atas 19 Bawah', rowCounts: [1, 5, 5, 5, 4], defaultGroupWeights: [1.4, 1.0, 1.0, 1.0, 1.0]),
        ];

      default:
        final int sqrtRows = math.sqrt(count).round().clamp(3, 8);
        final int tallerRows = (sqrtRows + 1).clamp(4, 10);
        final int widerRows = (sqrtRows - 1).clamp(3, 7);
        final rowsBalanced = _evenDistribute(count, sqrtRows, topHeavy: true);
        final rowsBottom = _evenDistribute(count, sqrtRows, topHeavy: false);
        final rowsTall = _evenDistribute(count, tallerRows, topHeavy: true);
        final rowsWide = _evenDistribute(count, widerRows, topHeavy: true);
        return [
          _createRowGridSpec(
            id: '${count}_balanced',
            name: 'Seimbang ($sqrtRows Baris)',
            rowCounts: rowsBalanced,
          ),
          _createRowGridSpec(
            id: '${count}_pyramid',
            name: 'Rapi ($sqrtRows Baris B)',
            rowCounts: rowsBottom,
          ),
          _createRowGridSpec(
            id: '${count}_tall',
            name: 'Rapat ($tallerRows Baris)',
            rowCounts: rowsTall,
          ),
          _createRowGridSpec(
            id: '${count}_wide',
            name: 'Lebar ($widerRows Baris)',
            rowCounts: rowsWide,
          ),
        ];
    }
  }

  static List<int> _evenDistribute(int total, int numRows, {bool topHeavy = true}) {
    final int base = total ~/ numRows;
    final int rem = total % numRows;
    final List<int> rows = List.generate(numRows, (i) {
      if (topHeavy) {
        return i < rem ? base + 1 : base;
      } else {
        return i >= (numRows - rem) ? base + 1 : base;
      }
    });
    return rows.where((r) => r > 0).toList();
  }

  static GridTemplateSpec _createRowGridSpec({
    required String id,
    required String name,
    required List<int> rowCounts,
    List<double>? defaultGroupWeights,
    List<List<double>>? defaultItemWeights,
  }) {
    final double rowHeight = 12.0 / (rowCounts.isNotEmpty ? rowCounts.length : 1);
    return GridTemplateSpec(
      id: id,
      name: name,
      isRowFirst: true,
      groups: _buildGroupsFromRowCounts(rowCounts),
      defaultGroupWeights: defaultGroupWeights,
      defaultItemWeights: defaultItemWeights,
      cells: _buildRowCells(rowCounts, rowHeight: rowHeight),
    );
  }

  static GridTemplateSpec _createColGridSpec({
    required String id,
    required String name,
    required List<int> colCounts,
    List<double>? defaultGroupWeights,
    List<List<double>>? defaultItemWeights,
  }) {
    final double colWidth = 12.0 / (colCounts.isNotEmpty ? colCounts.length : 1);
    return GridTemplateSpec(
      id: id,
      name: name,
      isRowFirst: false,
      groups: _buildGroupsFromRowCounts(colCounts),
      defaultGroupWeights: defaultGroupWeights,
      defaultItemWeights: defaultItemWeights,
      cells: _buildRowCells(colCounts, rowHeight: colWidth),
    );
  }

  static List<List<int>> _buildGroupsFromRowCounts(
    List<int> rowCounts, {
    int startIndex = 0,
  }) {
    final List<List<int>> groups = [];
    int cur = startIndex;
    for (final count in rowCounts) {
      if (count > 0) {
        groups.add(List.generate(count, (i) => cur + i));
        cur += count;
      }
    }
    return groups;
  }

  static List<GridCellSpan> _buildRowCells(
    List<int> rowCounts, {
    required double rowHeight,
  }) {
    final List<GridCellSpan> spans = [];
    for (final countInRow in rowCounts) {
      final int crossSpan = (12 ~/ countInRow).clamp(1, 12);
      for (int i = 0; i < countInRow; i++) {
        spans.add(GridCellSpan(crossSpan, rowHeight));
      }
    }
    return spans;
  }
}

/// Tab aktif di Bottom Sheet Editor (Persis Video 1 & Video 2 GridArt + Fitur Bang Paang)
enum EditorBottomTab {
  tataLetak('Tata Letak', Icons.space_dashboard_outlined),
  margin('Margin', Icons.padding_rounded),
  rasio('Rasio', Icons.aspect_ratio_rounded),
  latar('Latar belakang', Icons.format_color_fill_rounded),
  bingkai('Bingkai', Icons.border_style_rounded),
  teks('Teks', Icons.text_fields_rounded),
  filter('Filter', Icons.auto_fix_high_rounded),
  stiker('Stiker', Icons.emoji_emotions_outlined),
  tambahkan('Tambahkan', Icons.add_photo_alternate_outlined),
  gambar('Gambar', Icons.gesture_rounded);

  final String label;
  final IconData icon;
  const EditorBottomTab(this.label, this.icon);
}

class GridScreen extends StatefulWidget {
  final bool autoOpenPicker;
  final List<XFile>? initialPhotos;
  const GridScreen({
    super.key,
    this.autoOpenPicker = false,
    this.initialPhotos,
  });

  @override
  State<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends State<GridScreen> {
  static const int maxPhotos = 50;

  final ImagePicker _picker = ImagePicker();
  final GlobalKey _gridBoundaryKey = GlobalKey();
  final TextEditingController _textInputController = TextEditingController();

  final List<GridPhotoEntry> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadGridSettings();
    if (widget.initialPhotos != null && widget.initialPhotos!.isNotEmpty) {
      _photos.addAll(widget.initialPhotos!.map((f) => GridPhotoEntry(file: f)));
      _isPhotoPickerStage = false;
      _activeSheetTab = EditorBottomTab.tataLetak;
    } else if (widget.autoOpenPicker && _photos.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImagesFromDevice();
      });
    }
  }

  Future<void> _loadGridSettings() async {
    final s = await AppSettingsService.loadGridSettings();
    if (!mounted) return;
    setState(() {
      _selectedRatioIndex = s.selectedRatioIndex.clamp(0, kAspectRatios.length - 1);
      _outerMargin = s.outerMargin;
      _innerSpacing = s.innerSpacing;
      _cornerRadius = s.cornerRadius;
      _borderWidth = s.borderWidth;
      _borderColor = Color(s.borderColorValue);
      _backgroundColor = Color(s.backgroundColorValue);
      _isTransparentPngBg = s.isTransparentPngBg;
    });
  }

  void _saveGridSettings() {
    AppSettingsService.saveGridSettings(GridSettingsData(
      selectedRatioIndex: _selectedRatioIndex,
      outerMargin: _outerMargin,
      innerSpacing: _innerSpacing,
      cornerRadius: _cornerRadius,
      borderWidth: _borderWidth,
      borderColorValue: _borderColor.toARGB32(),
      backgroundColorValue: _backgroundColor.toARGB32(),
      isTransparentPngBg: _isTransparentPngBg,
    ));
  }

  // Mode Layar: true = Layar Pilih Foto (Tray Bawah seperti di video 00:01-00:09), false = Layar Editor Kolase
  bool _isPhotoPickerStage = true;

  // Seleksi Foto & Mode Tukar (Persis Video 2: 00:03 - 00:54)
  int? _selectedPhotoIndex;
  bool _showContextualPhotoBar = false;
  bool _isSwapModeActive = false; // Saat true -> tampil toast "Pilih foto untuk ditukar"
  int? _activeGesturePhotoIndex; // Foto yang sedang fokus aktif menerima gestur cubit / geser / rotasi

  int _selectedTemplateIndex = 0;
  int _selectedRatioIndex = 0; // Default IG 1:1

  // Bobot Proporsional Partisi Kolase (100% Full Kanvas & Resizing Lancar Persis Video)
  List<double> _layoutGroupWeights = [];
  List<List<double>> _layoutItemWeights = [];

  GridTemplateSpec? _getActiveTemplate() {
    final count = _photos.length;
    final templates = GridTemplateCatalog.forPhotoCount(count);
    if (templates.isEmpty) return null;
    return templates[_selectedTemplateIndex.clamp(0, templates.length - 1)];
  }

  static int _calculateCacheWidth(int totalPhotos) {
    if (totalPhotos <= 1) return 1080;
    if (totalPhotos <= 4) return 720;
    if (totalPhotos <= 9) return 540;
    if (totalPhotos <= 18) return 400;
    if (totalPhotos <= 32) return 300;
    return 220;
  }

  void _initLayoutWeightsIfNeeded(GridTemplateSpec template) {
    bool needsInit = false;
    if (_layoutGroupWeights.length != template.groups.length) {
      needsInit = true;
    } else if (_layoutItemWeights.length != template.groups.length) {
      needsInit = true;
    } else {
      for (int g = 0; g < template.groups.length; g++) {
        if (_layoutItemWeights[g].length != template.groups[g].length) {
          needsInit = true;
          break;
        }
      }
    }

    if (needsInit) {
      _layoutGroupWeights = template.defaultGroupWeights != null
          ? List<double>.from(template.defaultGroupWeights!)
          : List<double>.filled(template.groups.length, 1.0);
      _layoutItemWeights = [];
      for (int g = 0; g < template.groups.length; g++) {
        if (template.defaultItemWeights != null &&
            g < template.defaultItemWeights!.length &&
            template.defaultItemWeights![g].length == template.groups[g].length) {
          _layoutItemWeights
              .add(List<double>.from(template.defaultItemWeights![g]));
        } else {
          _layoutItemWeights
              .add(List<double>.filled(template.groups[g].length, 1.0));
        }
      }
    }
  }

  void _resetActiveTemplateWeights() {
    final activeTemplate = _getActiveTemplate();
    if (activeTemplate == null) return;
    setState(() {
      _layoutGroupWeights = activeTemplate.defaultGroupWeights != null
          ? List<double>.from(activeTemplate.defaultGroupWeights!)
          : List<double>.filled(activeTemplate.groups.length, 1.0);
      _layoutItemWeights = [];
      for (int g = 0; g < activeTemplate.groups.length; g++) {
        if (activeTemplate.defaultItemWeights != null &&
            g < activeTemplate.defaultItemWeights!.length) {
          _layoutItemWeights
              .add(List<double>.from(activeTemplate.defaultItemWeights![g]));
        } else {
          _layoutItemWeights
              .add(List<double>.filled(activeTemplate.groups[g].length, 1.0));
        }
      }
      if (_selectedPhotoIndex != null && _selectedPhotoIndex! < _photos.length) {
        _photos[_selectedPhotoIndex!].setZoom(1.0);
        _photos[_selectedPhotoIndex!].panOffset = Offset.zero;
      }
    });
  }

  void _adjustWeights(List<double> weights, int i1, int i2, double delta) {
    if (i1 < 0 || i1 >= weights.length || i2 < 0 || i2 >= weights.length) return;
    double w1 = weights[i1];
    double w2 = weights[i2];
    double d = delta;
    if (w1 + d < 0.2) d = 0.2 - w1;
    if (w2 - d < 0.2) d = w2 - 0.2;
    weights[i1] += d;
    weights[i2] -= d;
  }

  void _nudgeActivePhotoBorder(double dx, double dy) {
    if (_selectedPhotoIndex == null) return;
    final activeTemplate = _getActiveTemplate();
    if (activeTemplate == null) return;
    _initLayoutWeightsIfNeeded(activeTemplate);

    int targetG = -1;
    int targetP = -1;
    for (int g = 0; g < activeTemplate.groups.length; g++) {
      final p = activeTemplate.groups[g].indexOf(_selectedPhotoIndex!);
      if (p != -1) {
        targetG = g;
        targetP = p;
        break;
      }
    }
    if (targetG == -1) return;

    setState(() {
      const step = 0.08;
      if (activeTemplate.isRowFirst) {
        if (dx != 0) {
          if (dx > 0 && targetP < activeTemplate.groups[targetG].length - 1) {
            _adjustWeights(_layoutItemWeights[targetG], targetP, targetP + 1, step);
          } else if (dx < 0 && targetP > 0) {
            _adjustWeights(_layoutItemWeights[targetG], targetP - 1, targetP, -step);
          } else if (dx > 0 && targetP > 0) {
            _adjustWeights(_layoutItemWeights[targetG], targetP - 1, targetP, step);
          } else if (dx < 0 && targetP < activeTemplate.groups[targetG].length - 1) {
            _adjustWeights(_layoutItemWeights[targetG], targetP, targetP + 1, -step);
          }
        }
        if (dy != 0) {
          if (dy > 0 && targetG < activeTemplate.groups.length - 1) {
            _adjustWeights(_layoutGroupWeights, targetG, targetG + 1, step);
          } else if (dy < 0 && targetG > 0) {
            _adjustWeights(_layoutGroupWeights, targetG - 1, targetG, -step);
          } else if (dy > 0 && targetG > 0) {
            _adjustWeights(_layoutGroupWeights, targetG - 1, targetG, step);
          } else if (dy < 0 && targetG < activeTemplate.groups.length - 1) {
            _adjustWeights(_layoutGroupWeights, targetG, targetG + 1, -step);
          }
        }
      } else {
        if (dx != 0) {
          if (dx > 0 && targetG < activeTemplate.groups.length - 1) {
            _adjustWeights(_layoutGroupWeights, targetG, targetG + 1, step);
          } else if (dx < 0 && targetG > 0) {
            _adjustWeights(_layoutGroupWeights, targetG - 1, targetG, -step);
          }
        }
        if (dy != 0) {
          if (dy > 0 && targetP < activeTemplate.groups[targetG].length - 1) {
            _adjustWeights(_layoutItemWeights[targetG], targetP, targetP + 1, step);
          } else if (dy < 0 && targetP > 0) {
            _adjustWeights(_layoutItemWeights[targetG], targetP - 1, targetP, -step);
          }
        }
      }
    });
  }

  // 3 Slider Margin Persis Video (00:27 - 00:30):
  double _outerMargin = 0.0; // Slider 1: Jarak Bingkai Luar (0..45)
  double _innerSpacing = 4.0; // Slider 2: Jarak Antar Kotak Foto (0..25)
  double _cornerRadius = 0.0; // Slider 3: Lengkungan Sudut Tiap Kotak (0..28)

  // Pengaturan Tepi / Bingkai Tiap Kotak Foto Persis Video (00:32 - 00:37 & 01:12):
  double _borderWidth = 0.0; // Ketebalan garis tepi (0..15)
  Color _borderColor = Colors.white;

  // Warna Latar Belakang Kanvas (00:57 - 01:10: Putih, Png transparan, Warna)
  Color _backgroundColor = Colors.white;
  bool _isTransparentPngBg = false;

  // Teks Overlay (Fitur "Teks Aa" di Video 2: 01:14 - 02:04)
  final List<CollageTextOverlay> _textOverlays = [];
  int? _selectedTextIndex;
  int _textEditorSubTab = 0; // 0: Papan Ketik, 1: Font, 2: Gaya, 3: Koleksi (100% Gratis)

  // Filter Warna Kolase (Fitur "Filter" di Video 2: 02:06 - 02:17)
  int _selectedFilterIndex = 0;
  double _filterIntensity = 1.0;

  // Stiker Overlay (Fitur "Stiker" di Video 2: 02:20 - 02:22)
  final List<CollageStickerOverlay> _stickerOverlays = [];

  // Foto dalam Foto / PIP Overlay (Fitur "Tambahkan -> Foto dalam Foto" di Video 2: 02:24)
  final List<CollagePipOverlay> _pipOverlays = [];

  // Gambar / Coretan Kuas Bebas (Fitur "Gambar" di Video 2: 02:25 - 02:38)
  final List<FreehandStroke> _drawStrokes = [];
  final List<FreehandStroke> _redoStrokes = [];
  FreehandStroke? _activeStroke;
  Color _brushColor = Colors.white;
  double _brushSize = 7.0;
  final double _brushOpacity = 1.0;
  bool _brushIsNeon = false;
  bool _brushIsEraser = false;

  // Bottom Sheet Editor State
  EditorBottomTab? _activeSheetTab = EditorBottomTab.tataLetak;
  bool _isSaving = false;

  static const List<Color> _paletteColors = [
    Colors.white,
    Color(0xFF111315),
    Color(0xFF334155),
    Color(0xFF94A3B8),
    Color(0xFF10B981),
    Color(0xFF005141),
    Color(0xFF7DF8D6),
    Color(0xFF38BDF8),
    Color(0xFFFACC15),
    Color(0xFFF43F5E),
    Color(0xFFA855F7),
    Color(0xFFFEF3C7),
    Color(0xFFFDA4AF),
  ];

  static const List<CollageFontOption> _fontOptions = [
    CollageFontOption(
      id: 'sans_bold',
      label: 'Tegas Bold',
      fontFamily: 'sans-serif',
      fontWeight: FontWeight.w900,
    ),
    CollageFontOption(
      id: 'sans_normal',
      label: 'Modern Clean',
      fontFamily: 'sans-serif',
      fontWeight: FontWeight.w400,
    ),
    CollageFontOption(
      id: 'condensed',
      label: 'Kompak Bebas',
      fontFamily: 'sans-serif-condensed',
      fontWeight: FontWeight.w900,
      letterSpacing: 0.8,
    ),
    CollageFontOption(
      id: 'serif_bold',
      label: 'Klasik Serif',
      fontFamily: 'serif',
      fontWeight: FontWeight.w700,
    ),
    CollageFontOption(
      id: 'serif_italic',
      label: 'Elegan Italic',
      fontFamily: 'serif',
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
    ),
    CollageFontOption(
      id: 'monospace',
      label: 'Mesin Tik',
      fontFamily: 'monospace',
      fontWeight: FontWeight.w700,
    ),
    CollageFontOption(
      id: 'cursive',
      label: 'Tulisan Tangan',
      fontFamily: 'cursive',
      fontWeight: FontWeight.w600,
    ),
    CollageFontOption(
      id: 'casual',
      label: 'Santai Casual',
      fontFamily: 'casual',
      fontWeight: FontWeight.w700,
    ),
    CollageFontOption(
      id: 'sans_light',
      label: 'Minimalis Thin',
      fontFamily: 'sans-serif-light',
      fontWeight: FontWeight.w300,
      letterSpacing: 1.5,
    ),
    CollageFontOption(
      id: 'sans_black',
      label: 'Hitam Pekat',
      fontFamily: 'sans-serif-black',
      fontWeight: FontWeight.w900,
    ),
  ];

  static TextStyle _getTextStyleForOverlay(
    CollageTextOverlay t, {
    Color? color,
    Paint? foreground,
  }) {
    final opt = _fontOptions.firstWhere(
      (o) => o.id == t.fontFamily || o.label == t.fontFamily,
      orElse: () => _fontOptions.first,
    );
    final base = TextStyle(
      fontSize: t.fontSize,
      color: color,
      foreground: foreground,
    );
    return opt.applyTo(base);
  }

  static const List<String> _freeStickers = [
    '✨',
    '🔥',
    '❤️',
    '📌',
    '📸',
    '🌟',
    '🎉',
    '✅',
    '🏆',
    '💯',
    '📍',
    '🎨',
  ];

  @override
  void dispose() {
    _saveGridSettings();
    _textInputController.dispose();
    for (final entry in _photos) {
      entry.dispose();
    }
    super.dispose();
  }

  void _showMaxPhotosExceededDialog({
    required int currentCount,
    required int selectedCount,
    required bool alreadyFull,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Maksimal 50 Foto',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          alreadyFull
              ? 'Batas maksimal $maxPhotos foto telah tercapai. Anda tidak dapat menambahkan foto lagi kecuali menghapus beberapa foto yang ada.'
              : 'Anda memilih $selectedCount foto, sedangkan batas maksimal kolase adalah $maxPhotos foto.\n\nHanya $maxPhotos foto pertama yang dimasukkan ke kolase, sisa fotonya otomatis diabaikan.',
          style: const TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhotoFromCamera() async {
    if (_photos.length >= maxPhotos) {
      _showMaxPhotosExceededDialog(
        currentCount: _photos.length,
        selectedCount: 1,
        alreadyFull: true,
      );
      return;
    }
    try {
      final XFile? captured = await _picker.pickImage(
        source: ImageSource.camera,
      );
      if (captured == null || !mounted) return;
      setState(() {
        _photos.add(GridPhotoEntry(file: captured));
        _selectedTemplateIndex = 0;
        _layoutGroupWeights = [];
        _layoutItemWeights = [];
        _isPhotoPickerStage = false;
        _activeSheetTab = EditorBottomTab.tataLetak;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka kamera: $e')),
      );
    }
  }

  Future<void> _pickImagesFromDevice() async {
    if (_photos.length >= maxPhotos) {
      _showMaxPhotosExceededDialog(
        currentCount: _photos.length,
        selectedCount: 0,
        alreadyFull: true,
      );
      return;
    }

    try {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;

      final remainingSlots = maxPhotos - _photos.length;
      final bool exceeded = picked.length > remainingSlots;

      setState(() {
        final toAdd = picked.take(remainingSlots).map(
              (xfile) => GridPhotoEntry(file: xfile),
            );
        _photos.addAll(toAdd);
        _selectedTemplateIndex = 0;
        _layoutGroupWeights = [];
        _layoutItemWeights = [];
        if (_photos.isNotEmpty) {
          _isPhotoPickerStage = false;
          _activeSheetTab = EditorBottomTab.tataLetak;
        }
      });

      if (exceeded && mounted) {
        _showMaxPhotosExceededDialog(
          currentCount: _photos.length,
          selectedCount: picked.length,
          alreadyFull: false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Maksimal $maxPhotos foto! Hanya $maxPhotos foto pertama yang dimasukkan.'),
                ),
              ],
            ),
            backgroundColor: Colors.amber.shade900,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e')),
      );
    }
  }

  /// Fitur "Ganti" di Bar Biru Kontekstual (Video 2: 00:13)
  Future<void> _replacePhotoAt(int index) async {
    if (index < 0 || index >= _photos.length) return;
    if (_photos[index].isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto ini sedang dikunci. Buka kunci terlebih dahulu.')),
      );
      return;
    }
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
              );
      if (picked == null) return;
      setState(() {
        _photos[index].file = picked;
        _photos[index].resetTransform();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengganti foto: $e')),
      );
    }
  }

  /// Fitur "Tambahkan -> Foto dalam Foto (PIP)" (Video 2: 02:24)
  Future<void> _addPipOverlayPhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
              );
      if (picked == null) return;
      setState(() {
        _pipOverlays.add(CollagePipOverlay(file: picked));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambah Foto dalam Foto: $e')),
      );
    }
  }

  void _removePhotoAt(int index) {
    if (index < 0 || index >= _photos.length) return;
    if (_photos[index].isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto dikunci! Ketuk Kunci untuk membuka.')),
      );
      return;
    }
    setState(() {
      _photos[index].dispose();
      _photos.removeAt(index);
      _selectedTemplateIndex = 0;
      _layoutGroupWeights = [];
      _layoutItemWeights = [];
      _layoutGroupWeights = [];
      _layoutItemWeights = [];
      _isSwapModeActive = false;
      if (_photos.isEmpty) {
        _selectedPhotoIndex = null;
        _showContextualPhotoBar = false;
        _isPhotoPickerStage = true;
      } else if (_selectedPhotoIndex != null) {
        if (_selectedPhotoIndex == index) {
          _selectedPhotoIndex = null;
          _showContextualPhotoBar = false;
        } else if (_selectedPhotoIndex! > index) {
          _selectedPhotoIndex = _selectedPhotoIndex! - 1;
        }
      }
    });
  }

  void _clearAllPhotos() {
    setState(() {
      for (final entry in _photos) {
        entry.dispose();
      }
      _photos.clear();
      _selectedPhotoIndex = null;
      _showContextualPhotoBar = false;
      _isSwapModeActive = false;
      _selectedTemplateIndex = 0;
      _layoutGroupWeights = [];
      _layoutItemWeights = [];
    });
  }

  void _swapPhotoOrder(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _photos.length || fromIndex == toIndex) return;
    setState(() {
      final temp = _photos[fromIndex];
      _photos[fromIndex] = _photos[toIndex];
      _photos[toIndex] = temp;
      _selectedPhotoIndex = toIndex;
      _isSwapModeActive = false;
    });
  }

  void _openTextEditDialog(CollageTextOverlay textOverlay) {
    final controller = TextEditingController(text: textOverlay.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 26),
            SizedBox(width: 8),
            Text(
              'Edit Teks Kolase',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ketik teks di sini...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 3,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                final trimmed = controller.text.trim();
                textOverlay.text = trimmed.isEmpty ? 'Teks' : trimmed;
                _textInputController.text = textOverlay.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _addOrSelectTextOverlay() {
    if (_textOverlays.isEmpty) {
      final newText = CollageTextOverlay(text: 'Teks Kolase');
      _textOverlays.add(newText);
      _selectedTextIndex = 0;
      _textInputController.text = newText.text;
      _openTextEditDialog(newText);
    } else {
      _selectedTextIndex ??= _textOverlays.length - 1;
      _textInputController.text = _textOverlays[_selectedTextIndex!].text;
    }
  }

  Future<void> _exportGridToGallery() async {
    if (_photos.isEmpty || _isSaving) return;

    final previousSelected = _selectedPhotoIndex;
    final previousSelectedText = _selectedTextIndex;
    final previousContextual = _showContextualPhotoBar;
    setState(() {
      _selectedPhotoIndex = null;
      _selectedTextIndex = null;
      _showContextualPhotoBar = false;
      _isSwapModeActive = false;
      _isSaving = true;
    });

    try {
      // Pastikan frame yang menghilangkan seleksi/garis biru selesai digambar
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 100));
      final savedPath = await ImageExportService.captureAndSaveToGallery(
        boundaryKey: _gridBoundaryKey,
        filePrefix: 'GridMark',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kolase berhasil disimpan ke Galeri!\n($savedPath)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan kolase: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _selectedPhotoIndex = previousSelected;
          _selectedTextIndex = previousSelectedText;
          _showContextualPhotoBar = previousContextual;
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPhotoPickerStage) {
      return _buildPhotoPickerStage(context);
    }
    return _buildCollageEditorStage(context);
  }

  // ===========================================================================
  // TAHAP 1: LAYAR "PILIH FOTO" (LANGSUNG DARI PENYIMPANAN / GALERI HP & KAMERA)
  // ===========================================================================
  Widget _buildPhotoPickerStage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = _photos.length;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          count > 0 ? 'Pilih Foto ($count/$maxPhotos)' : 'Pilih Foto Kolase (Maks $maxPhotos)',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedTemplateIndex = 0;
                    _layoutGroupWeights = [];
                    _layoutItemWeights = [];
                    _isPhotoPickerStage = false;
                    _activeSheetTab = EditorBottomTab.tataLetak;
                  });
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text('Lanjut ($count)'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (count >= maxPhotos)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Batas maksimal $maxPhotos foto telah tercapai.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // KARTU AKSI UTAMA: 2 Tombol Besar (Galeri HP & Kamera Langsung)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickImagesFromDevice,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFF1D4ED8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_rounded, color: Colors.white, size: 26),
                          SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Galeri HP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Pilih banyak foto',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _capturePhotoFromCamera,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant, width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_rounded, color: scheme.primary, size: 26),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Kamera',
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Ambil foto baru',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 16),

          // AREA KONTEN FOTO: KOSONG ATAU DAFTAR FOTO ASLI YANG DIPILIH
          Expanded(
            child: count == 0
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.collections_outlined,
                              size: 56,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Belum Ada Foto Dipilih',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ketuk tombol "Galeri HP" untuk memilih 1 hingga 50 foto langsung dari penyimpanan HP Anda, atau ambil foto menggunakan Kamera.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _pickImagesFromDevice,
                            icon: const Icon(Icons.add_photo_alternate_rounded),
                            label: const Text('Buka Penyimpanan Galeri'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: count + 1, // +1 untuk tombol "+ Tambah"
                    itemBuilder: (context, index) {
                      if (index == count) {
                        return InkWell(
                          onTap: _pickImagesFromDevice,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.outlineVariant,
                                style: BorderStyle.solid,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: scheme.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tambah Foto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final entry = _photos[index];
                      return GestureDetector(
                        onTap: () => _showFullscreenPhotoPreview(
                          context,
                          entry.file,
                          photoNumber: index + 1,
                        ),
                        onLongPress: () => _showFullscreenPhotoPreview(
                          context,
                          entry.file,
                          photoNumber: index + 1,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(entry.file.path),
                                fit: BoxFit.cover,
                                cacheWidth: 320,
                                filterQuality: FilterQuality.low,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF2563EB),
                                  width: 2.0,
                                ),
                              ),
                            ),
                            // Badge nomor urut foto
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // Tombol Hapus (✕)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => _removePhotoAt(index),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // TRAY BAWAH: Status Pilihan & Tombol Lanjut ke Editor
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border(
                top: BorderSide(color: scheme.outlineVariant, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count == 0 ? 'Pilih foto untuk memulai' : '$count foto terpilih',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          'Maksimal 50 foto kolase',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (count > 0) ...[
                    IconButton(
                      tooltip: 'Kosongkan Semua Pilihan',
                      visualDensity: VisualDensity.compact,
                      onPressed: _clearAllPhotos,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    onPressed: count == 0
                        ? null
                        : () {
                            setState(() {
                              _isPhotoPickerStage = false;
                              _activeSheetTab = EditorBottomTab.tataLetak;
                            });
                          },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Buat Kolase'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Menampilkan dialog preview foto resolusi penuh saat foto di-HOLD (tekan & tahan)
  void _showFullscreenPhotoPreview(
    BuildContext context,
    XFile file, {
    int? photoNumber,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gambar dengan Pinch Zoom & Pan Interaktif
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.5,
                  child: Image.file(
                    File(file.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Header Atas
              Positioned(
                top: 36,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    Text(
                      photoNumber != null
                          ? 'Foto $photoNumber'
                          : 'Preview Foto',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Petunjuk Bawah
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'Cubit / Geser untuk Zoom Foto',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAHAP 2: LAYAR EDITOR KOLASE (VIDEO 1 + VIDEO 2 + FITUR BANG PAANG)
  // ===========================================================================
  Widget _buildCollageEditorStage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final int count = _photos.length;
    final templates = GridTemplateCatalog.forPhotoCount(count);
    final activeTemplate = templates.isNotEmpty
        ? templates[_selectedTemplateIndex.clamp(0, templates.length - 1)]
        : null;
    final activeRatio = kAspectRatios[_selectedRatioIndex].ratio;
    final activeFilter = kColorFilters[_selectedFilterIndex];

    return Scaffold(
      backgroundColor: scheme.surface,
      // TOP BAR EDITOR: Back (Kembali ke Pilih Foto), Undo/Redo, SIMPAN
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Ubah Pilihan Foto',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            setState(() => _isPhotoPickerStage = true);
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Undo Coretan / Reset Pengaturan',
              icon: const Icon(Icons.undo_rounded, size: 20),
              onPressed: () {
                setState(() {
                  if (_drawStrokes.isNotEmpty) {
                    _redoStrokes.add(_drawStrokes.removeLast());
                  } else {
                    _outerMargin = 0;
                    _innerSpacing = 4;
                    _cornerRadius = 0;
                    _borderWidth = 0;
                  }
                });
              },
            ),
            if (_redoStrokes.isNotEmpty)
              IconButton(
                tooltip: 'Redo Coretan',
                icon: const Icon(Icons.redo_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    _drawStrokes.add(_redoStrokes.removeLast());
                  });
                },
              ),
            Text(
              '$count Foto',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _isSaving ? null : _exportGridToGallery,
            child: Text(
              _isSaving ? 'MENYIMPAN...' : 'SIMPAN',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // AREA KANVAS TENGAH DENGAN RASIO PILIHAN + OVERLAY TEKS/STIKER/PIP/GAMBAR KUAS
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_selectedPhotoIndex != null) {
                  setState(() {
                    _selectedPhotoIndex = null;
                    _showContextualPhotoBar = false;
                    _activeGesturePhotoIndex = null;
                  });
                }
              },
              child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: AspectRatio(
                      aspectRatio: activeRatio,
                      child: RepaintBoundary(
                        key: _gridBoundaryKey,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.all(_outerMargin),
                          decoration: BoxDecoration(
                            color: _isTransparentPngBg
                                ? Colors.transparent
                                : _backgroundColor,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Lapisan Checkerboard saat pilih Background PNG Transparan (Video 2: 00:57)
                              if (_isTransparentPngBg && !_isSaving)
                                CustomPaint(
                                  painter: _CheckerboardPainter(),
                                ),

                              // 1. Lapisan Kisi Foto dengan Filter Warna
                              if (activeTemplate != null)
                                ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                    _interpolateFilterMatrix(
                                      activeFilter.matrix,
                                      _filterIntensity,
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      _initLayoutWeightsIfNeeded(activeTemplate);
                                      return _buildPartitionCollage(
                                        activeTemplate: activeTemplate,
                                        constraints: constraints,
                                        scheme: scheme,
                                      );
                                    },
                                  ),
                                ),

                              // 2. Lapisan Foto dalam Foto / PIP (Video 2: 02:24)
                              ...List.generate(_pipOverlays.length, (i) {
                                final pip = _pipOverlays[i];
                                return Positioned(
                                  left: pip.position.dx,
                                  top: pip.position.dy,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        pip.position += details.delta;
                                      });
                                    },
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: pip.size,
                                          height: pip.size,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.5,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black38,
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.file(
                                              File(pip.file.path),
                                              fit: BoxFit.cover,
                                              cacheWidth: 800,
                                              filterQuality: FilterQuality.medium,
                                            ),
                                          ),
                                        ),
                                        if (!_isSaving)
                                          Positioned(
                                            top: -8,
                                            right: -8,
                                            child: GestureDetector(
                                              onTap: () => setState(() =>
                                                  _pipOverlays.removeAt(i)),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                              // 3. Lapisan Stiker Overlay (Video 2: 02:20)
                              ...List.generate(_stickerOverlays.length, (i) {
                                final st = _stickerOverlays[i];
                                return Positioned(
                                  left: st.position.dx,
                                  top: st.position.dy,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        st.position += details.delta;
                                      });
                                    },
                                    onDoubleTap: () {
                                      setState(
                                          () => _stickerOverlays.removeAt(i));
                                    },
                                    child: Text(
                                      st.label,
                                      style:
                                          TextStyle(fontSize: 34 * st.scale),
                                    ),
                                  ),
                                );
                              }),

                              // 4. Lapisan Teks Overlay (Video 2: 01:14 - 02:04 "Tugas 1 pameran")
                              ...List.generate(_textOverlays.length, (i) {
                                final t = _textOverlays[i];
                                final isTextSelected =
                                    !_isSaving && _selectedTextIndex == i;
                                return Positioned(
                                  left: t.position.dx,
                                  top: t.position.dy,
                                  child: GestureDetector(
                                    onDoubleTap: () => _openTextEditDialog(t),
                                    onTap: () {
                                      setState(() {
                                        _selectedTextIndex = i;
                                        _textInputController.text = t.text;
                                        _activeSheetTab = EditorBottomTab.teks;
                                        _showContextualPhotoBar = false;
                                      });
                                    },
                                    onPanUpdate: (details) {
                                      setState(() {
                                        t.position += details.delta;
                                      });
                                    },
                                    child: Opacity(
                                      opacity: t.opacity.clamp(0.1, 1.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: t.backgroundColor,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: isTextSelected
                                              ? Border.all(
                                                  color: Colors.white,
                                                  width: 1.5,
                                                )
                                              : null,
                                          boxShadow: t.isNeon &&
                                                  t.strokeColor != null
                                              ? [
                                                  BoxShadow(
                                                    color: t.strokeColor!,
                                                    blurRadius: 12,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            if (t.strokeColor != null)
                                              Text(
                                                t.text,
                                                style: _getTextStyleForOverlay(
                                                  t,
                                                  foreground: Paint()
                                                    ..style =
                                                        PaintingStyle.stroke
                                                    ..strokeWidth = 3
                                                    ..color = t.strokeColor!,
                                                ),
                                              ),
                                            Text(
                                              t.text,
                                              style: _getTextStyleForOverlay(
                                                t,
                                                color: t.textColor,
                                              ).copyWith(
                                                shadows: t.hasShadow
                                                    ? [
                                                        Shadow(
                                                          color: t.isNeon &&
                                                                  t.strokeColor !=
                                                                      null
                                                              ? t.strokeColor!
                                                              : Colors.black54,
                                                          blurRadius: t.isNeon
                                                              ? 14
                                                              : 4,
                                                          offset: const Offset(
                                                              1, 1),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              // 5. Lapisan Gambar Coretan Kuas Bebas (Video 2: 02:25 - 02:38)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring:
                                      _activeSheetTab != EditorBottomTab.gambar,
                                  child: GestureDetector(
                                    onPanStart: (details) {
                                      setState(() {
                                        _redoStrokes.clear();
                                        _activeStroke = FreehandStroke(
                                          points: [details.localPosition],
                                          color: _brushColor,
                                          strokeWidth: _brushSize,
                                          opacity: _brushOpacity,
                                          isNeon: _brushIsNeon,
                                          isEraser: _brushIsEraser,
                                        );
                                        _drawStrokes.add(_activeStroke!);
                                      });
                                    },
                                    onPanUpdate: (details) {
                                      if (_activeStroke == null) return;
                                      setState(() {
                                        _activeStroke!.points
                                            .add(details.localPosition);
                                      });
                                    },
                                    onPanEnd: (_) {
                                      _activeStroke = null;
                                    },
                                    child: CustomPaint(
                                      painter: _FreehandCanvasPainter(
                                        strokes: _drawStrokes,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // TOAST MELAYANG "Pilih foto untuk ditukar" (Persis Video 2: 00:05 - 00:10 & 00:35)
                if (_isSwapModeActive && !_isSaving)
                  Positioned(
                    bottom: 16,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(24),
                      color: const Color(0xFF2563EB),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Pilih foto untuk ditukar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _isSwapModeActive = false),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

          // BAR AKSI BIRU KONTEKSTUAL SAAT FOTO DIKETUK (Persis Video 2: 00:13 - 00:34)
          if (_showContextualPhotoBar &&
              _selectedPhotoIndex != null &&
              _selectedPhotoIndex! < _photos.length)
            _buildContextualBluePhotoBar(),

          // PANEL BAWAH: BISA MODE SHEET TERBUKA ATAU BAR IKON UTAMA SCROLLABLE
          if (_activeSheetTab != null)
            _buildEditorBottomSheet(scheme, templates, count)
          else
            _buildCollapsedBottomToolbar(scheme),
        ],
      ),
    );
  }

  List<double> _interpolateFilterMatrix(
    List<double> target,
    double intensity,
  ) {
    const identity = <double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
    final t = intensity.clamp(0.0, 1.0);
    return List<double>.generate(20, (i) {
      return identity[i] + (target[i] - identity[i]) * t;
    });
  }

  Widget _buildPartitionCollage({
    required GridTemplateSpec activeTemplate,
    required BoxConstraints constraints,
    required ColorScheme scheme,
  }) {
    if (activeTemplate.isRowFirst) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int g = 0; g < activeTemplate.groups.length; g++) ...[
            if (g > 0 && _innerSpacing > 0) SizedBox(height: _innerSpacing),
            Expanded(
              flex: ((_layoutGroupWeights.length > g
                          ? _layoutGroupWeights[g]
                          : 1.0) *
                      1000)
                  .round()
                  .clamp(100, 100000),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int p = 0;
                      p < activeTemplate.groups[g].length;
                      p++) ...[
                    if (p > 0 && _innerSpacing > 0)
                      SizedBox(width: _innerSpacing),
                    Expanded(
                      flex: ((_layoutItemWeights.length > g &&
                                  _layoutItemWeights[g].length > p
                              ? _layoutItemWeights[g][p]
                              : 1.0) *
                              1000)
                          .round()
                          .clamp(100, 100000),
                      child: _buildPartitionTile(
                        photoIndex: activeTemplate.groups[g][p],
                        groupIndex: g,
                        itemIndex: p,
                        totalGroups: activeTemplate.groups.length,
                        totalItemsInGroup: activeTemplate.groups[g].length,
                        isRowFirst: true,
                        constraints: constraints,
                        scheme: scheme,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int g = 0; g < activeTemplate.groups.length; g++) ...[
            if (g > 0 && _innerSpacing > 0) SizedBox(width: _innerSpacing),
            Expanded(
              flex: ((_layoutGroupWeights.length > g
                          ? _layoutGroupWeights[g]
                          : 1.0) *
                      1000)
                  .round()
                  .clamp(100, 100000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int p = 0;
                      p < activeTemplate.groups[g].length;
                      p++) ...[
                    if (p > 0 && _innerSpacing > 0)
                      SizedBox(height: _innerSpacing),
                    Expanded(
                      flex: ((_layoutItemWeights.length > g &&
                                  _layoutItemWeights[g].length > p
                              ? _layoutItemWeights[g][p]
                              : 1.0) *
                              1000)
                          .round()
                          .clamp(100, 100000),
                      child: _buildPartitionTile(
                        photoIndex: activeTemplate.groups[g][p],
                        groupIndex: g,
                        itemIndex: p,
                        totalGroups: activeTemplate.groups.length,
                        totalItemsInGroup: activeTemplate.groups[g].length,
                        isRowFirst: false,
                        constraints: constraints,
                        scheme: scheme,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildPartitionTile({
    required int photoIndex,
    required int groupIndex,
    required int itemIndex,
    required int totalGroups,
    required int totalItemsInGroup,
    required bool isRowFirst,
    required BoxConstraints constraints,
    required ColorScheme scheme,
  }) {
    if (photoIndex >= _photos.length) return const SizedBox.shrink();
    final entry = _photos[photoIndex];
    final bool isSelected = !_isSaving && _selectedPhotoIndex == photoIndex;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
          details.data != photoIndex && !entry.isLocked,
      onAcceptWithDetails: (details) {
        _swapPhotoOrder(details.data, photoIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isDropTarget = candidateData.isNotEmpty;

        return LongPressDraggable<int>(
          data: photoIndex,
          maxSimultaneousDrags: entry.isLocked ? 0 : 1,
          delay: const Duration(milliseconds: 220),
          feedback: Material(
            color: Colors.transparent,
            elevation: 14,
            borderRadius: BorderRadius.circular(12),
            child: Opacity(
              opacity: 0.75,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2563EB),
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9.5),
                  child: Image.file(
                    File(entry.file.path),
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade400,
                      child: const Icon(Icons.image, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(_cornerRadius),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.5),
                  width: 2.0,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.black45,
                  size: 32,
                ),
              ),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: _buildPartitionTileContent(
                  entry: entry,
                  index: photoIndex,
                  isSelected: isSelected,
                  isDropTarget: isDropTarget,
                ),
              ),

              // Highlight Seleksi Biru
              if (isSelected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_cornerRadius),
                        border: Border.all(
                          color: const Color(0xFF2563EB),
                          width: 3.0,
                        ),
                      ),
                    ),
                  ),
                ),

              // Handle Geser Ukuran Kotak / Pill Handle (Persis Video WhatsApp Latif: 00:07 - 00:45)
              if (isSelected && !entry.isLocked && !_isSaving) ...[
                if (isRowFirst) ...[
                  // Bottom Handle (geser baris bawah)
                  if (groupIndex < totalGroups - 1)
                    Positioned(
                      bottom: -16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            final totalH = constraints.maxHeight;
                            if (totalH <= 0) return;
                            final sumW =
                                _layoutGroupWeights.fold(0.0, (a, b) => a + b);
                            final dWeight =
                                (details.delta.dy / totalH) * sumW;
                            setState(() {
                              _adjustWeights(_layoutGroupWeights, groupIndex,
                                  groupIndex + 1, dWeight);
                            });
                          },
                          child: _buildHandlePill(isVertical: false),
                        ),
                      ),
                    ),
                  // Top Handle (geser baris atas)
                  if (groupIndex > 0)
                    Positioned(
                      top: -16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            final totalH = constraints.maxHeight;
                            if (totalH <= 0) return;
                            final sumW =
                                _layoutGroupWeights.fold(0.0, (a, b) => a + b);
                            final dWeight =
                                (details.delta.dy / totalH) * sumW;
                            setState(() {
                              _adjustWeights(_layoutGroupWeights,
                                  groupIndex - 1, groupIndex, dWeight);
                            });
                          },
                          child: _buildHandlePill(isVertical: false),
                        ),
                      ),
                    ),
                  // Right Handle (geser kolom kanan)
                  if (itemIndex < totalItemsInGroup - 1)
                    Positioned(
                      right: -16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) {
                            final totalW = constraints.maxWidth;
                            if (totalW <= 0) return;
                            final sumW = _layoutItemWeights[groupIndex]
                                .fold(0.0, (a, b) => a + b);
                            final dWeight =
                                (details.delta.dx / totalW) * sumW;
                            setState(() {
                              _adjustWeights(_layoutItemWeights[groupIndex],
                                  itemIndex, itemIndex + 1, dWeight);
                            });
                          },
                          child: _buildHandlePill(isVertical: true),
                        ),
                      ),
                    ),
                  // Left Handle (geser kolom kiri)
                  if (itemIndex > 0)
                    Positioned(
                      left: -16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) {
                            final totalW = constraints.maxWidth;
                            if (totalW <= 0) return;
                            final sumW = _layoutItemWeights[groupIndex]
                                .fold(0.0, (a, b) => a + b);
                            final dWeight =
                                (details.delta.dx / totalW) * sumW;
                            setState(() {
                              _adjustWeights(_layoutItemWeights[groupIndex],
                                  itemIndex - 1, itemIndex, dWeight);
                            });
                          },
                          child: _buildHandlePill(isVertical: true),
                        ),
                      ),
                    ),
                ] else ...[
                  // Column-First mode
                  if (groupIndex < totalGroups - 1)
                    Positioned(
                      right: -16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) {
                            final totalW = constraints.maxWidth;
                            if (totalW <= 0) return;
                            final sumW =
                                _layoutGroupWeights.fold(0.0, (a, b) => a + b);
                            final dWeight =
                                (details.delta.dx / totalW) * sumW;
                            setState(() {
                              _adjustWeights(_layoutGroupWeights, groupIndex,
                                  groupIndex + 1, dWeight);
                            });
                          },
                          child: _buildHandlePill(isVertical: true),
                        ),
                      ),
                    ),
                  if (groupIndex > 0)
                    Positioned(
                      left: -16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) {
                            final totalW = constraints.maxWidth;
                            if (totalW <= 0) return;
                            final sumW =
                                _layoutGroupWeights.fold(0.0, (a, b) => a + b);
                            final dWeight =
                                (details.delta.dx / totalW) * sumW;
                            setState(() {
                              _adjustWeights(_layoutGroupWeights,
                                  groupIndex - 1, groupIndex, dWeight);
                            });
                          },
                          child: _buildHandlePill(isVertical: true),
                        ),
                      ),
                    ),
                  if (itemIndex < totalItemsInGroup - 1)
                    Positioned(
                      bottom: -16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            final totalH = constraints.maxHeight;
                            if (totalH <= 0) return;
                            final sumW = _layoutItemWeights[groupIndex]
                                .fold(0.0, (a, b) => a + b);
                            final dWeight =
                                (details.delta.dy / totalH) * sumW;
                            setState(() {
                              _adjustWeights(_layoutItemWeights[groupIndex],
                                  itemIndex, itemIndex + 1, dWeight);
                            });
                          },
                          child: _buildHandlePill(isVertical: false),
                        ),
                      ),
                    ),
                  if (itemIndex > 0)
                    Positioned(
                      top: -16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            final totalH = constraints.maxHeight;
                            if (totalH <= 0) return;
                            final sumW = _layoutItemWeights[groupIndex]
                                .fold(0.0, (a, b) => a + b);
                            final dWeight =
                                (details.delta.dy / totalH) * sumW;
                            setState(() {
                              _adjustWeights(_layoutItemWeights[groupIndex],
                                  itemIndex - 1, itemIndex, dWeight);
                            });
                          },
                          child: _buildHandlePill(isVertical: false),
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartitionTileContent({
    required GridPhotoEntry entry,
    required int index,
    required bool isSelected,
    required bool isDropTarget,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: _borderWidth > 0
            ? Border.all(color: _borderColor, width: _borderWidth)
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(
              (_cornerRadius - _borderWidth).clamp(0.0, 40.0),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_activeGesturePhotoIndex != null && _activeGesturePhotoIndex != index) return;
                setState(() {
                  if (_isSwapModeActive &&
                      _selectedPhotoIndex != null &&
                      _selectedPhotoIndex != index) {
                    _swapPhotoOrder(_selectedPhotoIndex!, index);
                    return;
                  }
                  _selectedPhotoIndex = index;
                  _showContextualPhotoBar = true;
                });
              },
              onDoubleTap: () {
                if (entry.isLocked) return;
                if (_selectedPhotoIndex != null && _selectedPhotoIndex != index) return;
                setState(() {
                  _selectedPhotoIndex = index;
                  _showContextualPhotoBar = true;
                  final bool isModified = entry.scale != 1.0 ||
                      entry.rotation != 0.0 ||
                      entry.panOffset != Offset.zero;
                  if (isModified) {
                    entry.scale = 1.0;
                    entry.rotation = 0.0;
                    entry.panOffset = Offset.zero;
                    entry.fitMode = BoxFit.cover;
                  } else {
                    entry.toggleFitMode();
                  }
                });
              },
              onScaleStart: (details) {
                if (entry.isLocked) return;
                // Auto-lock: Jika ada foto lain yang sedang aktif dipilih atau sedang digestur, foto ini terkunci total!
                if (_selectedPhotoIndex != null && _selectedPhotoIndex != index) return;
                if (_activeGesturePhotoIndex != null && _activeGesturePhotoIndex != index) return;

                setState(() {
                  _activeGesturePhotoIndex = index;
                  _selectedPhotoIndex = index;
                  _showContextualPhotoBar = true;
                });
                entry.startScale = entry.scale;
                entry.startRotation = entry.rotation;
                entry.startPan = entry.panOffset;
                entry.startFocalPoint = details.localFocalPoint;
              },
              onScaleUpdate: (details) {
                if (entry.isLocked) return;
                // Hanya foto yang sedang fokus dipilih & aktif gestur yang boleh digeser / dizoom / dirotate
                if (_selectedPhotoIndex != index || _activeGesturePhotoIndex != index) return;

                setState(() {
                  entry.scale = (entry.startScale * details.scale).clamp(0.15, 6.0);
                  entry.rotation = entry.startRotation + details.rotation;
                  entry.panOffset = entry.startPan + (details.localFocalPoint - entry.startFocalPoint);
                });
              },
              onScaleEnd: (_) {
                if (_activeGesturePhotoIndex == index) {
                  setState(() {
                    _activeGesturePhotoIndex = null;
                  });
                }
              },
              child: SizedBox.expand(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translateByDouble(entry.panOffset.dx, entry.panOffset.dy, 0.0, 1.0)
                    ..scaleByDouble(entry.scale, entry.scale, 1.0, 1.0)
                    ..rotateZ(entry.rotation),
                  child: FittedBox(
                    fit: entry.fitMode,
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    child: Transform.flip(
                      flipX: entry.flipHorizontal,
                      flipY: entry.flipVertical,
                      child: RotatedBox(
                        quarterTurns: entry.quarterTurns,
                        child: Image.file(
                          File(entry.file.path),
                          cacheWidth: _calculateCacheWidth(_photos.length),
                          filterQuality: FilterQuality.medium,
                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame != null) {
                              return child;
                            }
                            return Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Icon(
                                  Icons.photo_outlined,
                                  color: Colors.black26,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.grey.shade400,
                                      size: 26,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Foto ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isDropTarget)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(_cornerRadius),
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: 3.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tukar ke Sini',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          if (entry.isLocked && !_isSaving)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: Colors.amberAccent,
                ),
              ),
            ),
          if (isSelected && !_isSaving)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_cornerRadius),
                    border: Border.all(
                      color: const Color(0xFF2563EB),
                      width: 2.8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHandlePill({required bool isVertical}) {
    return Container(
      width: isVertical ? 34 : 58,
      height: isVertical ? 58 : 34,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Container(
        width: isVertical ? 12 : 36,
        height: isVertical ? 36 : 12,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF2563EB),
            width: 1.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 4,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Center(
          child: isVertical
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// BAR BIRU KONTEKSTUAL SAAT FOTO DIKETUK (Persis Video 2: 00:13 - 00:34:
  /// Kunci, Menukar, Ganti, Hapus, Filter, Putar, Paskan/Isi, Vertikal, Horizontal, Perbesar, Perkecil, Kiri, Kanan, Atas, Bawah)
  Widget _buildContextualBluePhotoBar() {
    final idx = _selectedPhotoIndex!;
    final entry = _photos[idx];

    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFF2563EB), // Biru khas bar aksi foto di Video 2
      ),
      child: Row(
        children: [
          // Tombol Tutup Bar Biru (v)
          InkWell(
            onTap: () => setState(() {
              _showContextualPhotoBar = false;
              _isSwapModeActive = false;
              _selectedPhotoIndex = null;
              _activeGesturePhotoIndex = null;
            }),
            child: Container(
              width: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                _BlueBarToolItem(
                  icon: entry.isLocked
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  label: entry.isLocked ? 'Terkunci' : 'Kunci',
                  isActive: entry.isLocked,
                  onTap: () => setState(() => entry.isLocked = !entry.isLocked),
                ),
                _BlueBarToolItem(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Menukar',
                  isActive: _isSwapModeActive,
                  onTap: () => setState(
                    () => _isSwapModeActive = !_isSwapModeActive,
                  ),
                ),
                _BlueBarToolItem(
                  icon: Icons.find_replace_rounded,
                  label: 'Ganti',
                  onTap: () => _replacePhotoAt(idx),
                ),
                _BlueBarToolItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus',
                  onTap: () => _removePhotoAt(idx),
                ),
                _BlueBarToolItem(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Filter',
                  onTap: () => setState(() {
                    _activeSheetTab = EditorBottomTab.filter;
                  }),
                ),
                _BlueBarToolItem(
                  icon: Icons.rotate_right_rounded,
                  label: 'Putar',
                  onTap: () => setState(() => entry.rotateRight()),
                ),
                _BlueBarToolItem(
                  icon: entry.fitMode == BoxFit.cover
                      ? Icons.fit_screen_rounded
                      : Icons.fullscreen_rounded,
                  label: entry.fitMode == BoxFit.cover ? 'Paskan' : 'Isi',
                  onTap: () => setState(() => entry.toggleFitMode()),
                ),
                _BlueBarToolItem(
                  icon: Icons.swap_vert_rounded,
                  label: 'Vertikal',
                  isActive: entry.flipVertical,
                  onTap: () => setState(() => entry.toggleFlipVertical()),
                ),
                _BlueBarToolItem(
                  icon: Icons.flip_rounded,
                  label: 'Horizontal',
                  isActive: entry.flipHorizontal,
                  onTap: () => setState(() => entry.toggleFlipHorizontal()),
                ),
                _BlueBarToolItem(
                  icon: Icons.zoom_in_rounded,
                  label: 'Zoom +',
                  onTap: () => setState(() => entry.setZoom(entry.scale + 0.25)),
                ),
                _BlueBarToolItem(
                  icon: Icons.zoom_out_rounded,
                  label: 'Zoom -',
                  onTap: () => setState(() => entry.setZoom(entry.scale - 0.25)),
                ),
                _BlueBarToolItem(
                  icon: Icons.restart_alt_rounded,
                  label: 'Perkecil',
                  onTap: _resetActiveTemplateWeights,
                ),
                _BlueBarToolItem(
                  icon: Icons.arrow_back_rounded,
                  label: 'Kiri',
                  onTap: () => _nudgeActivePhotoBorder(-1, 0),
                ),
                _BlueBarToolItem(
                  icon: Icons.arrow_forward_rounded,
                  label: 'Kanan',
                  onTap: () => _nudgeActivePhotoBorder(1, 0),
                ),
                _BlueBarToolItem(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Atas',
                  onTap: () => _nudgeActivePhotoBorder(0, -1),
                ),
                _BlueBarToolItem(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Bawah',
                  onTap: () => _nudgeActivePhotoBorder(0, 1),
                ),
                _BlueBarToolItem(
                  icon: Icons.aspect_ratio_rounded,
                  label: 'Lebar +',
                  onTap: () => setState(() {
                    final cur =
                        entry.customCrossSpan ?? 6;
                    entry.customCrossSpan = (cur + 1).clamp(2, 12);
                  }),
                ),
                _BlueBarToolItem(
                  icon: Icons.compress_rounded,
                  label: 'Lebar -',
                  onTap: () => setState(() {
                    final cur =
                        entry.customCrossSpan ?? 6;
                    entry.customCrossSpan = (cur - 1).clamp(2, 12);
                  }),
                ),
                _BlueBarToolItem(
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset',
                  onTap: () => setState(() => entry.resetTransform()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bar Ikon Utama di Bawah saat Sheet Ditutup (Scrollable persis Video 2: 00:55 - 02:38)
  Widget _buildCollapsedBottomToolbar(ColorScheme scheme) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          children: EditorBottomTab.values.map((tab) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _activeSheetTab = tab;
                  if (tab == EditorBottomTab.teks) {
                    _addOrSelectTextOverlay();
                  }
                });
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon, size: 22, color: scheme.onSurface),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Panel Sheet Bawah Ber-Tab (Tata Letak | Margin | Rasio | Latar belakang | Bingkai | Teks | Filter | Stiker | Tambahkan | Gambar) + Tombol ✓
  Widget _buildEditorBottomSheet(
    ColorScheme scheme,
    List<GridTemplateSpec> templates,
    int count,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Tab Sheet + Tombol Centang (✓) di Kanan
            Container(
              height: 44,
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: EditorBottomTab.values.map((tab) {
                        final isSelected = _activeSheetTab == tab;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _activeSheetTab = tab;
                              if (tab == EditorBottomTab.teks) {
                                _addOrSelectTextOverlay();
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected
                                      ? scheme.primary
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Selesai / Tutup Panel',
                    onPressed: () => setState(() => _activeSheetTab = null),
                    icon: const Icon(Icons.check_rounded, size: 22),
                  ),
                ],
              ),
            ),

            // Isi Konten Berdasarkan Tab yang Aktif
            SizedBox(
              height: 172,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: _buildActiveTabContent(scheme, templates, count),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(
    ColorScheme scheme,
    List<GridTemplateSpec> templates,
    int count,
  ) {
    switch (_activeSheetTab!) {
      // 1. TAB TATA LETAK: Grid 2 Baris Ikon Wireframe Visual
      case EditorBottomTab.tataLetak:
        return GridView.builder(
          scrollDirection: Axis.horizontal,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final tpl = templates[index];
            final isSelected = _selectedTemplateIndex == index;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedTemplateIndex = index;
                _layoutGroupWeights = [];
                _layoutItemWeights = [];
                _initLayoutWeightsIfNeeded(tpl);
                // Reset custom cell overrides agar bentuk template baru terlihat utuh
                for (final p in _photos) {
                  p.customCrossSpan = null;
                  p.customMainSpan = null;
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? scheme.primary : scheme.outlineVariant,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: CustomPaint(
                  painter: _WireframeTemplatePainter(
                    template: tpl,
                    color: isSelected
                        ? scheme.primary
                        : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            );
          },
        );

      // 2. TAB MARGIN: 3 Slider Persis Video (Luar, Spasi Antar Foto, Sudut Melengkung)
      case EditorBottomTab.margin:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MarginSliderRow(
              icon: Icons.crop_free_rounded,
              label: 'Luar',
              value: _outerMargin,
              max: 45,
              onChanged: (v) { setState(() => _outerMargin = v); _saveGridSettings(); },
            ),
            _MarginSliderRow(
              icon: Icons.grid_view_rounded,
              label: 'Spasi',
              value: _innerSpacing,
              max: 25,
              onChanged: (v) { setState(() => _innerSpacing = v); _saveGridSettings(); },
            ),
            _MarginSliderRow(
              icon: Icons.rounded_corner_rounded,
              label: 'Sudut',
              value: _cornerRadius,
              max: 28,
              onChanged: (v) { setState(() => _cornerRadius = v); _saveGridSettings(); },
            ),
          ],
        );

      // 3. TAB RASIO: Pilihan IG 1:1, IG 4:5, 5:4, 3:4, 9:16, 16:9, A4
      case EditorBottomTab.rasio:
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kAspectRatios.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = kAspectRatios[index];
            final isSelected = _selectedRatioIndex == index;
            return GestureDetector(
              onTap: () { setState(() => _selectedRatioIndex = index); _saveGridSettings(); },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: AspectRatio(
                      aspectRatio: item.ratio.clamp(0.55, 1.8),
                      child: Container(
                        margin: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );

      // 4. TAB LATAR BELAKANG (Persis Video 2: 00:57 - 01:10: Putih, Png Transparan, Warna)
      case EditorBottomTab.latar:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ActionButtonChip(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Putih',
                  onTap: () {
                    setState(() {
                      _isTransparentPngBg = false;
                      _backgroundColor = Colors.white;
                    });
                    _saveGridSettings();
                  },
                ),
                const SizedBox(width: 8),
                _ActionButtonChip(
                  icon: Icons.grid_on_rounded,
                  label: 'Png (Transparan)',
                  onTap: () { setState(() => _isTransparentPngBg = true); _saveGridSettings(); },
                ),
              ],
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _paletteColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final color = _paletteColors[index];
                  final isSelected =
                      !_isTransparentPngBg && _backgroundColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _isTransparentPngBg = false;
                        _backgroundColor = color;
                      });
                      _saveGridSettings();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

      // 5. TAB BINGKAI / TEPI: Pilihan Warna Garis Tepi Tiap Kotak + Slider Ketebalan
      case EditorBottomTab.bingkai:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _paletteColors.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isNone = _borderWidth == 0;
                    return GestureDetector(
                      onTap: () { setState(() => _borderWidth = 0); _saveGridSettings(); },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                isNone ? scheme.primary : scheme.outlineVariant,
                            width: isNone ? 2.5 : 1,
                          ),
                        ),
                        child: Icon(
                          Icons.block_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final color = _paletteColors[index - 1];
                  final isSelected =
                      _borderWidth > 0 && _borderColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _borderColor = color;
                        if (_borderWidth == 0) _borderWidth = 4.0;
                      });
                      _saveGridSettings();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _MarginSliderRow(
              icon: Icons.line_weight_rounded,
              label: 'Tebal',
              value: _borderWidth,
              max: 15,
              onChanged: (v) { setState(() => _borderWidth = v); _saveGridSettings(); },
            ),
          ],
        );

      // 6. TAB TEKS (Aa) (Persis Video 2: 01:14 - 02:04: Papan Ketik | Font | Gaya | Koleksi 100% Gratis)
      case EditorBottomTab.teks:
        final activeText = (_selectedTextIndex != null &&
                _selectedTextIndex! < _textOverlays.length)
            ? _textOverlays[_selectedTextIndex!]
            : null;
        return Column(
          children: [
            // Sub-tab Teks: Papan Ketik, Font, Gaya, Koleksi + Tombol Tambah/Hapus Teks
            Row(
              children: [
                for (int i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        const ['Ketik', 'Font', 'Gaya', 'Koleksi'][i],
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _textEditorSubTab == i,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) =>
                          setState(() => _textEditorSubTab = i),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Tambah Teks Baru',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final t = CollageTextOverlay(
                      text: 'Teks ${_textOverlays.length + 1}',
                      position: const Offset(90, 140),
                    );
                    setState(() {
                      _textOverlays.add(t);
                      _selectedTextIndex = _textOverlays.length - 1;
                      _textInputController.text = t.text;
                    });
                    _openTextEditDialog(t);
                  },
                  icon: Icon(Icons.add_circle_outline_rounded,
                      size: 20, color: scheme.primary),
                ),
                if (activeText != null) ...[
                  IconButton(
                    tooltip: 'Edit Teks',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openTextEditDialog(activeText),
                    icon: Icon(Icons.edit_note_rounded,
                        size: 22, color: scheme.primary),
                  ),
                  IconButton(
                    tooltip: 'Hapus Teks Ini',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _textOverlays.removeAt(_selectedTextIndex!);
                        _selectedTextIndex = _textOverlays.isNotEmpty ? 0 : null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: Colors.redAccent),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: activeText == null
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: () =>
                            setState(() => _addOrSelectTextOverlay()),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Tambah Teks ke Kolase'),
                      ),
                    )
                  : _buildTextSubTabContent(scheme, activeText),
            ),
          ],
        );

      // 7. TAB FILTER WARNA (Persis Video 2: 02:06 - 02:17: Bright, Story, Warm, Dew, Cocoa, Grape + Slider)
      case EditorBottomTab.filter:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kColorFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final f = kColorFilters[index];
                  final isSelected = _selectedFilterIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilterIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        f.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _MarginSliderRow(
              icon: Icons.tune_rounded,
              label: 'Kuat',
              value: _filterIntensity * 100,
              max: 100,
              onChanged: (v) => setState(() => _filterIntensity = v / 100.0),
            ),
          ],
        );

      // 8. TAB STIKER (Persis Video 2: 02:20 - 02:22)
      case EditorBottomTab.stiker:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ketuk stiker untuk ditambahkan (ketuk 2x pada stiker di kanvas untuk menghapus):',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _freeStickers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final emoji = _freeStickers[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _stickerOverlays.add(
                          CollageStickerOverlay(label: emoji),
                        );
                      });
                    },
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                },
              ),
            ),
          ],
        );

      // 9. TAB TAMBAHKAN (Persis Video 2: 02:24: "Tambahkan ke Kisi" & "Foto dalam Foto")
      case EditorBottomTab.tambahkan:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickImagesFromDevice,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dashboard_customize_rounded,
                          size: 28, color: scheme.primary),
                      const SizedBox(height: 8),
                      const Text(
                        'Tambahkan ke Kisi',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Tambah sel foto baru',
                        style: TextStyle(
                            fontSize: 10.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _addPipOverlayPhoto,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_in_picture_alt_rounded,
                          size: 28, color: scheme.primary),
                      const SizedBox(height: 8),
                      const Text(
                        'Foto dalam Foto',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Foto melayang di atas',
                        style: TextStyle(
                            fontSize: 10.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

      // 10. TAB GAMBAR / CORETAN KUAS BEBAS (Persis Video 2: 02:25 - 02:38)
      case EditorBottomTab.gambar:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _ActionButtonChip(
                  icon: Icons.brush_rounded,
                  label: _brushIsNeon ? 'Kuas Neon' : 'Kuas Solid',
                  onTap: () => setState(() {
                    _brushIsEraser = false;
                    _brushIsNeon = !_brushIsNeon;
                  }),
                ),
                const SizedBox(width: 8),
                _ActionButtonChip(
                  icon: Icons.cleaning_services_rounded,
                  label: _brushIsEraser ? 'Penghapus Aktif' : 'Penghapus',
                  onTap: () =>
                      setState(() => _brushIsEraser = !_brushIsEraser),
                ),
                const SizedBox(width: 8),
                _ActionButtonChip(
                  icon: Icons.delete_sweep_rounded,
                  label: 'Bersihkan',
                  onTap: _drawStrokes.isEmpty
                      ? null
                      : () => setState(() => _drawStrokes.clear()),
                ),
              ],
            ),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _paletteColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final c = _paletteColors[index];
                  final isSelected = !_brushIsEraser && _brushColor == c;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _brushIsEraser = false;
                      _brushColor = c;
                    }),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _MarginSliderRow(
              icon: Icons.line_weight_rounded,
              label: 'Ukuran',
              value: _brushSize,
              min: 2,
              max: 28,
              onChanged: (v) => setState(() => _brushSize = v),
            ),
          ],
        );
    }
  }

  Widget _buildTextSubTabContent(
    ColorScheme scheme,
    CollageTextOverlay activeText,
  ) {
    // 0: Papan Ketik
    if (_textEditorSubTab == 0) {
      return Center(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textInputController,
                decoration: InputDecoration(
                  labelText: 'Ketik teks di atas kolase',
                  hintText: 'Contoh: Tugas 1 pameran',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    activeText.text = val.isEmpty ? ' ' : val;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Buka Dialog Edit Teks',
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: () => _openTextEditDialog(activeText),
            ),
          ],
        ),
      );
    }

    // 1: Font
    if (_textEditorSubTab == 1) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _fontOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = _fontOptions[i];
          final isSel =
              activeText.fontFamily == opt.id || activeText.fontFamily == opt.label;
          return GestureDetector(
            onTap: () => setState(() => activeText.fontFamily = opt.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? scheme.primary : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel ? scheme.primary : scheme.outlineVariant,
                  width: isSel ? 1.5 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                opt.label,
                style: opt.applyTo(
                  TextStyle(
                    fontSize: 13,
                    color: isSel ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // 2: Gaya (Warna Teks, Ukuran, Opasitas)
    if (_textEditorSubTab == 2) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _paletteColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final c = _paletteColors[index];
                final isSelected = activeText.textColor == c;
                return GestureDetector(
                  onTap: () => setState(() => activeText.textColor = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _MarginSliderRow(
            icon: Icons.format_size_rounded,
            label: 'Ukuran',
            value: activeText.fontSize,
            min: 12,
            max: 52,
            onChanged: (v) => setState(() => activeText.fontSize = v),
          ),
        ],
      );
    }

    // 3: Koleksi Preset Gaya Teks (100% Gratis Tanpa Iklan / Tanpa Gembok Pro!)
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: kFreeTextPresets.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final preset = kFreeTextPresets[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              activeText.textColor = preset.textColor;
              activeText.backgroundColor = preset.backgroundColor;
              activeText.strokeColor = preset.strokeColor;
              activeText.isNeon = preset.isNeon;
              activeText.hasShadow = preset.hasShadow;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: preset.backgroundColor ?? const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: preset.strokeColor ?? scheme.outlineVariant,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              preset.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: preset.textColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlueBarToolItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BlueBarToolItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter untuk Coretan Kuas Bebas (Fitur "Gambar" di Video 2: 02:25 - 02:38)
class _FreehandCanvasPainter extends CustomPainter {
  final List<FreehandStroke> strokes;

  _FreehandCanvasPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      if (s.isEraser) continue;

      final paint = Paint()
        ..color = s.color.withValues(alpha: s.opacity.clamp(0.1, 1.0))
        ..strokeWidth = s.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (s.isNeon) {
        final glowPaint = Paint()
          ..color = s.color.withValues(alpha: 0.55)
          ..strokeWidth = s.strokeWidth + 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        _drawPath(canvas, s.points, glowPaint);
      }

      _drawPath(canvas, s.points, paint);
    }
  }

  void _drawPath(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.length == 1) {
      canvas.drawCircle(pts.first, paint.strokeWidth / 2, paint);
      return;
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FreehandCanvasPainter oldDelegate) => true;
}

/// Painter kotak-kotak catur transparan saat mode Latar Belakang "Png" aktif
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cellSize = 14.0;
    final light = Paint()..color = const Color(0xFFE2E8F0);
    final dark = Paint()..color = const Color(0xFFCBD5E1);

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isEven = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MarginSliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _MarginSliderRow({
    required this.icon,
    required this.label,
    required this.value,
    this.min = 0.0,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${value.toInt()}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtonChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButtonChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: enabled ? scheme.onSurface : scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menggambar ikon mini wireframe bentuk kisi template (persis ikon-ikon di tab Tata Letak video GridArt)
class _WireframeTemplatePainter extends CustomPainter {
  final GridTemplateSpec template;
  final Color color;

  _WireframeTemplatePainter({
    required this.template,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final int cols = template.crossAxisCount;
    final double cellW = size.width / cols;

    // Hitung perkiraan susunan baris sederhana untuk digambar di ikon mini
    double curX = 0;
    double curY = 0;
    double rowMaxH = 0;

    // Cari total tinggi untuk menormalisasi ke size.height
    double totalEstimatedH = 0;
    int tempX = 0;
    double tempRowH = 0;
    for (final c in template.cells) {
      if (tempX + c.crossAxisSpan > cols) {
        totalEstimatedH += tempRowH;
        tempX = 0;
        tempRowH = 0;
      }
      tempX += c.crossAxisSpan;
      if (c.mainAxisSpan > tempRowH) tempRowH = c.mainAxisSpan;
    }
    totalEstimatedH += tempRowH;
    if (totalEstimatedH <= 0) totalEstimatedH = 12;

    for (final c in template.cells) {
      if (curX + c.crossAxisSpan > cols) {
        curY += rowMaxH;
        curX = 0;
        rowMaxH = 0;
      }
      final double w = c.crossAxisSpan * cellW;
      final double h = (c.mainAxisSpan / totalEstimatedH) * size.height;
      final rect = Rect.fromLTWH(
        curX * cellW + 1,
        curY + 1,
        (w - 2).clamp(2.0, size.width),
        (h - 2).clamp(2.0, size.height),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
      curX += c.crossAxisSpan;
      if (h > rowMaxH) rowMaxH = h;
    }
  }

  @override
  bool shouldRepaint(covariant _WireframeTemplatePainter oldDelegate) {
    return oldDelegate.template.id != template.id ||
        oldDelegate.color != color;
  }
}
