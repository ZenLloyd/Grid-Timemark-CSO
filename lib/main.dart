import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

List<CameraDescription> globalCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi portrait agar layout kamera & grid konsisten
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Inisialisasi format tanggal bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi daftar kamera yang tersedia di perangkat
  try {
    globalCameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Gagal mendeteksi kamera: ${e.code} - ${e.description}');
  }

  runApp(const GridTimeMarkApp());
}

class GridTimeMarkApp extends StatelessWidget {
  final Widget? home;
  const GridTimeMarkApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Grid & TimeMark',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: home ?? const SplashScreen(),
        );
      },
    );
  }
}
