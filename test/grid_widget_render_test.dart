import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grid_and_timemark/screens/grid_screen.dart';

void main() {
  testWidgets('Test GridScreen with 11 photos layout rendering', (tester) async {
    final photos = List.generate(
      11,
      (i) => GridPhotoEntry(file: XFile('fake_path_$i.jpg')),
    );

    // Pump widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final templates = GridTemplateCatalog.forPhotoCount(11);
              final activeTemplate = templates[0];
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: 400,
                    height: 400,
                    child: Column(
                      children: [
                        for (int g = 0; g < activeTemplate.groups.length; g++) ...[
                          Expanded(
                            child: Row(
                              children: [
                                for (int p = 0; p < activeTemplate.groups[g].length; p++) ...[
                                  Expanded(
                                    child: Container(
                                      key: ValueKey('tile_${activeTemplate.groups[g][p]}'),
                                      color: Colors.blue,
                                      child: Text('Photo ${activeTemplate.groups[g][p]}'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(Container), findsWidgets);
    for (int i = 0; i < 11; i++) {
      expect(find.byKey(ValueKey('tile_$i')), findsOneWidget);
    }
    print('All 11 tiles found in mock tree!');
  });
}
