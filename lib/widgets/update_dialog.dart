import 'package:flutter/material.dart';

import '../services/app_update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _isCancelled = false;
  int _receivedBytes = 0;
  int _totalBytes = -1;
  String? _downloadedFilePath;
  String? _errorMessage;
  String? _statusNote;

  String _formatMegabytes(int bytes) {
    if (bytes <= 0) return '0.0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _isCancelled = false;
      _receivedBytes = 0;
      _totalBytes = -1;
      _errorMessage = null;
      _statusNote = 'Menghubungkan ke server pembaruan...';
    });

    try {
      final path = await AppUpdateService.downloadApk(
        url: widget.updateInfo.apkUrl,
        isCancelled: () => _isCancelled,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _receivedBytes = received;
            _totalBytes = total;
            _statusNote = 'Mengunduh pembaruan... Jangan tutup aplikasi.';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadedFilePath = path;
        _statusNote = 'Unduhan selesai! Membuka pemasang paket Android...';
      });

      await _triggerInstall(path);
    } catch (e) {
      if (!mounted) return;
      if (_isCancelled) {
        setState(() {
          _isDownloading = false;
          _statusNote = null;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isDownloading = false;
          _statusNote = null;
          _errorMessage = 'Gagal mengunduh pembaruan: $e';
        });
      }
    }
  }

  Future<void> _triggerInstall(String path) async {
    try {
      final status = await AppUpdateService.installApk(path);
      if (!mounted) return;
      if (status == 'REQUESTING_PERMISSION') {
        setState(() {
          _statusNote =
              'Aktifkan izin "Instal aplikasi tidak dikenal" untuk Grid & TimeMark, lalu instalasi akan berjalan otomatis.';
        });
      } else {
        setState(() {
          _statusNote =
              'Jendela instalasi dibuka. Tekan "Update / Instal" pada layar sistem Android.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal membuka installer APK: $e';
      });
    }
  }

  @override
  void dispose() {
    _isCancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = widget.updateInfo;
    final double? progressValue =
        (_totalBytes > 0) ? (_receivedBytes / _totalBytes).clamp(0.0, 1.0) : null;
    final int percent =
        progressValue != null ? (progressValue * 100).round() : 0;

    return PopScope(
      canPop: !_isDownloading && !info.forceUpdate,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Gaya OBS Studio Updater
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pembaruan Tersedia!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v$kCurrentAppVersion',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v${info.latestVersion}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!_isDownloading && !info.forceUpdate)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                      ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),

                Text(
                  'Apa yang Baru di Versi ${info.latestVersion}:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                // Daftar Catatan Rilis (Scrollable, Anti-AI-Slop Bullet Points)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: info.changelog.isEmpty
                        ? Text(
                            'Peningkatan stabilitas dan perbaikan bug.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: info.changelog.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = info.changelog[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    width: 6.5,
                                    height: 6.5,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (item.description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              fontSize: 11.8,
                                              color: scheme.onSurfaceVariant,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ),

                // Area Progress Unduhan / Status / Error
                if (_isDownloading) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        progressValue != null
                            ? 'Mengunduh APK ($percent%)'
                            : 'Mengunduh APK...',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _totalBytes > 0
                            ? '${_formatMegabytes(_receivedBytes)} / ${_formatMegabytes(_totalBytes)}'
                            : _formatMegabytes(_receivedBytes),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 8,
                    ),
                  ),
                ],

                if (_statusNote != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusNote!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Tombol Pilihan Bawah: "Nanti Saja (Stay)" vs "Update Sekarang"
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_isDownloading)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isCancelled = true;
                          });
                        },
                        child: const Text(
                          'Batal Unduh',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else ...[
                      if (!info.forceUpdate)
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Nanti Saja',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (_downloadedFilePath != null)
                        FilledButton.icon(
                          onPressed: () =>
                              _triggerInstall(_downloadedFilePath!),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.install_mobile_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Pasang Sekarang',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _startDownloadAndInstall,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.download_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _errorMessage != null
                                ? 'Coba Unduh Lagi'
                                : 'Update Sekarang',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
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
