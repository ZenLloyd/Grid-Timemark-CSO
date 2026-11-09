import 'package:intl/intl.dart';

class IndonesianDateFormatter {
  /// Contoh output: "Minggu, 08/11/2026 16:17:50 WIB"
  static String formatFullLive(DateTime dateTime) {
    final dayName = DateFormat('EEEE', 'id_ID').format(dateTime);
    final datePart = DateFormat('dd/MM/yyyy HH:mm:ss', 'id_ID').format(dateTime);
    final tzName = _resolveIndonesianTimezone(dateTime.timeZoneOffset);
    return '$dayName, $datePart $tzName';
  }

  /// Contoh output: "08-11-2026"
  static String formatShortDate(DateTime dateTime) {
    return DateFormat('dd-MM-yyyy', 'id_ID').format(dateTime);
  }

  static String _resolveIndonesianTimezone(Duration offset) {
    if (offset.inHours == 7) return 'WIB';
    if (offset.inHours == 8) return 'WITA';
    if (offset.inHours == 9) return 'WIT';
    final sign = offset.isNegative ? '-' : '+';
    return 'UTC$sign${offset.inHours.abs()}';
  }
}
