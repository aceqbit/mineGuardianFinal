// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:rxdart/rxdart.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config.dart';
import '../api/api_client.dart';

/// Socket.io client. Every payload is an envelope { v, id, ts, data }; [on] dedupes by id (500-entry LRU).
class SocketService {
  SocketService({required TokenProvider tokenProvider, String? url})
      : _tokenProvider = tokenProvider,
        _url = url ?? socketUrl;

  final TokenProvider _tokenProvider;
  final String _url;
  io.Socket? _socket;
  final _connection = BehaviorSubject<bool>.seeded(false);
  final _seen = <String>{};
  final _controllers = <String, StreamController<SocketEnvelope>>{};

  Stream<bool> get connection$ => _connection.stream;
  bool get isConnected => _connection.value;

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _tokenProvider(forceRefresh: false);
    final s = io.io(
      _url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .disableAutoConnect()
          .build(),
    );
    s.onConnect((_) => _connection.add(true));
    s.onDisconnect((_) => _connection.add(false));
    s.onConnectError((_) => _connection.add(false));
    // Fresh token before every reconnect attempt.
    s.io.on('reconnect_attempt', (_) async {
      final fresh = await _tokenProvider(forceRefresh: true);
      s.auth = {'token': fresh};
    });
    _socket = s;
    for (final name in _controllers.keys) {
      _bind(name);
    }
    s.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connection.add(false);
  }

  void _bind(String event) {
    _socket?.off(event);
    _socket?.on(event, (raw) {
      final env = SocketEnvelope.tryParse(raw);
      if (env == null) return;
      if (!_remember(env.id)) return;
      _controllers[event]?.add(env);
    });
  }

  bool _remember(String id) {
    if (_seen.contains(id)) return false;
    _seen.add(id);
    if (_seen.length > 500) _seen.remove(_seen.first);
    return true;
  }

  /// Stream of deduped envelopes for [event].
  Stream<SocketEnvelope> on(String event) {
    final c = _controllers.putIfAbsent(event, () {
      final ctrl = StreamController<SocketEnvelope>.broadcast();
      return ctrl;
    });
    _bind(event);
    return c.stream;
  }

  /// Pushes a server event into the stream as if it arrived over the socket. Tests only.
  @visibleForTesting
  void inject(String event, Map<String, dynamic> data, {String? id}) {
    final env = SocketEnvelope(id: id ?? 't-${DateTime.now().microsecondsSinceEpoch}-$event', ts: DateTime.now().toUtc(), data: data);
    if (_remember(env.id)) _controllers[event]?.add(env);
  }

  /// Emit a client event wrapped in the envelope; completes with the ack payload (or null on timeout).
  Future<Map<String, dynamic>?> emit(String event, Map<String, dynamic> data, {Duration timeout = const Duration(seconds: 5)}) {
    final s = _socket;
    final done = Completer<Map<String, dynamic>?>();
    if (s == null || !s.connected) {
      done.complete(null);
      return done.future;
    }
    final env = {'v': 1, 'id': '${DateTime.now().microsecondsSinceEpoch}-$event', 'ts': DateTime.now().toUtc().toIso8601String(), 'data': data};
    s.emitWithAck(event, env, ack: (res) {
      if (!done.isCompleted) done.complete(res is Map ? res.cast<String, dynamic>() : null);
    });
    return done.future.timeout(timeout, onTimeout: () => null);
  }

  Future<void> dispose() async {
    disconnect();
    for (final c in _controllers.values) {
      await c.close();
    }
    await _connection.close();
  }
}

class SocketEnvelope {
  SocketEnvelope({required this.id, required this.ts, required this.data});
  final String id;
  final DateTime ts;
  final Map<String, dynamic> data;

  static SocketEnvelope? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final d = raw['data'];
    if (id is! String || d is! Map) return null;
    return SocketEnvelope(
      id: id,
      ts: DateTime.tryParse(raw['ts']?.toString() ?? '') ?? DateTime.now().toUtc(),
      data: d.cast<String, dynamic>(),
    );
  }
}
