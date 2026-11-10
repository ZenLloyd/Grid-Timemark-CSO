import 'package:flutter_test/flutter_test.dart';
import 'package:grid_and_timemark/screens/grid_screen.dart';
import 'package:grid_and_timemark/services/app_settings_service.dart';

void main() {
  test('GridSettingsData serialization round-trip preserves all values', () {
    final original = GridSettingsData(
      selectedRatioIndex: 2,
      outerMargin: 12.5,
      innerSpacing: 8.0,
      cornerRadius: 10.0,
      borderWidth: 3.5,
      borderColorValue: 0xFF10B981,
      backgroundColorValue: 0xFF111315,
      isTransparentPngBg: true,
    );
    final restored = GridSettingsData.fromJson(original.toJson());
    expect(restored.selectedRatioIndex, 2);
    expect(restored.outerMargin, 12.5);
    expect(restored.innerSpacing, 8.0);
    expect(restored.cornerRadius, 10.0);
    expect(restored.borderWidth, 3.5);
    expect(restored.borderColorValue, 0xFF10B981);
    expect(restored.backgroundColorValue, 0xFF111315);
    expect(restored.isTransparentPngBg, isTrue);
  });

  test('TimemarkSettingsData serialization round-trip preserves all fields', () {
    final original = TimemarkSettingsData(
      activeTemplateId: 'patroli',
      accentColorValue: 0xFF2563EB,
      showLogo: true,
      logoPath: '/path/logo.png',
      showCompany: true,
      companyName: 'PT Maju',
      showOfficerName: true,
      officerName: 'Andi',
      showBusinessCard: true,
      businessCardRole: 'Supervisor',
      showMiniMap: true,
      showCoordinates: true,
      showVerifyCode: true,
      customNotes: [
        {'title': 'Blok', 'content': 'Lantai 2'},
      ],
      bottomModeName: 'absensi',
    );
    final restored = TimemarkSettingsData.fromJson(original.toJson());
    expect(restored.activeTemplateId, 'patroli');
    expect(restored.accentColorValue, 0xFF2563EB);
    expect(restored.showLogo, isTrue);
    expect(restored.logoPath, '/path/logo.png');
    expect(restored.companyName, 'PT Maju');
    expect(restored.officerName, 'Andi');
    expect(restored.businessCardRole, 'Supervisor');
    expect(restored.showMiniMap, isTrue);
    expect(restored.showVerifyCode, isTrue);
    expect(restored.customNotes.length, 1);
    expect(restored.customNotes.first['content'], 'Lantai 2');
    expect(restored.bottomModeName, 'absensi');
  });

  test('GridTemplateCatalog generates valid symmetrical grids up to 50 photos', () {
    for (int count = 1; count <= 50; count++) {
      final templates = GridTemplateCatalog.forPhotoCount(count);
      expect(templates, isNotEmpty, reason: 'Failed for count=$count');
      for (final tpl in templates) {
        final totalCells = tpl.groups.fold<int>(0, (sum, g) => sum + g.length);
        expect(totalCells, count, reason: 'Template ${tpl.id} cell sum mismatch');
      }
    }
  });
}
