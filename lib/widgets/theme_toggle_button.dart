import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tombol bulat Sun / Moon bergaya M3 seperti ThemeToggle.tsx di projek kuliah
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Tooltip(
          message: isDark
              ? 'Ganti ke mode terang (Light mode)'
              : 'Ganti ke mode gelap (Dark mode)',
          child: Material(
            color: scheme.surfaceContainerHigh,
            shape: CircleBorder(
              side: BorderSide(color: scheme.outlineVariant, width: 1),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: appThemeController.toggleTheme,
              child: SizedBox(
                width: 38,
                height: 38,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                    key: ValueKey<bool>(isDark),
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
