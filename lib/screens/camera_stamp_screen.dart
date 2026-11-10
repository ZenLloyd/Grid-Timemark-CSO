import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../services/image_export_service.dart';
import '../services/location_service.dart';
import '../services/photo_code_service.dart';

/// Model Catatan Tambahan ("Judul" & "Konten" persis video Timemark)
class TimemarkNoteItem {
  final String title;
  final String content;

  const TimemarkNoteItem({
    required this.title,
    required this.content,
  });
}

/// Model Templat Watermark Timemark
class TimemarkTemplateSpec {
  final String id;
  final String name;
  final String badge;
  final Color accentColor;
  final String description;

  const TimemarkTemplateSpec({
    required this.id,
    required this.name,
    required this.badge,
    required this.accentColor,
    required this.description,
  });
}

const List<TimemarkTemplateSpec> kTimemarkTemplates = [
  TimemarkTemplateSpec(
    id: 'waktu_lokasi',
    name: 'Waktu & Lokasi',
    badge: 'Default',
    accentColor: Color(0xFFF59E0B),
    description: 'Jam besar + garis vertikal + Tanggal & Lokasi',
  ),
  TimemarkTemplateSpec(
    id: 'e_absensi',
    name: 'e-Absensi',
    badge: 'Absensi',
    accentColor: Color(0xFFF59E0B),
    description: 'Badge Absensi + Jam + Tanggal + Kode Foto',
  ),
  TimemarkTemplateSpec(
    id: 'patroli',
    name: 'Patroli',
    badge: 'Patroli',
    accentColor: Color(0xFF2563EB),
    description: 'Header biru Patroli + Jam besar + Lokasi',
  ),
  TimemarkTemplateSpec(
    id: 'selesai',
    name: 'Selesai',
    badge: 'Selesai',
    accentColor: Color(0xFF10B981),
    description: 'Jam + Centang Selesai + Tanggal & Alamat',
  ),
  TimemarkTemplateSpec(
    id: 'bersih',
    name: 'Bersih',
    badge: 'Bersih',
    accentColor: Color(0xFF0EA5E9),
    description: 'Stempel kebersihan area + Jam + Lokasi',
  ),
  TimemarkTemplateSpec(
    id: 'report_kunjungan',
    name: 'Report Kunjungan',
    badge: 'Visit',
    accentColor: Color(0xFFEAB308),
    description: 'Badge kuning Visit + Jam + Tanggal & Lokasi',
  ),
  TimemarkTemplateSpec(
    id: 'catatan_proyek',
    name: 'Catatan Proyek',
    badge: 'Proyek',
    accentColor: Color(0xFF1D4ED8),
    description: 'Tabel rapi: Petugas, Kegiatan, Waktu & Lokasi',
  ),
  TimemarkTemplateSpec(
    id: 'catatan_kerja',
    name: 'Catatan Kerja',
    badge: 'Kerja',
    accentColor: Color(0xFFEA580C),
    description: 'Kartu oranye Catatan Kerja: Proyek, Inspeksi, Lokasi',
  ),
  TimemarkTemplateSpec(
    id: 'sederhana',
    name: 'Gaya Sederhana',
    badge: 'Minimalis',
    accentColor: Color(0xFF10B981),
    description: 'Satu baris ringkas: | Tanggal & Jam + Lokasi',
  ),
];

enum TimemarkBottomMode { laporan, video, foto, absensi, daftarPeriksa }

class CameraStampScreen extends StatefulWidget {
  const CameraStampScreen({super.key});

  @override
  State<CameraStampScreen> createState() => _CameraStampScreenState();
}

