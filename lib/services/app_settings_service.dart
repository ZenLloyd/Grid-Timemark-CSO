import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class GridSettingsData {
  int selectedRatioIndex;
  double outerMargin;
  double innerSpacing;
  double cornerRadius;
  double borderWidth;
  int borderColorValue;
  int backgroundColorValue;
  bool isTransparentPngBg;

  GridSettingsData({
    this.selectedRatioIndex = 0,
    this.outerMargin = 0.0,
    this.innerSpacing = 4.0,
    this.cornerRadius = 0.0,
    this.borderWidth = 0.0,
    this.borderColorValue = 0xFFFFFFFF,
    this.backgroundColorValue = 0xFFFFFFFF,
    this.isTransparentPngBg = false,
  });

  Map<String, dynamic> toJson() => {
        'selectedRatioIndex': selectedRatioIndex,
        'outerMargin': outerMargin,
        'innerSpacing': innerSpacing,
        'cornerRadius': cornerRadius,
        'borderWidth': borderWidth,
        'borderColorValue': borderColorValue,
        'backgroundColorValue': backgroundColorValue,
        'isTransparentPngBg': isTransparentPngBg,
      };

  factory GridSettingsData.fromJson(Map<String, dynamic> j) => GridSettingsData(
        selectedRatioIndex: (j['selectedRatioIndex'] as num?)?.toInt() ?? 0,
        outerMargin: (j['outerMargin'] as num?)?.toDouble() ?? 0.0,
        innerSpacing: (j['innerSpacing'] as num?)?.toDouble() ?? 4.0,
        cornerRadius: (j['cornerRadius'] as num?)?.toDouble() ?? 0.0,
        borderWidth: (j['borderWidth'] as num?)?.toDouble() ?? 0.0,
        borderColorValue:
            (j['borderColorValue'] as num?)?.toInt() ?? Colors.white.toARGB32(),
        backgroundColorValue: (j['backgroundColorValue'] as num?)?.toInt() ??
            Colors.white.toARGB32(),
        isTransparentPngBg: j['isTransparentPngBg'] as bool? ?? false,
      );
}

class TimemarkSettingsData {
  String activeTemplateId;
  int accentColorValue;
  bool showLogo;
  String? logoPath;
  bool showCompany;
  String companyName;
  bool showOfficerName;
  String officerName;
  bool showBusinessCard;
  String businessCardRole;
  bool showTime;
  bool showAddress;
  bool showMiniMap;
  bool showCoordinates;
  bool showAltitude;
  bool showStyledNote;
  String styledNoteText;
  bool showTag;
  String tagText;
  bool showVerifyCode;
  bool showCustomNotes;
  List<Map<String, String>> customNotes;
  bool showGrid3x3;
  bool showSideVerifyCode;
  String bottomModeName;

  TimemarkSettingsData({
    this.activeTemplateId = 'waktu_lokasi',
    this.accentColorValue = 0xFFF59E0B,
    this.showLogo = false,
    this.logoPath,
    this.showCompany = false,
    this.companyName = '',
    this.showOfficerName = false,
    this.officerName = '',
    this.showBusinessCard = false,
    this.businessCardRole = '',
    this.showTime = true,
    this.showAddress = true,
    this.showMiniMap = false,
    this.showCoordinates = false,
    this.showAltitude = false,
    this.showStyledNote = false,
    this.styledNoteText = '',
    this.showTag = false,
    this.tagText = '',
    this.showVerifyCode = false,
    this.showCustomNotes = false,
    this.customNotes = const [],
    this.showGrid3x3 = false,
    this.showSideVerifyCode = false,
    this.bottomModeName = 'foto',
  });

