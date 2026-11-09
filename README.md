# Aplikasi Grid & TimeMark

Aplikasi mobile cross-platform (Android & iOS) berbasis Flutter untuk kebutuhan dokumentasi & laporan kerja profesional:
1. **Grid Master (Kolase Foto):** Pilih 1 hingga 20 foto dari galeri dengan tata letak dinamis (`flutter_staggered_grid_view`), pengaturan margin, border radius, warna latar, serta ekspor resolusi tinggi ke galeri.
2. **Report Camera (Timemark):** Kamera real-time dengan stempel waktu standar Indonesia (`id_ID` — Hari, `dd/MM/yyyy HH:mm:ss` WIB/WITA/WIT), titik koordinat GPS akurat (`geolocator`), nama jalan/wilayah (`geocoding`), serta judul proyek/petugas kustom.

## Struktur Folder Proyek

```text
Aplikasi Grid & TimeMark/
├── android/
│   └── app/src/main/AndroidManifest.xml  # Konfigurasi permission Kamera, GPS, & Galeri Android
├── ios/
│   └── Runner/Info.plist                 # Konfigurasi permission Kamera, GPS, & Galeri iOS
├── lib/
│   ├── main.dart                         # Entry point & inisialisasi locale 'id_ID' + kamera
│   ├── screens/
│   │   ├── home_screen.dart              # Menu utama (Grid Master & Report Camera)
│   │   ├── grid_screen.dart              # Fitur A: Kolase 1-20 foto dinamis & ekspor galeri
│   │   └── camera_stamp_screen.dart      # Fitur B: Kamera real-time watermark GPS & Waktu ID
│   ├── services/
│   │   ├── image_export_service.dart     # Render RepaintBoundary ke PNG HD & simpan via Gal
│   │   └── location_service.dart         # GPS Geolocator & Reverse Geocoding nama jalan
│   └── utils/
│       └── date_formatter.dart           # Formatter waktu & zona waktu Indonesia (WIB/WITA/WIT)
└── pubspec.yaml                          # Daftar dependencies Flutter
```

## Cara Menjalankan Proyek

1. Pastikan Flutter SDK sudah terinstal di komputer Anda.
2. Buka terminal di dalam folder `Aplikasi Grid & TimeMark`:
   ```bash
   flutter create . --project-name grid_and_timemark
   flutter pub get
   flutter run
   ```
   *(Catatan: Perintah `flutter create .` akan melengkapi file boilerplate native gradle/xcode tanpa menimpa kode di `lib/`).*
