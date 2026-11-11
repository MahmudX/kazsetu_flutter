import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import 'chat.dart';
import 'find_work.dart';
import 'gigs.dart';
import 'report.dart';

/// A public profile: who they are, separate worker and poster records, and what they offer.
class Person extends StatefulWidget {
  const Person({super.key, required this.keyOrHandle});
  final String keyOrHandle;
  @override
  State<Person> createState() => _PersonState();
}

class _PersonState extends State<Person> {
  String? _tab;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Loader(
          key: ValueKey(_tab),
          load: () => session.get('people/${Uri.encodeComponent(widget.keyOrHandle)}', {'tab': _tab}),
          builder: (context, p, _) => _body(context, p as Map),
        ),
      );

  Widget _body(BuildContext context, Map p) {
    final theme = Theme.of(context);
    final mine = p['userId'] == session.me?['id'];
    final selected = '${p['selectedTab']}';
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ]),
        );
    String rating(Object? r, Object? n) => r == null ? '—' : '★ ${digits((r as num).toStringAsFixed(1))}';
    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: true,
        expandedHeight: 280,
        backgroundColor: K.deep,
        foregroundColor: Colors.white,
        actions: [
          if (!mine)
            IconButton(
              tooltip: t('Report a problem'),
              icon: const Icon(FluentIcons.flag_24_regular),
              onPressed: () => showReportSheet(context, subjectUserId: '${p['userId']}'),
            ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: DecoratedBox(
            decoration: const BoxDecoration(gradient: K.brandGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                child: Column(children: [
                  Avatar(name: '${p['displayName']}', url: p['pictureUrl'] as String?, size: 76),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: Text('${p['displayName']}', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis)),
                    if ((p['verified'] as List?)?.isNotEmpty == true) ...[
                      const SizedBox(width: 6),
                      const Icon(FluentIcons.shield_checkmark_24_filled, color: Colors.white, size: 20),
                    ],
                  ]),
                  if (name(p, 'area').isNotEmpty) Text(name(p, 'area'), style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  Row(children: [
                    stat(digits(p['completedAsWorker'] ?? 0), t('done as worker')),
                    stat(rating(p['workerRating'], p['workerReviewCount']), t('as worker')),
                    stat(digits(p['completedAsPoster'] ?? 0), t('done as poster')),
                    stat(rating(p['posterRating'], p['posterReviewCount']), t('as poster')),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        sliver: SliverList.list(children: [
          if (!mine)
            FilledButton.icon(
              onPressed: () async {
                if (await requireSignIn(context) && context.mounted) {
                  await push(context, ChatThread(otherUserId: '${p['userId']}'));
                }
              },
              icon: const Icon(FluentIcons.chat_24_regular),
              label: Text(t('Message')),
            ),
          if ('${p['introduction']}'.isNotEmpty) ...[SectionTitle(t('About')), Text('${p['introduction']}')],
          if ('${p['availability']}'.isNotEmpty) ...[SectionTitle(t('Availability')), Text('${p['availability']}')],
          if ((p['capabilities'] as List?)?.isNotEmpty == true) ...[
            SectionTitle(t('Can do')),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final c in p['capabilities'] as List) Pill('$c', color: theme.colorScheme.primary)]),
          ],
          const SizedBox(height: 16),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'WorkPosts', label: Text(t('Posts'))),
              ButtonSegment(value: 'WorkHistory', label: Text(t('History'))),
              ButtonSegment(value: 'Gigs', label: Text(t('Talents'))),
            ],
            selected: {selected},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 12),
        ]),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList.list(children: [
          if (selected == 'WorkPosts')
            for (final j in (p['workPosts'] as List).cast<Map<String, dynamic>>())
              Padding(padding: const EdgeInsets.only(bottom: 12), child: JobCard(job: j)),
          if (selected == 'Gigs')
            for (final g in (p['gigs'] as List).cast<Map<String, dynamic>>())
              Padding(padding: const EdgeInsets.only(bottom: 12), child: GigCard(gig: g)),
          if (selected == 'WorkHistory')
            for (final h in (p['workHistory'] as List).cast<Map>())
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(h['status'] == 'Completed' ? FluentIcons.checkmark_circle_24_filled : FluentIcons.clock_24_regular,
                      color: h['status'] == 'Completed' ? K.success : null),
                  title: Text('${h['title']}'),
                  subtitle: Text([
                    h['asPoster'] == true ? t('as poster') : t('as worker'),
                    if (h['receivedRating'] != null) '★' * (h['receivedRating'] as int),
                    if ('${h['receivedReview']}'.isNotEmpty) '“${h['receivedReview']}”',
                  ].join(' · ')),
                ),
              ),
          if ((selected == 'WorkPosts' && (p['workPosts'] as List).isEmpty) ||
              (selected == 'Gigs' && (p['gigs'] as List).isEmpty) ||
              (selected == 'WorkHistory' && (p['workHistory'] as List).isEmpty))
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('Nothing here yet')))),
        ]),
      ),
    ]);
  }
}
