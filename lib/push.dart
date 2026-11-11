import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'screens/chat.dart';

/// Root navigator, so a tapped notification can open its screen from anywhere.
final navigatorKey = GlobalKey<NavigatorState>();

/// The latest push that arrived while the app was open. Open threads and the inbox listen and
/// refresh at once instead of waiting for their next poll.
final incomingPush = ValueNotifier<RemoteMessage?>(null);

const _sound = MethodChannel('kazsetu/sound');

/// WhatsApp-style delivery: when the app is closed Android shows the server's notification; when it
/// is open nothing is shown, a short in-app tone plays and the badges refresh.
void initPush() {
  final messaging = FirebaseMessaging.instance;

  FirebaseMessaging.onMessage.listen((message) {
    _sound.invokeMethod('incoming').ignore();
    incomingPush.value = message;
    unawaited(session.refreshMe());
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_open);
  messaging.getInitialMessage().then((m) {
    if (m != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(m));
  });

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
      if (token != null) await session.post('push/token', {'token': token});
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
  if (message.data['type'] == 'chat' && userId is String && session.signedIn) {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatThread(otherUserId: userId)));
  }
}
