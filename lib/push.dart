import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'screens/chat.dart';

/// Root navigator, so a tapped notification can open its screen from anywhere.
final navigatorKey = GlobalKey<NavigatorState>();

/// The latest push that arrived while the app was open. Open threads and the inbox listen and
/// refresh at once instead of waiting for their next poll.
final incomingPush = ValueNotifier<RemoteMessage?>(null);

/// MainActivity: the in-app tone, and the chat notifications the app draws (ChatNotifications.kt).
const _native = MethodChannel('kazsetu/sound');

/// The Android app draws its own chat notifications (the sender's photo, one conversation per
/// person), so the server sends it data-only pushes. Elsewhere the server's notification is shown.
bool get _drawsNotifications => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// WhatsApp-style delivery: when the app is closed a notification with the sender's photo is shown;
/// when it is open nothing is shown, a short in-app tone plays and the badges refresh.
void initPush() {
  final messaging = FirebaseMessaging.instance;

  FirebaseMessaging.onMessage.listen((message) {
    _native.invokeMethod('incoming').ignore();
    session.clearCache(); // a push means something changed on the server: an offer, an applicant
    incomingPush.value = message;
    unawaited(session.refreshMe());
  });

  // Notifications Android drew from the server's payload (older-style pushes).
  FirebaseMessaging.onMessageOpenedApp.listen(_open);
  messaging.getInitialMessage().then((m) {
    if (m != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(m));
  });

  // Notifications the app drew: the sender's photo comes from the server, and a tap opens the chat
  // whether the app was running or closed.
  if (_drawsNotifications) {
    _native.invokeMethod('setApiBase', apiBase).ignore();
    _native.setMethodCallHandler((call) async {
      if (call.method == 'openChat') _openChat('${call.arguments}');
    });
    _native.invokeMethod<String>('launchChat').then((userId) {
      if (userId != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openChat(userId));
    }).ignore();
  }

  // Register this phone for whoever is signed in, now and after every sign-in or token rotation.
  // Signing out deletes the token (Session.signOut), so the old account stops getting pushes.
  Future<void> register([String? token]) async {
    if (!session.signedIn) return;
    try {
      await messaging.requestPermission(); // Android 13+ asks once; later calls are no-ops
      // ponytail: registration tokens, deprecated in favour of installation IDs (register() /
      // onRegistered); move when the server's FirebaseAdmin .NET SDK can send to those.
      // ignore: deprecated_member_use
      token ??= await messaging.getToken();
      if (token != null) {
        await session.post('push/token', {'token': token, 'drawsNotifications': _drawsNotifications});
      }
    } catch (_) {
      // Offline or no Play services: the next sign-in or app start retries.
    }
  }

  session.signedInNotifier.addListener(() => register());
  // ignore: deprecated_member_use
  messaging.onTokenRefresh.listen(register);
  register();
}

void _open(RemoteMessage message) {
  final userId = message.data['userId'];
  if (message.data['type'] == 'chat' && userId is String) _openChat(userId);
}

void _openChat(String userId) {
  if (session.signedIn) {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatThread(otherUserId: userId)));
  }
}