class _CameraStampScreenState extends State<CameraStampScreen>
    with WidgetsBindingObserver {
  final GlobalKey _stampBoundaryKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();

  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _showFlashBar = false;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Zoom state dinamis mengikuti hardware kamera bawaan HP (Ultrawide 0.5x/0.6x, 1x, 2x, Tele 3x/5x/10x..maxZoom)
  double _currentZoom = 1.0;
  double _baseScaleZoom = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 8.0;
  bool _hasUltrawideBackLens = false;
  int? _ultrawideCameraIndex;
  int _primaryBackCameraIndex = 0;
  bool _isUsingSecondaryUltrawideLens = false;
  bool _showZoomRuler = false;

  // Template & 15 Toggle Komponen Watermark (Persis Video Timemark)
  String _activeTemplateId = 'waktu_lokasi';
  Color _accentColor = const Color(0xFFF59E0B);

  // Semua isian identitas dikosongkan: sepenuhnya diisi oleh pengguna.
  // Aplikasi hanya menyediakan data nyata: waktu, lokasi, peta, ketinggian, kode foto.
  bool _showLogo = false;
  File? _logoFile;
  bool _showCompany = false;
  String _companyName = '';
  bool _showOfficerName = false;
  String _officerName = '';
  bool _showBusinessCard = false;
  String _businessCardRole = '';
  bool _showTime = true;
  bool _showAddress = true;
  String _addressText = 'Mencari lokasi GPS...';
  bool _showMiniMap = false;
  bool _showCoordinates = false;
  String _coordinatesText = 'Menunggu sinyal GPS...';
  double? _lat;
  double? _lon;
  bool _showAltitude = false;
  String _altitudeText = '';
  bool _showStyledNote = false;
  String _styledNoteText = '';
  bool _showTag = false;
  String _tagText = '';
  bool _showVerifyCode = false;
  bool _showCustomNotes = false;
  final List<TimemarkNoteItem> _customNotes = [];
  String _nextPhotoCode = PhotoCodeService.generateCode();

  // Pengaturan Kamera
  bool _showGrid3x3 = false;
  bool _showSideVerifyCode = false;
  final int _timerSeconds = 0; // 0, 3, 5, 10

  TimemarkBottomMode _bottomMode = TimemarkBottomMode.foto;
  File? _pickedGalleryBackground;
  final List<String> _capturedStampedPaths = [];
  bool _isProcessingCapture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLiveClock();
    _initCamera(_selectedCameraIndex);
    _refreshLiveGpsLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_selectedCameraIndex);
    }
  }

  void _startLiveClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Jangan ubah jam saat proses jepret berlangsung (waktu dibekukan)
      if (mounted && !_isProcessingCapture) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  Future<void> _initCamera(int cameraIndex, {double? targetZoom}) async {
    if (globalCameras.isEmpty) return;

    // Deteksi apakah HP memiliki beberapa lensa belakang (mis. Main + Ultrawide)
    final backIndices = <int>[];
    for (int i = 0; i < globalCameras.length; i++) {
      if (globalCameras[i].lensDirection == CameraLensDirection.back) {
        backIndices.add(i);
      }
    }
    if (backIndices.isNotEmpty) {
      _primaryBackCameraIndex = backIndices.first;
      if (backIndices.length > 1) {
        _hasUltrawideBackLens = true;
        _ultrawideCameraIndex = backIndices[1];
      }
    }

    final prevController = _cameraController;
    if (prevController != null) {
      await prevController.dispose();
    }

    final description = globalCameras[cameraIndex % globalCameras.length];
    CameraController controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _cameraController = controller;

    try {
      try {
        await controller.initialize();
      } catch (_) {
        // Fallback otomatis ke ResolutionPreset.medium untuk HP jadul/kentang
        await controller.dispose();
        controller = CameraController(
          description,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        _cameraController = controller;
        await controller.initialize();
      }
      await controller.setFlashMode(_flashMode);

      // Baca batas zoom asli dari hardware kamera bawaan HP
      final hwMinZoom = await controller.getMinZoomLevel();
      final hwMaxZoom = await controller.getMaxZoomLevel();

      _minAvailableZoom = hwMinZoom;
      _maxAvailableZoom = hwMaxZoom > hwMinZoom ? hwMaxZoom : 8.0;

      final initialZoom = (targetZoom ?? 1.0).clamp(hwMinZoom, _maxAvailableZoom);
      await controller.setZoomLevel(initialZoom);
      _currentZoom = _isUsingSecondaryUltrawideLens ? 0.6 : initialZoom;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Gagal inisialisasi kamera: $e');
    }
  }

  bool get _isFrontCameraActive {
    if (globalCameras.isEmpty) return false;
    return globalCameras[_selectedCameraIndex % globalCameras.length]
            .lensDirection ==
        CameraLensDirection.front;
  }

  /// Menghasilkan daftar preset zoom sesuai kemampuan hardware kamera HP
  /// (Ultrawide 0.5x/0.6x jika didukung, 1x, 2x, Telephoto 3x/5x/10x, hingga Max Zoom HP)
  List<double> _getHardwareZoomPresets() {
    final presets = <double>[];

    // 1. Ultrawide (jika minZoom < 1.0 dari CameraX/iOS, atau ada lensa belakang ke-2 saat kamera belakang aktif)
    if (_minAvailableZoom < 0.95 && !_isFrontCameraActive) {
      final uw = double.parse(_minAvailableZoom.toStringAsFixed(1));
      presets.add(uw);
    } else if (_hasUltrawideBackLens && !_isFrontCameraActive) {
      presets.add(0.6);
    }

    // 2. Lensa Utama 1.0x
    presets.add(1.0);

    // Khusus Kamera Depan: hanya sediakan 1.0x dan 2.0x (selfie tidak memiliki telephoto panjang)
    if (_isFrontCameraActive) {
      if (_maxAvailableZoom >= 2.0) presets.add(2.0);
      return presets.reversed.toList();
    }

    // 3. Lensa 2x / Telephoto / Periskop / Max Zoom sesuai kemampuan sensor HP belakang
    if (_maxAvailableZoom >= 2.0) presets.add(2.0);
    if (_maxAvailableZoom >= 3.0 && _maxAvailableZoom < 15.0) presets.add(3.0);
    if (_maxAvailableZoom >= 5.0) presets.add(5.0);
    if (_maxAvailableZoom >= 10.0) presets.add(10.0);

    final roundedMax = _maxAvailableZoom.floorToDouble();
    if (roundedMax > 2.0 && !presets.contains(roundedMax)) {
      presets.add(roundedMax);
    }

    return presets.reversed.toList(); // Urut dari besar (atas) ke kecil (bawah)
  }

  String _formatZoomChip(double z) {
    if (z < 1.0) {
      // Contoh: 0.5 -> ".5", 0.6 -> ".6"
      final dec = ((z * 10).round() % 10);
      return '.$dec';
    }
    if (z == z.roundToDouble()) {
      return '${z.toInt()}';
    }
    return z.toStringAsFixed(1);
  }

  Future<void> _refreshLiveGpsLocation() async {
    try {
      final snapshot = await LocationService.getCurrentLocationSnapshot();
      if (!mounted) return;
      setState(() {
        _lat = snapshot.latitude;
        _lon = snapshot.longitude;
        _coordinatesText = snapshot.coordinatesText;
        _altitudeText = '${snapshot.altitude.toStringAsFixed(0)} m';
        if (snapshot.addressLine.isNotEmpty &&
            snapshot.addressLine != 'Alamat tidak ditemukan') {
          _addressText = snapshot.addressLine;
        } else {
          _addressText = 'Alamat tidak ditemukan (koordinat tetap valid)';
        }
      });
    } catch (e) {
      if (!mounted) return;
      // Jangan pernah memakai lokasi palsu: tampilkan alasan sebenarnya
      setState(() {
        _addressText = e.toString().replaceFirst('Exception: ', '');
        _coordinatesText = 'GPS belum tersedia';
      });
    }
  }

  Future<void> _setCameraZoom(double zoom) async {
    final controller = _cameraController;

    // Jika HP memisahkan lensa Ultrawide sebagai kamera belakang ke-2 (bukan via minZoom < 1.0)
    if (zoom < 1.0 &&
        _minAvailableZoom >= 1.0 &&
        _hasUltrawideBackLens &&
        _ultrawideCameraIndex != null) {
      if (!_isUsingSecondaryUltrawideLens) {
        _isUsingSecondaryUltrawideLens = true;
        _selectedCameraIndex = _ultrawideCameraIndex!;
        await _initCamera(_selectedCameraIndex, targetZoom: 1.0);
      }
      setState(() {
        _currentZoom = zoom;
        _showZoomRuler = false;
      });
      return;
    }

    // Jika kembali dari lensa Ultrawide terpisah ke lensa utama (>= 1.0x)
    if (zoom >= 1.0 && _isUsingSecondaryUltrawideLens) {
      _isUsingSecondaryUltrawideLens = false;
      _selectedCameraIndex = _primaryBackCameraIndex;
      await _initCamera(_selectedCameraIndex, targetZoom: zoom);
      setState(() {
        _currentZoom = zoom;
        _showZoomRuler = false;
      });
      return;
    }

    final clamped = zoom.clamp(_minAvailableZoom, _maxAvailableZoom);
    setState(() {
      _currentZoom = clamped;
      _showZoomRuler = false;
    });
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setZoomLevel(clamped);
      } catch (_) {}
    }
  }

  Future<void> _switchCamera() async {
    if (globalCameras.length < 2) return;
    _isUsingSecondaryUltrawideLens = false;
    // Beralih antara kamera Belakang Utama dan kamera Depan (via tombol atas atau Double-Tap layar)
    final currentDir =
        globalCameras[_selectedCameraIndex % globalCameras.length].lensDirection;
    final targetDir = currentDir == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    if (targetDir == CameraLensDirection.back) {
      _selectedCameraIndex = _primaryBackCameraIndex;
    } else {
      final nextIdx =
          globalCameras.indexWhere((cam) => cam.lensDirection == targetDir);
      if (nextIdx != -1) {
        _selectedCameraIndex = nextIdx;
      } else {
        _selectedCameraIndex = (_selectedCameraIndex + 1) % globalCameras.length;
      }
    }
    await _initCamera(_selectedCameraIndex, targetZoom: 1.0);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetDir == CameraLensDirection.front
                ? '🤳 Beralih ke Kamera Depan'
                : '📷 Beralih ke Kamera Belakang',
          ),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _pickedGalleryBackground = File(picked.path);
    });
  }

  Future<void> _captureAndStampPhoto() async {
    if (_isProcessingCapture) return;
    if (_bottomMode == TimemarkBottomMode.video) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode Video belum tersedia (Alpha). Gunakan mode Foto.'),
        ),
      );
      return;
    }
    // Bekukan waktu, lokasi, dan kode TEPAT saat shutter ditekan agar yang
    // tercetak di foto sama persis dengan yang tersimpan di riwayat.
    final shutterTime = DateTime.now();
    final shutterCode = _nextPhotoCode;
    final shutterLat = _lat;
    final shutterLon = _lon;
    final shutterAddress = _addressText;
    setState(() {
      _isProcessingCapture = true;
      _now = shutterTime;
    });

    try {
      if (_timerSeconds > 0) {
        await Future.delayed(Duration(seconds: _timerSeconds));
      }

      final controller = _cameraController;
      if (_pickedGalleryBackground == null &&
          controller != null &&
          controller.value.isInitialized) {
        final XFile rawShot = await controller.takePicture();
        setState(() {
          _pickedGalleryBackground = File(rawShot.path);
        });
      }

      // Beri waktu peta mini memuat tile sebelum diambil gambarnya
      await Future.delayed(Duration(milliseconds: _showMiniMap ? 900 : 150));

      final String savedPath = await ImageExportService.captureAndSaveToGallery(
        boundaryKey: _stampBoundaryKey,
        filePrefix: 'FotoMark',
        pixelRatio: 3.0,
      );

      // Catat ke riwayat lokal (kode unik per foto + hash berkas)
      try {
        await PhotoCodeService.save(PhotoRecord(
          code: shutterCode,
          capturedAt: shutterTime,
          latitude: shutterLat,
          longitude: shutterLon,
          address: shutterAddress,
          fileSha256: await PhotoCodeService.sha256OfFile(savedPath),
        ));
      } catch (_) {
        // Riwayat gagal tersimpan tidak boleh menggagalkan foto
      }

      if (!mounted) return;
      setState(() {
        _capturedStampedPaths.insert(0, savedPath);
        _pickedGalleryBackground = null;
        _nextPhotoCode = PhotoCodeService.generateCode();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _bottomMode == TimemarkBottomMode.absensi
                ? 'Absen Masuk berhasil disimpan ke Galeri!'
                : 'Foto Timestamp berhasil disimpan ke Galeri!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan foto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingCapture = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildLeftDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            if (_showFlashBar) _buildFlashDropdownBar(),
            Expanded(
              child: _bottomMode == TimemarkBottomMode.daftarPeriksa
                  ? _buildChecklistView()
                  : _buildViewfinderStack(),
            ),
            _buildBottomControlPanel(context),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TOP BAR PUTIH PERSIS TIMEMARK (00:01)
  // ===========================================================================
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 19, color: Color(0xFF1E293B)),
                onPressed: () => Navigator.pop(context),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.menu_rounded,
                    size: 22, color: Color(0xFF1E293B)),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _flashMode == FlashMode.off
                      ? Icons.flash_off_rounded
                      : Icons.flash_on_rounded,
                  size: 20,
                  color: const Color(0xFF1E293B),
                ),
                onPressed: () => setState(() => _showFlashBar = !_showFlashBar),
              ),
            ],
          ),
          // Pill Tengah: Verifikasi Foto
          GestureDetector(
            onTap: _openVerifySheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined,
                      size: 14, color: Color(0xFF334155)),
                  SizedBox(width: 4),
                  Text(
                    'Verifikasi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Kanan: Indikator GPS + Switch Camera
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _addressText = 'Mencari lokasi GPS...');
                  _refreshLiveGpsLocation();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _lat != null
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.my_location_rounded,
                          size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        _lat != null ? 'GPS' : 'GPS...',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.cameraswitch_outlined,
                    size: 21, color: Color(0xFF1E293B)),
                onPressed: _switchCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlashDropdownBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFlashOption(FlashMode.off, 'Mati', Icons.flash_off_rounded),
          _buildFlashOption(FlashMode.always, 'Nyala', Icons.flash_on_rounded),
          _buildFlashOption(FlashMode.auto, 'Auto', Icons.flash_auto_rounded),
          _buildFlashOption(
              FlashMode.torch, 'Senter', Icons.flashlight_on_rounded),
        ],
      ),
    );
  }

  Widget _buildFlashOption(FlashMode mode, String label, IconData icon) {
    final selected = _flashMode == mode;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _flashMode = mode;
          _showFlashBar = false;
        });
        await _cameraController?.setFlashMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFEF3C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: selected
                    ? const Color(0xFFB45309)
                    : const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFFB45309)
                    : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VIEWFINDER UTAMA + FLOATING ZOOM / EDIT CEPAT / ALAMAT + OVERLAY WATERMARK
  // ===========================================================================
  Widget _buildViewfinderStack() {
    final hwPresets = _getHardwareZoomPresets();
    final hasUltrawide = _minAvailableZoom < 0.95 ||
        (_hasUltrawideBackLens && !_isFrontCameraActive);
    final uwValue = _minAvailableZoom < 0.95
        ? double.parse(_minAvailableZoom.toStringAsFixed(1))
        : 0.6;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Double-tap layar viewfinder untuk membalik kamera Depan <-> Belakang
      onDoubleTap: _switchCamera,
      onScaleStart: (_) {
        _baseScaleZoom = _currentZoom;
      },
      onScaleUpdate: (details) {
        if ((details.scale - 1.0).abs() > 0.02) {
          final nextZ = (_baseScaleZoom * details.scale)
              .clamp(_minAvailableZoom, _maxAvailableZoom);
          _setCameraZoom(nextZ);
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Area yang di-capture ke Galeri (Foto + Watermark)
            RepaintBoundary(
              key: _stampBoundaryKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraPreviewOrBackground(),
                  // Gradient bawah halus
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 210,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Mini Map di Pojok Kiri Atas (peta nyata, hanya jika diaktifkan pengguna)
                  if (_showMiniMap)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _buildMiniMapOverlay(),
                    ),
                  // Overlay Watermark di Kiri Bawah (Ketuk -> Edit Template)
                  Positioned(
                    left: 12,
                    right: 58,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: () => _openEditTemplateSheet(context),
                      child: _buildLiveWatermarkContent(),
                    ),
                  ),
                  // Kode Foto Samping Vertikal (kode nyata, unik per foto)
                  if (_showSideVerifyCode)
                    Positioned(
                      right: 4,
                      top: 120,
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          color: Colors.black45,
                          child: Text(
                            'Kode Foto: $_nextPhotoCode',
                            style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Garis Bantu Grid Potret 3x3
            if (_showGrid3x3) _buildGrid3x3Lines(),

            // Tombol Floating Kanan: Zoom Dinamis Sesuai Kamera Bawaan HP + Edit Cepat + Alamat
            Positioned(
              right: 10,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showZoomRuler)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: hwPresets.map((z) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: InkWell(
                              onTap: () => _setCameraZoom(z),
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.black54,
                                child: Text(
                                  '${z >= 10 ? z.toInt() : z}x',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  // Stack Zoom Ringkas Mengikuti Kemampuan Lensa HP (Tele/2x, 1.0x, & Ultrawide .5/.6 jika ada)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        if (!_isFrontCameraActive && _maxAvailableZoom >= 5.0) ...[
                          _buildSmallZoomCircle('5', 5.0),
                          const SizedBox(height: 4),
                        ],
                        if (_maxAvailableZoom >= 2.0) ...[
                          _buildSmallZoomCircle('2', 2.0),
                          const SizedBox(height: 4),
                        ],
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showZoomRuler = !_showZoomRuler),
                          onDoubleTap: () => _setCameraZoom(1.0),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black87,
                              border:
                                  Border.all(color: Colors.white, width: 1.4),
                            ),
                            child: Text(
                              '${_currentZoom >= 10 ? _currentZoom.toInt() : _currentZoom.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (hasUltrawide) ...[
                          const SizedBox(height: 4),
                          _buildSmallZoomCircle(
                            _formatZoomChip(uwValue),
                            uwValue,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tombol Edit Cepat (Ikon Kotak Pensil persis 00:06 part 2)
                  _buildRightFloatingIconButton(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Edit Cepat',
                    onTap: () => _openQuickEditSheet(context),
                  ),
                  const SizedBox(height: 10),
                  // Tombol Pilih Alamat Terdekat (Ikon Pin Lokasi persis 00:10 part 2)
                  _buildRightFloatingIconButton(
                    icon: Icons.location_on_outlined,
                    tooltip: 'Alamat Terdekat',
                    onTap: () => _openAddressPickerSheet(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallZoomCircle(String label, double zoom) {
    return GestureDetector(
      onTap: () => _setCameraZoom(zoom),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black38,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRightFloatingIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _buildCameraPreviewOrBackground() {
    if (_pickedGalleryBackground != null) {
      return Image.file(
        _pickedGalleryBackground!,
        fit: BoxFit.cover,
        cacheWidth: 1280,
        filterQuality: FilterQuality.medium,
      );
    }
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      return CameraPreview(controller);
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: const Center(
        child: Text(
          'Memuat Kamera...',
          style: TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMapOverlay() {
    final lat = _lat;
    final lon = _lon;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: (lat == null || lon == null)
          ? const Center(
              child: Text(
                'Menunggu\nGPS...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF475569)),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: FlutterMap(
                    key: ValueKey('$lat,$lon'),
                    options: MapOptions(
                      initialCenter: LatLng(lat, lon),
                      initialZoom: 17,
                      interactionOptions:
                          const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'id.tim.csotim',
                      ),
                    ],
                  ),
                ),
                const Center(
                  child: Icon(Icons.location_on_rounded,
                      size: 28, color: Color(0xFFDC2626)),
                ),
                const Positioned(
                  right: 3,
                  bottom: 1,
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      fontSize: 6.5,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGrid3x3Lines() {
    return IgnorePointer(
      child: Column(
        children: List.generate(
          3,
          (_) => Expanded(
            child: Row(
              children: List.generate(
                3,
                (_) => Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // RENDER WATERMARK LIVE SESUAI TEMPLAT & 15 TOGGLE (00:01 - 00:35)
  // ===========================================================================
  Widget _buildLiveWatermarkContent() {
    final hhmm = DateFormat('HH:mm', 'id_ID').format(_now);
    final dateLong = DateFormat('dd MMMM yyyy', 'id_ID').format(_now);
    final dayName = DateFormat('EEEE', 'id_ID').format(_now);

    final pills = <String>[
      if (_showOfficerName && _officerName.isNotEmpty) _officerName,
      if (_showCompany && _companyName.isNotEmpty) _companyName,
      if (_showBusinessCard && _businessCardRole.isNotEmpty) _businessCardRole,
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white54, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showLogo && _logoFile != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  _logoFile!,
                  height: 28,
                  fit: BoxFit.contain,
                  cacheHeight: 120,
                ),
              ),
            ),

          // Baris Jam & Tanggal sesuai Template
          if (_showTime)
            if (_activeTemplateId == 'e_absensi' ||
                _activeTemplateId == 'bersih' ||
                _activeTemplateId == 'report_kunjungan') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      color: _accentColor,
                      child: Text(
                        _activeTemplateId == 'bersih'
                            ? 'Bersih ✨'
                            : (_activeTemplateId == 'report_kunjungan'
                                ? 'Visit'
                                : 'Absensi'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      color: Colors.white,
                      child: Text(
                        hhmm,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$dayName, $dateLong',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ] else ...[
              // Default "Waktu & Lokasi" (00:01 part 1: Jam 34px + Garis Vertikal + Tanggal & Hari)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hhmm,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLong,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        dayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],

          if (_showAddress) ...[
            const SizedBox(height: 4),
            Text(
              _addressText,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],

          if (_showCoordinates)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _coordinatesText,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.white70,
                ),
              ),
            ),

          if (_showAltitude && _altitudeText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Ketinggian $_altitudeText',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),

          if (_showStyledNote && _styledNoteText.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _styledNoteText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),

          if (_showCustomNotes && _customNotes.isNotEmpty)
            ..._customNotes.map(
              (n) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${n.title}: ${n.content}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          if (_showTag && _tagText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _tagText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6EE7B7),
                ),
              ),
            ),

          if (pills.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: pills
                  .map(
                    (p) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          if (_showVerifyCode)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 12, color: Color(0xFF34D399)),
                  const SizedBox(width: 4),
                  Text(
                    'Kode Foto: $_nextPhotoCode',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PANEL KONTROL BAWAH (FOTO LOKAL | SHUTTER | TEMPLAT + 5 MODE BAWAH)
  // ===========================================================================
  Widget _buildBottomControlPanel(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris Foto Lokal | Shutter | Templat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Foto Lokal
              GestureDetector(
                onTap: _pickPhotoFromGallery,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.photo_library_outlined,
                          color: Color(0xFF334155), size: 20),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Foto Lokal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol Shutter Bulat atau Pill Hijau Absen Masuk
              if (_bottomMode == TimemarkBottomMode.absensi)
                ElevatedButton.icon(
                  onPressed: _captureAndStampPhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text(
                    'Absen Masuk',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                )
              else
                GestureDetector(
                  onTap: _captureAndStampPhoto,
                  child: Container(
                    width: 66,
                    height: 66,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF0F172A), width: 5),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _bottomMode == TimemarkBottomMode.video
                            ? const Color(0xFFDC2626)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),

              // Templat
              GestureDetector(
                onTap: () => _openTemplateGallerySheet(context),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.description_outlined,
                          color: Color(0xFF334155), size: 20),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Templat',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          // 5 Tab Mode Bawah: Laporan | Video | Foto | Absensi | DaftarPeriksa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomModeTab(TimemarkBottomMode.laporan, 'Laporan'),
              _buildBottomModeTab(TimemarkBottomMode.video, 'Video'),
              _buildBottomModeTab(TimemarkBottomMode.foto, 'Foto'),
              _buildBottomModeTab(TimemarkBottomMode.absensi, 'Absensi'),
              _buildBottomModeTab(
                  TimemarkBottomMode.daftarPeriksa, 'DaftarPeriksa'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomModeTab(TimemarkBottomMode mode, String label) {
    final active = _bottomMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _bottomMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF0F172A) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistView() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Formulir Foto',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Isi sendiri sesuai kebutuhan pekerjaan Anda',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Formulir belum tersedia (Alpha). Untuk sekarang, gunakan kolom Catatan Kustom di Edit Template.',
              style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DRAWER KIRI (RASIO, TIMER, FILTER, SETELAN, TOGGLE LOGO TIMEMARK)
  // ===========================================================================
  Widget _buildLeftDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _officerName.isEmpty ? 'Pengaturan' : _officerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (_companyName.isNotEmpty)
                Text(
                  _companyName,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_outlined,
                    color: Color(0xFF0F172A)),
                title: const Text(
                  'Verifikasi Kode Foto',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openVerifySheet();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Grid Potret (3x3)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                value: _showGrid3x3,
                onChanged: (v) => setState(() => _showGrid3x3 = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Kode Foto (Samping)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                value: _showSideVerifyCode,
                onChanged: (v) => setState(() => _showSideVerifyCode = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM SHEETS: EDIT TEMPLATE, EDIT CEPAT, ALAMAT TERDEKAT, & GALERI TEMPLAT
  // ===========================================================================
  void _openEditTemplateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void updateBoth(VoidCallback fn) {
              setState(fn);
              setModalState(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit template',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF334155)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('Logo (dari galeri Anda)',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      subtitle: Text(
                          _logoFile == null
                              ? 'Belum ada logo dipilih'
                              : 'Logo terpasang',
                          style: const TextStyle(fontSize: 11)),
                      value: _showLogo,
                      onChanged: (v) async {
                        if (v && _logoFile == null) {
                          await _pickLogo();
                          if (_logoFile == null) return;
                        }
                        updateBoth(() => _showLogo = v);
                      },
                    ),
                    if (_logoFile != null)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.image_outlined),
                        title: const Text('Ganti logo'),
                        onTap: () async {
                          await _pickLogo();
                          updateBoth(() {});
                        },
                      ),
                    SwitchListTile(
                      title: Text(
                          'Perusahaan${_companyName.isEmpty ? ' (isi di Edit Cepat)' : ': $_companyName'}',
                          style: const TextStyle(color: Color(0xFF1E293B))),
                      value: _showCompany,
                      onChanged: (v) => updateBoth(() => _showCompany = v),
                    ),
                    SwitchListTile(
                      title: Text(
                          'Nama${_officerName.isEmpty ? ' (isi di Edit Cepat)' : ': $_officerName'}',
                          style: const TextStyle(color: Color(0xFF1E293B))),
                      value: _showOfficerName,
                      onChanged: (v) => updateBoth(() => _showOfficerName = v),
                    ),
                    SwitchListTile(
                      title: Text(
                          'Jabatan${_businessCardRole.isEmpty ? ' (isi di Edit Cepat)' : ': $_businessCardRole'}',
                          style: const TextStyle(color: Color(0xFF1E293B))),
                      value: _showBusinessCard,
                      onChanged: (v) => updateBoth(() => _showBusinessCard = v),
                    ),
                    SwitchListTile(
                      title: const Text('Waktu Live',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showTime,
                      onChanged: (v) => updateBoth(() => _showTime = v),
                    ),
                    SwitchListTile(
                      title: const Text('Alamat Lokasi',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showAddress,
                      onChanged: (v) => updateBoth(() => _showAddress = v),
                    ),
                    SwitchListTile(
                      title: const Text('Peta Mini',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showMiniMap,
                      onChanged: (v) => updateBoth(() => _showMiniMap = v),
                    ),
                    SwitchListTile(
                      title: const Text('Koordinat GPS',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showCoordinates,
                      onChanged: (v) => updateBoth(() => _showCoordinates = v),
                    ),
                    SwitchListTile(
                      title: const Text('Ketinggian (dari GPS)',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showAltitude,
                      onChanged: (v) => updateBoth(() => _showAltitude = v),
                    ),
                    SwitchListTile(
                      title: const Text('Styled Note',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showStyledNote,
                      onChanged: (v) => updateBoth(() => _showStyledNote = v),
                    ),
                    SwitchListTile(
                      title: const Text('Tag',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showTag,
                      onChanged: (v) => updateBoth(() => _showTag = v),
                    ),
                    SwitchListTile(
                      title: const Text('Kode Foto (unik per foto)',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showVerifyCode,
                      onChanged: (v) => updateBoth(() => _showVerifyCode = v),
                    ),
                    SwitchListTile(
                      title: const Text('Catatan Kustom',
                          style: TextStyle(color: Color(0xFF1E293B))),
                      value: _showCustomNotes,
                      onChanged: (v) => updateBoth(() => _showCustomNotes = v),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _openQuickEditSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: _officerName);
    final compCtrl = TextEditingController(text: _companyName);
    final roleCtrl = TextEditingController(text: _businessCardRole);
    final noteCtrl = TextEditingController(text: _styledNoteText);
    final tagCtrl = TextEditingController(text: _tagText);
    final noteTitleCtrl = TextEditingController(
        text: _customNotes.isNotEmpty ? _customNotes.first.title : '');
    final noteBodyCtrl = TextEditingController(
        text: _customNotes.isNotEmpty ? _customNotes.first.content : '');

    InputDecoration deco(String label, String hint) =>
        InputDecoration(labelText: label, hintText: hint);
    const fieldStyle = TextStyle(color: Color(0xFF0F172A));

    void syncNote() {
      final t = noteTitleCtrl.text.trim();
      final b = noteBodyCtrl.text.trim();
      setState(() {
        _customNotes.clear();
        if (t.isNotEmpty || b.isNotEmpty) {
          _customNotes.add(TimemarkNoteItem(title: t, content: b));
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Cepat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Semua kolom opsional dan kosong secara default. Nyalakan tampilannya di Edit Template.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  style: fieldStyle,
                  decoration: deco('Nama', 'Nama Anda'),
                  onChanged: (v) => setState(() {
                    _officerName = v;
                    if (v.trim().isNotEmpty) _showOfficerName = true;
                  }),
                ),
                TextField(
                  controller: compCtrl,
                  style: fieldStyle,
                  decoration: deco('Perusahaan / Tim', 'Nama perusahaan atau tim'),
                  onChanged: (v) => setState(() {
                    _companyName = v;
                    if (v.trim().isNotEmpty) _showCompany = true;
                  }),
                ),
                TextField(
                  controller: roleCtrl,
                  style: fieldStyle,
                  decoration: deco('Jabatan', 'Jabatan atau peran'),
                  onChanged: (v) => setState(() {
                    _businessCardRole = v;
                    if (v.trim().isNotEmpty) _showBusinessCard = true;
                  }),
                ),
                TextField(
                  controller: noteCtrl,
                  style: fieldStyle,
                  decoration: deco('Catatan Singkat', 'Tampil sebagai label'),
                  onChanged: (v) => setState(() {
                    _styledNoteText = v;
                    if (v.trim().isNotEmpty) _showStyledNote = true;
                  }),
                ),
                TextField(
                  controller: tagCtrl,
                  style: fieldStyle,
                  decoration: deco('Tag', '#contoh #tag'),
                  onChanged: (v) => setState(() {
                    _tagText = v;
                    if (v.trim().isNotEmpty) _showTag = true;
                  }),
                ),
                TextField(
                  controller: noteTitleCtrl,
                  style: fieldStyle,
                  decoration: deco('Catatan Kustom: Judul', 'mis. Proyek'),
                  onChanged: (_) {
                    syncNote();
                    setState(() => _showCustomNotes = _customNotes.isNotEmpty);
                  },
                ),
                TextField(
                  controller: noteBodyCtrl,
                  style: fieldStyle,
                  decoration: deco('Catatan Kustom: Isi', 'Isi catatan'),
                  onChanged: (_) {
                    syncNote();
                    setState(() => _showCustomNotes = _customNotes.isNotEmpty);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Selesai'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _logoFile = File(picked.path));
  }

  /// Alamat: ambil ulang dari GPS atau ketik manual bila GPS tidak akurat
  /// (mis. di dalam gedung/basement).
  void _openAddressPickerSheet(BuildContext context) {
    final addrCtrl = TextEditingController(
        text: _addressText.startsWith('Mencari') ? '' : _addressText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lokasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _coordinatesText,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _addressText = 'Mencari lokasi GPS...');
                    _refreshLiveGpsLocation();
                  },
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Ambil ulang dari GPS'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                maxLines: 3,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  labelText: 'Ubah alamat manual (opsional)',
                  hintText: 'Ketik alamat bila GPS kurang akurat',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final v = addrCtrl.text.trim();
                    if (v.isNotEmpty) setState(() => _addressText = v);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Simpan alamat'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Verifikasi LOKAL: mencocokkan kode / berkas foto dengan riwayat foto
  /// yang dibuat aplikasi ini di HP ini. Bukan bukti anti-manipulasi bagi
  /// pihak ketiga (itu butuh server).
  void _openVerifySheet() {
    final codeCtrl = TextEditingController();
    PhotoRecord? result;
    String? message;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> verifyCode() async {
            final r = await PhotoCodeService.findByCode(codeCtrl.text);
            setSheet(() {
              result = r;
              message = r == null
                  ? 'Kode tidak ditemukan di riwayat HP ini.'
                  : null;
            });
          }

          Future<void> verifyFile() async {
            final picked = await _picker.pickImage(source: ImageSource.gallery);
            if (picked == null) return;
            final r = await PhotoCodeService.findByFile(picked.path);
            setSheet(() {
              result = r;
              message = r == null
                  ? 'Foto tidak cocok dengan riwayat HP ini. Foto yang sudah dikirim lewat WhatsApp berubah (dikompres), cek memakai kodenya.'
                  : null;
            });
          }

          final r = result;
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verifikasi Kode Foto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mencocokkan dengan riwayat foto yang dibuat di HP ini saja.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        color: Color(0xFF0F172A), fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Kode Foto (14 karakter)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: verifyCode,
                          child: const Text('Cek kode'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: verifyFile,
                          child: const Text('Pilih foto'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (message != null)
                    Text(message!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFB91C1C))),
                  if (r != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ditemukan di riwayat HP ini',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF065F46))),
                          const SizedBox(height: 6),
                          Text('Kode: ${r.code}',
                              style: const TextStyle(
                                  fontSize: 12, fontFamily: 'monospace')),
                          Text(
                              'Waktu: ${DateFormat('dd MMM yyyy HH:mm:ss', 'id_ID').format(r.capturedAt)}',
                              style: const TextStyle(fontSize: 12)),
                          if (r.latitude != null && r.longitude != null)
                            Text(
                                'Koordinat: ${r.latitude!.toStringAsFixed(6)}, ${r.longitude!.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12)),
                          if (r.address.isNotEmpty)
                            Text('Alamat: ${r.address}',
                                style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }


  void _openTemplateGallerySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemCount: kTimemarkTemplates.length,
          itemBuilder: (_, idx) {
            final tpl = kTimemarkTemplates[idx];
            final active = tpl.id == _activeTemplateId;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _activeTemplateId = tpl.id;
                  _accentColor = tpl.accentColor;
                });
                Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF06B6D4)
                        : const Color(0xFFCBD5E1),
                    width: active ? 2.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tpl.accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tpl.badge,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      tpl.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
