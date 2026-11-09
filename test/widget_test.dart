import 'package:flutter_test/flutter_test.dart';
import 'package:grid_and_timemark/main.dart';
import 'package:grid_and_timemark/screens/home_screen.dart';

void main() {
  testWidgets('Home screen displays Grid and Foto Mark buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GridTimeMarkApp(home: HomeScreen(autoShowChangelog: false)));

    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('Foto Mark'), findsOneWidget);
  });

  testWidgets('Foto Mark terkunci (Segera Hadir) saat FOTOMARK_ENABLED=false',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GridTimeMarkApp(home: HomeScreen(autoShowChangelog: false)));

    await tester.tap(find.text('Foto Mark'));
    await tester.pumpAndSettle();

    expect(find.text('Segera Hadir'), findsOneWidget);
  }, skip: kFotoMarkEnabled);
}
