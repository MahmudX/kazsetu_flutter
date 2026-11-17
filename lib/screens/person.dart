import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import 'chat.dart';
import 'find_work.dart';
import 'gigs.dart';
import 'job_detail.dart';
import 'report.dart';

/// The server's selectedTab names and the ?tab= values it accepts (PublicProfileViewModel.ResolveTab).
const _tabParam = {'WorkPosts': 'work', 'WorkHistory': 'history', 'Gigs': 'gigs'};

/// A public profile, laid out like the web's /people page: who they are, separate worker and
/// poster records, and their tasks, history and gigs.
class Person extends StatefulWidget {
  const Person({super.key, required this.keyOrHandle});
  final String keyOrHandle;
  @override
  State<Person> createState() => _PersonState();
}

class _PersonState extends State<Person> {
  Map? _p; // the profile on screen; the header stays while another tab loads
  String? _loading; // the tab being fetched
  // The server sends one tab's list per request, so each tab is fetched once and kept: switching
  // back is instant. Leaving and reopening the profile fetches fresh.
  final _byTab = <String, Map>{};

  Future<Map> _fetch(String? tab) async {
    final p = await session.get('people/${Uri.encodeComponent(widget.keyOrHandle)}', {'tab': tab}) as Map;
    _byTab[_tabParam['${p['selectedTab']}'] ?? 'history'] = p;
    return p;
  }

  Future<void> _select(String tab) async {
    if (_byTab[tab] case final cached?) {
      setState(() => _p = cached);
      return;
    }
    setState(() => _loading = tab);
    try {
      final p = await _fetch(tab);
      if (mounted) setState(() => _p = p);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Loader(
          load: () => _fetch(null),
          builder: (context, p, _) => _body(context, _p ?? p as Map),
        ),
      );

  Widget _body(BuildContext context, Map p) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = p['userId'] == session.me?['id'];
    final shown = _tabParam['${p['selectedTab']}'] ?? 'history';
    final selected = _loading ?? shown;
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          ]),
        );
    // Only figures that say something: no "0" counts and no "—" for a rating nobody has given.
    int count(Object? n) => (n as num?)?.toInt() ?? 0;
    final stats = [
      if (count(p['completedAsWorker']) > 0) stat(digits(count(p['completedAsWorker'])), t('done as worker')),
      if (p['workerRating'] case final num r) stat('★ ${digits(r.toStringAsFixed(1))}', t('as worker')),
      if (count(p['completedAsPoster']) > 0) stat(digits(count(p['completedAsPoster'])), t('done as poster')),
      if (p['posterRating'] case final num r) stat('★ ${digits(r.toStringAsFixed(1))}', t('as poster')),
    ];
    Widget tab(String value, String label) {
      final on = value == selected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? scheme.surface : Colors.transparent,
            elevation: on ? 1 : 0,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: on ? null : () => _select(value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                    )),
              ),
            ),
          ),
        ),
      );
    }

    final List items = switch (shown) {
      'work' => p['workPosts'] as List,
      'gigs' => p['gigs'] as List,
      _ => p['workHistory'] as List,
    };
    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: true,
        actions: [
          if (!mine)
            IconButton(
              tooltip: t('Report a problem'),
              icon: const Icon(FluentIcons.flag_24_regular),
              onPressed: () => showReportSheet(context, subjectUserId: '${p['userId']}'),
            ),
        ],
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        sliver: SliverList.list(children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Avatar(name: '${p['displayName']}', url: p['pictureUrl'] as String?, size: 72),
                const SizedBox(height: 12),
                Text(t('Public profile'), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                Row(children: [
                  Flexible(
                    child: Text('${p['displayName']}',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  ),
                  VerifiedBadge(p['verified'] as List?, size: 20),
                ]),
                if (name(p, 'area').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(spacing: 6, children: [
                      Icon(FluentIcons.location_24_regular, size: 18, color: scheme.onSurfaceVariant),
                      Flexible(child: Text(name(p, 'area'), style: TextStyle(color: scheme.onSurfaceVariant))),
                    ]),
                  ),
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: stats),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
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
            Wrap(spacing: 6, runSpacing: 6, children: [for (final c in p['capabilities'] as List) Pill('$c', color: scheme.primary)]),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [tab('work', t('Tasks')), tab('history', t('Reviews')), tab('gigs', t('Gigs'))]),
          ),
          const SizedBox(height: 12),
        ]),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList.list(children: [
          if (_loading != null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('Nothing here yet'))))
          else if (shown == 'work')
            for (final j in items.cast<Map<String, dynamic>>())
              Padding(padding: const EdgeInsets.only(bottom: 12), child: JobCard(job: j))
          else if (shown == 'gigs')
            for (final g in items.cast<Map<String, dynamic>>())
              Padding(padding: const EdgeInsets.only(bottom: 12), child: GigCard(gig: g))
          else
            for (final h in items.cast<Map>()) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReviewCard(h)),
        ]),
      ),
    ]);
  }
}

/// One finished task or gig order and the review this person received for it: stars and their
/// words first, then what the work was. Mirrors the web's _TaskHistoryCard.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard(this.h);
  final Map h;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rating = h['receivedRating'] as int?;
    final review = '${h['receivedReview'] ?? ''}'.trim();
    final completed = h['status'] == 'Completed';
    final id = '${h['taskId']}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => push(context, h['isGigOrder'] == true ? GigDetail(id: id) : JobDetail(id: id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (rating != null) ...[
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  Icon(i <= rating ? FluentIcons.star_24_filled : FluentIcons.star_24_regular,
                      size: 18, color: i <= rating ? K.warning : scheme.outline),
                const SizedBox(width: 6),
                Text(digits('$rating.0'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              if (review.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('“$review”', style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
                ),
            ] else
              Text(t('No published review received.'), style: TextStyle(color: scheme.onSurfaceVariant)),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: scheme.outlineVariant)),
            Text('${h['title']}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pill(completed ? t('Completed') : t('Expired'), color: completed ? K.success : scheme.onSurfaceVariant),
              Pill(h['asPoster'] == true ? t('as poster') : t('as worker')),
              if (h['endsAt'] != null) Text(date(h['endsAt'], time: false), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
            ]),
          ]),
        ),
      ),
    );
  }
}
