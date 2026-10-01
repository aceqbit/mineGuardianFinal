// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import '../../config.dart';

class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.statusCode, this.details});
  final String code;
  final String message;
  final int? statusCode;
  final dynamic details;

  bool get isNetwork => code == 'NETWORK';

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

typedef TokenProvider = Future<String?> Function({bool forceRefresh});

/// Dio wrapper: bearer interceptor, 401 -> one forced refresh retry, error JSON -> [ApiException].
class ApiClient {
  ApiClient({required TokenProvider tokenProvider, String? baseUrl, Dio? dio})
      : _tokenProvider = tokenProvider,
        dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              headers: {'Accept': 'application/json'},
            )) {
    this.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra['noAuth'] != true) {
          final token = await _tokenProvider(forceRefresh: false);
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final req = e.requestOptions;
        if (e.response?.statusCode == 401 && req.extra['retried'] != true && req.extra['noAuth'] != true) {
          try {
            final fresh = await _tokenProvider(forceRefresh: true);
            if (fresh != null) {
              req.extra['retried'] = true;
              req.headers['Authorization'] = 'Bearer $fresh';
              final res = await this.dio.fetch<dynamic>(req);
              return handler.resolve(res);
            }
          } catch (_) {}
        }
        handler.next(e);
      },
    ));
  }

  final Dio dio;
  final TokenProvider _tokenProvider;

  ApiException _map(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: (err['code'] ?? 'UNKNOWN').toString(),
        message: (err['message'] ?? 'Request failed').toString(),
        statusCode: e.response?.statusCode,
        details: err['details'],
      );
    }
    if (e.response == null) {
      return ApiException(code: 'NETWORK', message: 'No connection — check your internet');
    }
    return ApiException(code: 'HTTP_${e.response!.statusCode}', message: 'Request failed', statusCode: e.response!.statusCode);
  }

  Future<T> _run<T>(Future<Response<dynamic>> Function() call, T Function(dynamic data) parse) async {
    try {
      final res = await call();
      return parse(res.data);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query, Options? options}) =>
      _run(() => dio.get<dynamic>(path, queryParameters: query, options: options), (d) => (d as Map).cast<String, dynamic>());

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) =>
      _run(() => dio.get<dynamic>(path, queryParameters: query), (d) => d as List<dynamic>);

  Future<Map<String, dynamic>> postJson(String path, {Object? body, Map<String, dynamic>? query}) =>
      _run(() => dio.post<dynamic>(path, data: body, queryParameters: query), (d) => (d as Map?)?.cast<String, dynamic>() ?? {});

  Future<Map<String, dynamic>> putJson(String path, {Object? body}) =>
      _run(() => dio.put<dynamic>(path, data: body), (d) => (d as Map?)?.cast<String, dynamic>() ?? {});

  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) =>
      _run(() => dio.patch<dynamic>(path, data: body), (d) => (d as Map?)?.cast<String, dynamic>() ?? {});

  Future<Map<String, dynamic>> postMultipart(String path, FormData form, {void Function(int sent, int total)? onProgress}) =>
      _run(() => dio.post<dynamic>(path, data: form, onSendProgress: onProgress), (d) => (d as Map?)?.cast<String, dynamic>() ?? {});

  /// Reachability probe used by the sync engine (3 s timeout, no auth).
  Future<bool> health() async {
    try {
      final res = await dio.get<dynamic>('/api/health',
          options: Options(sendTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 3), extra: {'noAuth': true}));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
