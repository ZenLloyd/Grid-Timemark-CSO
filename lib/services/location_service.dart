import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationSnapshot {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String addressLine;

  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.addressLine,
  });

  String get coordinatesText =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} (±${accuracy.toStringAsFixed(0)}m)';
}

class LocationService {
  /// Memastikan izin lokasi aktif dan mengambil koordinat GPS + Reverse Geocoding
  static Future<LocationSnapshot> getCurrentLocationSnapshot() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan GPS tidak aktif. Mohon aktifkan lokasi perangkat.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak oleh pengguna.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengaktifkan.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 25),
      ),
    );

    String resolvedAddress = 'Alamat tidak ditemukan';
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String>[
          if (place.street != null && place.street!.trim().isNotEmpty)
            place.street!.trim(),
          if (place.subLocality != null && place.subLocality!.trim().isNotEmpty)
            place.subLocality!.trim(),
          if (place.locality != null && place.locality!.trim().isNotEmpty)
            place.locality!.trim(),
          if (place.subAdministrativeArea != null &&
              place.subAdministrativeArea!.trim().isNotEmpty)
            place.subAdministrativeArea!.trim(),
          if (place.administrativeArea != null &&
              place.administrativeArea!.trim().isNotEmpty)
            place.administrativeArea!.trim(),
        ];

        if (parts.isNotEmpty) {
          resolvedAddress = parts.join(', ');
        }
      }
    } catch (_) {
      resolvedAddress = 'Koordinat berhasil dikunci (Tanpa nama jalan)';
    }

    return LocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      addressLine: resolvedAddress,
    );
  }
}
