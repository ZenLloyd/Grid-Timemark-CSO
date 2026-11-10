import 'package:flutter_test/flutter_test.dart';
import 'package:grid_and_timemark/services/photo_code_service.dart';

void main() {
  test('Kode Foto: 14 karakter, alfabet aman, unik per foto', () {
    final seen = <String>{};
    for (var i = 0; i < 2000; i++) {
      final code = PhotoCodeService.generateCode();
      expect(code.length, 14);
      expect(RegExp(r'^[A-HJ-NP-Z2-9]{14}$').hasMatch(code), isTrue);
      seen.add(code);
    }
    expect(seen.length, 2000);
  });

  test('PhotoRecord bisa diserialisasi bolak-balik', () {
    final r = PhotoRecord(
      code: 'ABCDEFGHJKLMNP',
      capturedAt: DateTime.utc(2026, 11, 10, 15, 0, 0),
      latitude: -6.2,
      longitude: 106.8,
      address: 'Alamat uji',
      fileSha256: 'abc',
    );
    final back = PhotoRecord.fromJson(r.toJson());
    expect(back.code, r.code);
    expect(back.capturedAt, r.capturedAt);
    expect(back.latitude, r.latitude);
    expect(back.address, 'Alamat uji');
    expect(back.fileSha256, 'abc');
  });
}
