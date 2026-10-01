import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// Asks for notification permission, uploads the FCM token and follows refreshes.
/// Never blocks or fails login: every error is swallowed.
class PushRegistrar {
  PushRegistrar({required ApiClient api}) : _api = api;
  final ApiClient _api;
  StreamSubscription<String>? _refreshSub;

  Future<void> register() async {
    if (kIsWeb) return; // web push needs a service worker + VAPID key; not part of this build
    try {
      final fm = FirebaseMessaging.instance;
      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await fm.getToken();
      if (token != null) await _send(token);
      await _refreshSub?.cancel();
      _refreshSub = fm.onTokenRefresh.listen(_send);
    } catch (_) {/* never block login */}
  }

  Future<void> _send(String token) async {
    try {
      await _api.putJson('/api/users/me/fcm-token', body: {'token': token});
    } catch (_) {}
  }

  Future<void> dispose() async => _refreshSub?.cancel();
}
