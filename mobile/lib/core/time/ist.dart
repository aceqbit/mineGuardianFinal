import 'package:intl/intl.dart';

import '../../contracts/enums.dart';

/// All times are stored UTC and displayed in Asia/Kolkata (UTC+05:30, no DST).
const Duration istOffset = Duration(hours: 5, minutes: 30);

/// Wall-clock IST for a UTC instant. The returned DateTime is flagged UTC but holds IST wall time.
DateTime toIst(DateTime t) => t.toUtc().add(istOffset);

DateTime nowIst() => toIst(DateTime.now());

String formatIst(DateTime t, {String pattern = 'HH:mm'}) => DateFormat(pattern).format(toIst(t));

String formatIstTime(DateTime t) => '${formatIst(t, pattern: 'HH:mm:ss')} IST';

bool sameIstDay(DateTime a, DateTime b) {
  final x = toIst(a);
  final y = toIst(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

int _minutes(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Whether [istWall] (already IST wall time) is within the shift window. Shift C wraps midnight.
bool isShiftOpen(Shift shift, DateTime istWall, {int toleranceMin = 0}) {
  final now = istWall.hour * 60 + istWall.minute;
  var start = _minutes(shift.start) - toleranceMin;
  var end = _minutes(shift.end) + toleranceMin;
  if (shift.end == '06:00' && shift.start == '22:00') {
    start = (start + 1440) % 1440;
    end = (end + 1440) % 1440;
    return now >= start || now < end;
  }
  return now >= start && now < end;
}

String relativeTime(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).toUtc().difference(t.toUtc());
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return DateFormat('d MMM, HH:mm').format(toIst(t));
}
