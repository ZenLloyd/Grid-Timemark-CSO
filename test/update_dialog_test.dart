import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_and_timemark/services/app_update_service.dart';
import 'package:grid_and_timemark/widgets/update_dialog.dart';

void main() {
  test('AppUpdateInfo parses version.json and detects newer versions', () {
    final jsonText = File('version.json').readAsStringSync();
    final map = jsonDecode(jsonText) as Map<String, dynamic>;
    final currentInfo = AppUpdateInfo.fromJson(map);

    expect(currentInfo.latestVersion, kCurrentAppVersion);
    expect(currentInfo.latestBuildNumber, kCurrentBuildNumber);
    expect(currentInfo.isUpdateAvailable, isFalse);

    final newerInfo = AppUpdateInfo.fromJson({
      ...map,
      'version': '1.2.0',
      'buildNumber': kCurrentBuildNumber + 1,
    });
    expect(newerInfo.isUpdateAvailable, isTrue);
    expect(newerInfo.changelog.isNotEmpty, isTrue);
  });

  testWidgets('UpdateDialog displays OBS-style update prompt and Nanti Saja / Update Sekarang', (tester) async {
    final info = AppUpdateInfo(
      latestVersion: '1.2.0',
      latestBuildNumber: kCurrentBuildNumber + 1,
      apkUrl: kDefaultApkDownloadUrl,
      changelog: const [
        UpdateChangelogItem(
          title: 'Fitur Auto-Update',
          description: 'Download update langsung di dalam aplikasi.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => UpdateDialog(updateInfo: info),
                  );
                },
                child: const Text('Buka Update'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Update'));
    await tester.pumpAndSettle();

    expect(find.text('Pembaruan Tersedia!'), findsOneWidget);
    expect(find.text('v$kCurrentAppVersion'), findsOneWidget);
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('Fitur Auto-Update'), findsOneWidget);
    expect(find.text('Nanti Saja'), findsOneWidget);
    expect(find.text('Update Sekarang'), findsOneWidget);

    // Tap 'Nanti Saja' to stay on current version
    await tester.tap(find.text('Nanti Saja'));
    await tester.pumpAndSettle();

    expect(find.text('Pembaruan Tersedia!'), findsNothing);
  });
}
