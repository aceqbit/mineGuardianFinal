// Run: dart run tool/check_images.dart  -> every AppImages URL must return 200 + an image content type.
import 'dart:io';

import 'package:mine_guardian/app/app_images.dart';

Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  var failed = 0;
  for (final e in AppImages.all.entries) {
    try {
      final req = await client.getUrl(Uri.parse(e.value));
      final res = await req.close();
      final type = res.headers.contentType?.mimeType ?? '';
      await res.drain<void>();
      final ok = res.statusCode == 200 && type.startsWith('image/');
      if (!ok) failed++;
      stdout.writeln('${ok ? 'OK  ' : 'FAIL'} ${res.statusCode} $type ${e.key}');
    } catch (err) {
      failed++;
      stdout.writeln('FAIL ERR ${e.key}: $err');
    }
  }
  client.close();
  if (failed > 0) {
    stdout.writeln('$failed image(s) failed - replace those URLs in lib/app/app_images.dart');
    exit(1);
  }
  stdout.writeln('All ${AppImages.all.length} images OK');
}
