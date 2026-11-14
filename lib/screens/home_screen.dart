import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_stamp_screen.dart';
import '../widgets/changelog_dialog.dart';
import '../widgets/theme_toggle_button.dart';
import 'grid_screen.dart';

/// Android alpha: true (default). Build iOS v1.0.2: --dart-define=FOTOMARK_ENABLED=false
const bool kFotoMarkEnabled =
    bool.fromEnvironment('FOTOMARK_ENABLED', defaultValue: true);

class HomeScreen extends StatefulWidget {
  final bool autoShowChangelog;
  const HomeScreen({super.key, this.autoShowChangelog = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoShowChangelog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowChangelog();
      });
    }
  }

  Future<void> _checkAndShowChangelog() async {
    const versionKey = '1_1_4';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/hide_changelog_$versionKey.txt');
      if (file.existsSync()) return;
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ChangelogDialog(versionKey: versionKey),
    );
  }

  void _openGrid(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GridScreen(autoOpenPicker: true)),
    );
  }

  void _openFotoMark(BuildContext context) {
    // Build iOS (v1.0.2): Foto Mark dikunci via --dart-define=FOTOMARK_ENABLED=false
    if (!kFotoMarkEnabled) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Color(0xFF0D9488), size: 28),
              SizedBox(width: 10),
              Text(
                'Segera Hadir',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'Fitur Kamera Timestamp sedang dalam tahap penyempurnaan agar lebih stabil di semua tipe HP.\n\nSaat ini, silakan gunakan fitur Kolase Grid Foto terlebih dahulu.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraStampScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TOP BAR BERSIH (Logo + Nama Aplikasi + Tombol Dark/Light Mode)
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/logo_transparent.png',
                      width: 26,
                      height: 26,
                      color: scheme.primary,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.space_dashboard_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Grid & TimeMark',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded),
                    tooltip: 'Apa yang Baru?',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) =>
                            const ChangelogDialog(versionKey: '1_1_4'),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  const ThemeToggleButton(),
                ],
              ),

              const Spacer(flex: 1),

              // Identitas Tim: CSO - TIM
              Center(
                child: Text(
                  'CSO - TIM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 2. VISUAL BANNER ATAS (Mirip Showcase Card GridArt)
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [
                              Color(0xFF064E3B),
                              Color(0xFF0F766E),
                              Color(0xFF134E4A),
                            ]
                          : const [
                              Color(0xFF0D9488),
                              Color(0xFF0F766E),
                              Color(0xFF115E59),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      // Ilustrasi 2 Fitur (Grid & Foto Mark)
                      Container(
                        width: 220,
                        height: 130,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Sisi Kiri: Ilustrasi Grid
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.rotate_right_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0D9488),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.zoom_in_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF047857),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'MAX 50 FOTO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Sisi Kanan: Ilustrasi Foto Mark
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0284C7),
                                      Color(0xFF0369A1),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: Color(0xFF7DF8D6),
                                      size: 16,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'FOTO MARK\nGPS & Waktu',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Kolase Laporan & Kamera Timestamp',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih fitur di bawah untuk mulai bekerja',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

              const SizedBox(height: 18),

              // 3. HANYA 2 TOMBOL PILIHAN UTAMA: "Grid" & "Foto Mark" (Gaya GridArt)
              Row(
                children: [
                  Expanded(
                    child: _MainOptionButton(
                      title: 'Grid',
                      subtitle: 'Kolase 1–50 Foto',
                      icon: Icons.space_dashboard_rounded,
                      gradientColors: const [
                        Color(0xFF10B981), // Hijau Emerald Teal
                        Color(0xFF047857),
                      ],
                      onTap: () => _openGrid(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MainOptionButton(
                      title: 'Foto Mark',
                      subtitle: 'Kamera Timestamp',
                      badge: 'Coming Soon',
                      icon: Icons.camera_enhance_rounded,
                      gradientColors: const [
                        Color(0xFF0D9488), // Teal Cyan
                        Color(0xFF0369A1),
                      ],
                      onTap: () => _openFotoMark(context),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),
              Opacity(
                opacity: 0.45,
                child: Column(
                  children: [
                    Text(
                      'Created by Latif Muhith Wibowo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'ZenLloyd',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol utama bergaya GridArt (Hanya 2 opsi: Grid & Foto Mark)
class _MainOptionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final String? badge;

  const _MainOptionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

