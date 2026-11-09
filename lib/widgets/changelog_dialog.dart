import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ChangelogDialog extends StatefulWidget {
  final String versionKey;
  final int autoCloseSeconds;

  const ChangelogDialog({
    super.key,
    required this.versionKey,
    this.autoCloseSeconds = 5,
  });

  @override
  State<ChangelogDialog> createState() => _ChangelogDialogState();
}

class _ChangelogDialogState extends State<ChangelogDialog> {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.autoCloseSeconds;
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _dismissDialog();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  Future<void> _savePreferenceIfChecked() async {
    if (_dontShowAgain) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/hide_changelog_${widget.versionKey}.txt');
        await file.writeAsString('hidden');
      } catch (_) {}
    }
  }

  void _dismissDialog() async {
    _countdownTimer?.cancel();
    await _savePreferenceIfChecked();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _dismissAndNeverShowAgain() async {
    _countdownTimer?.cancel();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/hide_changelog_${widget.versionKey}.txt');
      await file.writeAsString('hidden');
    } catch (_) {}
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    const items = [
      _ChangelogItem(
        title: 'Loading Foto Instan',
        description: 'Buka hingga 20 foto dari Galeri HP langsung tampil tanpa lag atau freeze.',
      ),
      _ChangelogItem(
        title: 'Katalog Grid Komplit (1-20 Foto)',
        description: 'Pilihan layout simetris rapi: 3x3 (9 foto), 4x3 & 3x4 (12 foto), 5x3 (15 foto), 4x4, 5x4, dll.',
      ),
      _ChangelogItem(
        title: 'Peringatan Batas 20 Foto',
        description: 'Notifikasi & pop-up otomatis jika foto melebihi kapasitas maksimal 20 foto.',
      ),
      _ChangelogItem(
        title: 'Simpan Galeri Ultra HD (2K)',
        description: 'Bebas bug foto hilang/blank putih. Hasil ekspor tajam dan tidak burik di WhatsApp.',
      ),
      _ChangelogItem(
        title: 'Auto-Lock Saat Edit Foto',
        description: 'Foto lain otomatis terkunci saat Anda sedang zoom atau menggeser 1 foto tertentu.',
      ),
      _ChangelogItem(
        title: '10 Pilihan Font Tipografi',
        description: 'Ganti gaya font teks secara real-time (Tegas, Tulisan Tangan, Mesin Tik, dll).',
      ),
      _ChangelogItem(
        title: 'Logo Monogram GT & Splash Screen',
        description: 'Tampilan pembuka elegan dengan signature "Made by ZenLloyd".',
      ),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: scheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Apa yang Baru?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Pembaruan Versi 1.0.2',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Tutup',
                    onPressed: _dismissDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // Daftar Pembaruan (Scrollable)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 7),
                          width: 6.5,
                          height: 6.5,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 8),

              // Checkbox Jangan Tampilkan Lagi
              InkWell(
                onTap: () {
                  setState(() {
                    _dontShowAgain = !_dontShowAgain;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _dontShowAgain,
                          onChanged: (val) {
                            setState(() {
                              _dontShowAgain = val ?? false;
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Jangan tampilkan lagi',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Tombol Aksi Bawah: Lewati & Tutup (Countdown)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _dismissAndNeverShowAgain,
                    child: Text(
                      'Jangan Tampilkan Lagi',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _dismissDialog,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Tutup (${_remainingSeconds}s)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangelogItem {
  final String title;
  final String description;

  const _ChangelogItem({
    required this.title,
    required this.description,
  });
}
