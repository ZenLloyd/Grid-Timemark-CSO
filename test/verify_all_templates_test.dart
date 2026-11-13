import 'package:flutter_test/flutter_test.dart';
import 'package:grid_and_timemark/screens/grid_screen.dart';

void main() {
  test('Verify all templates for counts 1 to 50', () {
    for (int count = 1; count <= 50; count++) {
      final templates = GridTemplateCatalog.forPhotoCount(count);
      expect(templates.isNotEmpty, isTrue, reason: 'Count $count should have templates');

      for (int t = 0; t < templates.length; t++) {
        final tpl = templates[t];
        // Collect all photo indices in groups
        final indices = <int>[];
        for (final group in tpl.groups) {
          indices.addAll(group);
        }

        // Check total photo indices count matches count
        expect(
          indices.length,
          count,
          reason: 'Count $count template index $t (${tpl.id}) has ${indices.length} indices instead of $count',
        );

        // Check indices are exactly 0..(count-1)
        final sortedIndices = List<int>.from(indices)..sort();
        for (int i = 0; i < count; i++) {
          expect(
            sortedIndices[i],
            i,
            reason: 'Count $count template index $t (${tpl.id}) missing index $i: $sortedIndices',
          );
        }

        // Check weights match groups length if provided
        if (tpl.defaultGroupWeights != null) {
          expect(
            tpl.defaultGroupWeights!.length,
            tpl.groups.length,
            reason: 'Count $count template index $t group weights mismatch',
          );
        }
      }
    }
    print('All templates 1..50 validated successfully!');
  });
}
