import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// A 2-second two-tone siren as a 16-bit mono WAV, generated in code so no audio asset has to ship.
Uint8List buildSirenWav({int sampleRate = 8000, double seconds = 2.0}) {
  final n = (sampleRate * seconds).round();
  final data = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final freq = 700 + 400 * (0.5 + 0.5 * math.sin(2 * math.pi * t / seconds * 2)); // sweeps 700..1100 Hz twice
    phase += 2 * math.pi * freq / sampleRate;
    data.setInt16(44 + i * 2, (math.sin(phase) * 0.6 * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

abstract class SirenPlayer {
  Future<void> play();
  Future<void> stop();
}

class _AudioplayersSiren implements SirenPlayer {
  final AudioPlayer _p = AudioPlayer();

  @override
  Future<void> play() async {
    await _p.setReleaseMode(ReleaseMode.loop);
    await _p.play(BytesSource(buildSirenWav(), mimeType: 'audio/wav'));
  }

  @override
  Future<void> stop() => _p.stop();
}

/// Siren with a mute control. When the platform blocks autoplay (web) `blocked` turns true and the UI shows "Tap to enable siren".
class SirenController extends ChangeNotifier {
  SirenController({SirenPlayer? player}) : _player = player ?? _AudioplayersSiren();
  final SirenPlayer _player;
  bool _playing = false, _muted = false, _blocked = false;
  Timer? _autoStop;

  bool get playing => _playing;
  bool get muted => _muted;
  bool get blocked => _blocked;

  Future<void> start({Duration? forAtMost}) async {
    _autoStop?.cancel();
    if (_muted) return;
    try {
      await _player.play();
      _playing = true;
      _blocked = false;
    } catch (_) {
      _playing = false;
      _blocked = true;
    }
    if (forAtMost != null) _autoStop = Timer(forAtMost, stop);
    notifyListeners();
  }

  /// Called from a user tap: browsers allow audio after a gesture.
  Future<void> enable() => start();

  Future<void> stop() async {
    _autoStop?.cancel();
    try {
      await _player.stop();
    } catch (_) {/* nothing playing */}
    _playing = false;
    _blocked = false;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      await stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _autoStop?.cancel();
    super.dispose();
  }
}
