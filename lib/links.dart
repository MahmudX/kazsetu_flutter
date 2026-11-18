import 'package:flutter/material.dart';

import 'api.dart';
import 'push.dart';
import 'screens/candidates.dart';
import 'screens/chat.dart';
import 'screens/engagement.dart';
import 'screens/gigs.dart';
import 'screens/job_detail.dart';
import 'screens/job_editor.dart';
import 'screens/my_work.dart';
import 'screens/person.dart';
import 'ui.dart';

const _id = r'([0-9a-fA-F-]{36})';
final _routes = <(RegExp, Widget Function(Match))>[
  (RegExp('^/applications/$_id'), (m) => ApplicationDetail(id: m[1]!)),
  (RegExp('^/tasks/$_id/applications'), (m) => Candidates(jobId: m[1]!)),
  (RegExp('^/tasks/$_id/edit'), (m) => JobEditor(jobId: m[1]!)),
  (RegExp('^/tasks/$_id(?:/|\$|\\?)'), (m) => JobDetail(id: m[1]!)),
  (RegExp('^/engagements/$_id'), (m) => EngagementDetail(id: m[1]!)),
  (RegExp('^/gigs/$_id(?:/|\$|\\?)'), (m) => GigDetail(id: m[1]!)),
  (RegExp(r'^/people/([^/?#]+)'), (m) => Person(keyOrHandle: Uri.decodeComponent(m[1]!))),
  (RegExp(r'^/chat/([^/?#]+)'), (m) => ChatThread(otherUserId: Uri.decodeComponent(m[1]!))),
];

Widget? _screen(String path) {
  for (final (pattern, page) in _routes) {
    final m = pattern.firstMatch(path);
    if (m != null) return page(m);
  }
  return null;
}

/// Opens a server path (inbox deep links, chat topics) in the matching screen, or the website for
/// anything the app does not show.
Future<void> openLink(BuildContext context, String path) async {
  final screen = _screen(path);
  screen == null ? await openWeb(path) : await push(context, screen);
}

/// Android App Links: a tapped `kazsetu.com/tasks/{id}` or `/gigs/{id}/{slug}` link opens here
/// instead of the browser (intent filter in AndroidManifest.xml, verified by the website's
/// /.well-known/assetlinks.json).
///
/// A link tapped while signed out: the app is for members only, so it opens after sign-in.
String? _pending;

/// The screen for a link's path, or null when the app does not show it or nobody is signed in yet.
Route<void>? linkRoute(String path) {
  final screen = _screen(path);
  if (screen == null) return null;
  if (!session.signedIn) {
    _pending = path;
    return null;
  }
  return MaterialPageRoute(builder: (_) => screen);
}

/// Links tapped while the app is running. Registered before runApp so it runs ahead of
/// MaterialApp's own handler, which would pushNamed the path and fail on anything unknown.
/// Cold starts arrive as the platform's initial route instead (initLinks).
class _Links with WidgetsBindingObserver {
  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async {
    final route = linkRoute(info.uri.path);
    if (route != null) navigatorKey.currentState?.push(route);
    return true;
  }
}

void initLinks() {
  WidgetsBinding.instance.addObserver(_Links());
  // Cold start from a tapped link: the listing goes on top of home once the first frame is up.
  final initial = Uri.parse(WidgetsBinding.instance.platformDispatcher.defaultRouteName).path;
  if (initial != '/') {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = linkRoute(initial);
      if (route != null) navigatorKey.currentState?.push(route);
    });
  }
  session.signedInNotifier.addListener(() {
    final path = _pending;
    if (!session.signedIn || path == null) return;
    _pending = null;
    // After the frame that swaps sign-in for the home screen, so the listing lands on top of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = linkRoute(path);
      if (route != null) navigatorKey.currentState?.push(route);
    });
  });
}