  Map<String, dynamic> toJson() => {
        'activeTemplateId': activeTemplateId,
        'accentColorValue': accentColorValue,
        'showLogo': showLogo,
        'logoPath': logoPath,
        'showCompany': showCompany,
        'companyName': companyName,
        'showOfficerName': showOfficerName,
        'officerName': officerName,
        'showBusinessCard': showBusinessCard,
        'businessCardRole': businessCardRole,
        'showTime': showTime,
        'showAddress': showAddress,
        'showMiniMap': showMiniMap,
        'showCoordinates': showCoordinates,
        'showAltitude': showAltitude,
        'showStyledNote': showStyledNote,
        'styledNoteText': styledNoteText,
        'showTag': showTag,
        'tagText': tagText,
        'showVerifyCode': showVerifyCode,
        'showCustomNotes': showCustomNotes,
        'customNotes': customNotes,
        'showGrid3x3': showGrid3x3,
        'showSideVerifyCode': showSideVerifyCode,
        'bottomModeName': bottomModeName,
      };

  factory TimemarkSettingsData.fromJson(Map<String, dynamic> j) {
    final rawNotes = (j['customNotes'] as List<dynamic>?) ?? [];
    final notes = rawNotes
        .whereType<Map>()
        .map((m) => {
              'title': (m['title'] ?? '').toString(),
              'content': (m['content'] ?? '').toString(),
            })
        .toList();
    return TimemarkSettingsData(
      activeTemplateId: (j['activeTemplateId'] as String?) ?? 'waktu_lokasi',
      accentColorValue: (j['accentColorValue'] as num?)?.toInt() ?? 0xFFF59E0B,
      showLogo: j['showLogo'] as bool? ?? false,
      logoPath: j['logoPath'] as String?,
      showCompany: j['showCompany'] as bool? ?? false,
      companyName: (j['companyName'] as String?) ?? '',
      showOfficerName: j['showOfficerName'] as bool? ?? false,
      officerName: (j['officerName'] as String?) ?? '',
      showBusinessCard: j['showBusinessCard'] as bool? ?? false,
      businessCardRole: (j['businessCardRole'] as String?) ?? '',
      showTime: j['showTime'] as bool? ?? true,
      showAddress: j['showAddress'] as bool? ?? true,
      showMiniMap: j['showMiniMap'] as bool? ?? false,
      showCoordinates: j['showCoordinates'] as bool? ?? false,
      showAltitude: j['showAltitude'] as bool? ?? false,
      showStyledNote: j['showStyledNote'] as bool? ?? false,
      styledNoteText: (j['styledNoteText'] as String?) ?? '',
      showTag: j['showTag'] as bool? ?? false,
      tagText: (j['tagText'] as String?) ?? '',
      showVerifyCode: j['showVerifyCode'] as bool? ?? false,
      showCustomNotes: j['showCustomNotes'] as bool? ?? false,
      customNotes: notes,
      showGrid3x3: j['showGrid3x3'] as bool? ?? false,
      showSideVerifyCode: j['showSideVerifyCode'] as bool? ?? false,
      bottomModeName: (j['bottomModeName'] as String?) ?? 'foto',
    );
  }
}

class AppSettingsService {
  static Future<File> _gridFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/grid_settings.json');
  }

  static Future<File> _timemarkFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/timemark_settings.json');
  }

  static Future<GridSettingsData> loadGridSettings() async {
    try {
      final f = await _gridFile();
      if (!f.existsSync()) return GridSettingsData();
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return GridSettingsData.fromJson(map);
    } catch (_) {
      return GridSettingsData();
    }
  }

  static Future<void> saveGridSettings(GridSettingsData data) async {
    try {
      final f = await _gridFile();
      await f.writeAsString(jsonEncode(data.toJson()), flush: true);
    } catch (_) {}
  }

  static Future<TimemarkSettingsData> loadTimemarkSettings() async {
    try {
      final f = await _timemarkFile();
      if (!f.existsSync()) return TimemarkSettingsData();
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return TimemarkSettingsData.fromJson(map);
    } catch (_) {
      return TimemarkSettingsData();
    }
  }

  static Future<void> saveTimemarkSettings(TimemarkSettingsData data) async {
    try {
      final f = await _timemarkFile();
      await f.writeAsString(jsonEncode(data.toJson()), flush: true);
    } catch (_) {}
  }
}
