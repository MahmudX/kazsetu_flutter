import 'package:flutter/widgets.dart';

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

/// Opens a server path (inbox deep links, chat topics) in the matching screen, or the website for
/// anything the app does not show.
Future<void> openLink(BuildContext context, String path) async {
  for (final (pattern, page) in _routes) {
    final m = pattern.firstMatch(path);
    if (m != null) {
      await push(context, page(m));
      return;
    }
  }
  await openWeb(path);
}
