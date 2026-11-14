import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grid_and_timemark/screens/grid_screen.dart';

void main() {
  testWidgets('Test GridScreen collage editor stage with 11 photos', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync();
    final sampleFile = File('${tempDir.path}/sample.png');
    sampleFile.writeAsBytesSync([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);

    final initialPhotos = List.generate(
      11,
      (i) => XFile(sampleFile.path),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GridScreen(
          autoOpenPicker: false,
          initialPhotos: initialPhotos,
        ),
      ),
    );

    // Wait for async _initInitialPhotos to complete
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify 11 photos in editor
    expect(find.text('11 Foto'), findsOneWidget);
    print('Rendered 11 images successfully!');
  });
}
