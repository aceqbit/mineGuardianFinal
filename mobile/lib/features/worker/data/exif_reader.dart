import 'dart:typed_data';

import 'package:exif/exif.dart';

/// EXIF DateTimeOriginal ("yyyy:MM:dd HH:mm:ss") is device-local wall time.
/// Returned as a UTC instant assuming the *current* device timezone offset.
Future<DateTime?> readExifTakenAt(Uint8List bytes) async {
  try {
    final tags = await readExifFromBytes(bytes);
    final raw = (tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'])?.printable;
    return parseExifDate(raw);
  } catch (_) {
    return null;
  }
}

DateTime? parseExifDate(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!);
  if (y < 1990) return null;
  final local = DateTime(y, int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!), int.parse(m[5]!), int.parse(m[6]!));
  return local.toUtc();
}
