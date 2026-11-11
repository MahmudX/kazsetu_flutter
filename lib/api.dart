import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Server origin. Override per build: --dart-define=API_BASE=http://10.0.2.2:5000
const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://kazsetu.com');

/// A relative path from the server (e.g. a legacy /files/... picture) made absolute.
String absUrl(String path) => path.startsWith('http') ? path : '$apiBase$path';

class ApiError implements Exception {
  ApiError(this.status, this.message, [this.body = const {}]);
  final int status; // 0 = no connection
  final String message;
  final Map<String, dynamic> body;

  /// Field errors from a form submit, keyed by camelCase field name.
  Map<String, String> get fields => {
        for (final e in (body['errors'] as List? ?? const []))
          if ((e as Map)['field'] is String && (e['field'] as String).isNotEmpty) e['field'] as String: '${e['message']}',
      };

  @override
  String toString() => message;
}

/// The signed-in person and their tokens. Tokens live only in Android Keystore-backed secure
/// storage, never in plain preferences or logs.
///
/// Two listenables on purpose: [lang] rebuilds the whole app (rare), the session itself only
/// rebuilds the few widgets that show the person, badges or sign-in state (frequent).
class Session extends ChangeNotifier {
  static const _store = FlutterSecureStorage();
  String? _access, _refresh;
  Future<bool>? _refreshing;
  Map<String, dynamic>? me;
  final langNotifier = ValueNotifier('bn');
  String get lang => langNotifier.value;
  set lang(String value) => langNotifier.value = value;

  bool get signedIn => _access != null;
  int get actionCount => (me?['actionCount'] as int?) ?? 0;

  Future<void> load() async {
    try {
      _access = await _store.read(key: 'access');
      _refresh = await _store.read(key: 'refresh');
      lang = await _store.read(key: 'lang') ?? 'bn';
    } catch (_) {
      // A corrupted keystore entry means signing in again, not a crash.
    }
    notifyListeners();
    if (signedIn) unawaited(refreshMe());
  }

  Future<void> setLang(String value) async {
    lang = value;
    await _store.write(key: 'lang', value: value);
    if (signedIn) unawaited(refreshMe());
  }

  Future<void> refreshMe() async {
    try {
      final next = await get('me') as Map<String, dynamic>;
      // Only rebuild listeners when something they show changed.
      if (!mapEquals(next, me)) {
        me = next;
        notifyListeners();
      }
    } on ApiError catch (_) {
      // Offline: keep the last known profile.
    }
  }

  Future<void> login(String login, String password) async {
    _saveTokens(await post('auth/login', {'login': login, 'password': password}));
    await refreshMe();
  }

  Future<void> register(Map<String, Object?> input) async {
    _saveTokens(await post('auth/register', input));
    await refreshMe();
  }

  Future<void> signOut() async {
    _access = _refresh = null;
    me = null;
    notifyListeners();
    await _store.delete(key: 'access');
    await _store.delete(key: 'refresh');
  }

  void _saveTokens(dynamic body) {
    _access = body['accessToken'] as String;
    _refresh = body['refreshToken'] as String;
    _store.write(key: 'access', value: _access);
    _store.write(key: 'refresh', value: _refresh);
    notifyListeners();
  }

  Future<dynamic> get(String path, [Map<String, Object?> query = const {}]) =>
      _send(() => _request('GET', path, query: query), path);

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _request('POST', path, body: body ?? {}), path);

  /// Multipart upload of one file field (credential evidence).
  Future<dynamic> upload(String path, String field, Uint8List bytes, {String filename = 'photo.jpg'}) =>
      _send(() async {
        final request = http.MultipartRequest('POST', _uri(path, const {}))
          ..headers.addAll(_headers(json: false))
          ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
        return http.Response.fromStream(await request.send().timeout(const Duration(seconds: 60)));
      }, path);

  /// Profile and listing photos: declare → PUT the exact bytes to the signed storage URL →
  /// complete. [kind] is 'photos' or 'profile/picture'. Returns the completed JSON.
  Future<Map<String, dynamic>> uploadPhoto(String kind, Uint8List jpeg) async {
    final image = await (await ui.instantiateImageCodec(jpeg)).getNextFrame();
    final ticket = await post('$kind/upload', {
      'contentType': 'image/jpeg',
      'sizeBytes': jpeg.length,
      'md5': base64.encode(md5.convert(jpeg).bytes),
      'width': image.image.width,
      'height': image.image.height,
    }) as Map<String, dynamic>;
    image.image.dispose();
    final put = await http
        .put(Uri.parse(ticket['url'] as String),
            headers: (ticket['headers'] as Map).cast<String, String>(), body: jpeg)
        .timeout(const Duration(seconds: 60));
    if (put.statusCode >= 300) throw ApiError(put.statusCode, lang == 'bn' ? 'আপলোড হয়নি। আবার চেষ্টা করুন।' : 'Upload failed. Try again.');
    return await post('$kind/${ticket['fileId']}/complete') as Map<String, dynamic>;
  }

  Uri _uri(String path, Map<String, Object?> query) {
    final params = {
      for (final e in query.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    return Uri.parse('$apiBase/api/m/$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> _headers({bool json = true}) => {
        'Accept': 'application/json',
        'Accept-Language': lang,
        if (json) 'Content-Type': 'application/json',
        if (_access != null) 'Authorization': 'Bearer $_access',
      };

  Future<http.Response> _request(String method, String path, {Map<String, Object?> query = const {}, Object? body}) {
    final uri = _uri(path, query);
    return (method == 'GET'
            ? http.get(uri, headers: _headers(json: false))
            : http.post(uri, headers: _headers(), body: jsonEncode(body)))
        .timeout(const Duration(seconds: 20));
  }

  /// Sends, refreshes the access token once on 401, and turns errors into [ApiError].
  Future<dynamic> _send(Future<http.Response> Function() send, String path, {bool retried = false}) async {
    http.Response response;
    try {
      response = await send();
    } catch (_) {
      throw ApiError(0, lang == 'bn' ? 'ইন্টারনেট সংযোগ নেই। আবার চেষ্টা করুন।' : 'No connection. Try again.');
    }

    if (response.statusCode == 401 && _refresh != null && !retried && !path.startsWith('auth/')) {
      if (await (_refreshing ??= _tryRefresh().whenComplete(() => _refreshing = null))) {
        return _send(send, path, retried: true);
      }
      await signOut();
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null; // e.g. an HTML error page
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    throw ApiError(
      response.statusCode,
      map['error'] as String? ?? (lang == 'bn' ? 'কিছু একটা ভুল হয়েছে।' : 'Something went wrong.'),
      map,
    );
  }

  Future<bool> _tryRefresh() async {
    try {
      final body = await _send(() => _request('POST', 'auth/refresh', body: {'refreshToken': _refresh}), 'auth/refresh', retried: true);
      _saveTokens(body);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('refresh failed: ${e is ApiError ? e.status : e}');
      return false;
    }
  }
}

final session = Session();
