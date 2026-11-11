import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import 'candidates.dart';
import 'engagement.dart';
import 'gigs.dart';
import 'job_detail.dart';
import 'job_editor.dart';
import 'my_work.dart';
import 'todo.dart';

/// Everything the person is part of, as worker and as poster. "To do" first: it is the durable
/// action inbox (PRD 20A).
class Activity extends StatelessWidget {
  const Activity({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (!session.signedIn) {
            return Scaffold(
              appBar: AppBar(title: Text(t('Activity'))),
              body: const SignInPrompt(icon: FluentIcons.task_list_square_ltr_24_regular),
            );
          }
          return DefaultTabController(
            key: const ValueKey('signed-in'),
            length: 5,
            child: Scaffold(
              appBar: AppBar(
                title: Text(t('Activity')),
                bottom: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                      Text(t('To do')),
                      if (session.actionCount > 0)
                        Badge(label: Text(digits(session.actionCount)), backgroundColor: Theme.of(context).colorScheme.tertiary),
                    ])),
                    Tab(text: t('Applications')),
                    Tab(text: t('My posts')),
                    Tab(text: t('Agreements')),
                    Tab(text: t('My talents')),
                  ],
                ),
              ),
              body: TabBarView(children: [
                const _Keep(child: Todo()),
                _Keep(child: MyWork(onBrowse: () => DefaultTabController.of(context).animateTo(0))),
                const _Keep(child: _Posts()),
                const _Keep(child: _Agreements()),
                const _Keep(child: _Talents()),
              ]),
            ),
          );
        },
      );
}

/// Keeps a tab's list and scroll position when swiping between tabs.
class _Keep extends StatefulWidget {
  const _Keep({required this.child});
  final Widget child;
  @override
  State<_Keep> createState() => _KeepState();
}

class _KeepState extends State<_Keep> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

Widget _list(BuildContext context, List items, Future<void> Function() reload, Widget Function(Map) tile, Widget empty) =>
    RefreshIndicator(
      onRefresh: reload,
      child: items.isEmpty
          ? ListView(children: [SizedBox(height: 440, child: empty)])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => Entrance(index: i, id: 'act-${items[i]['id']}', child: tile(items[i] as Map)),
            ),
    );

class _Posts extends StatefulWidget {
  const _Posts();
  @override
  State<_Posts> createState() => _PostsState();
}

class _PostsState extends State<_Posts> {
  final _loader = GlobalKey<LoaderState>();

  (String, Color) _state(BuildContext context, Map p) {
    final s = Theme.of(context).colorScheme;
    return switch ('${p['moderation']}') {
      'Draft' => (t('Draft'), s.onSurfaceVariant),
      'PendingReview' => (t('In review'), K.warning),
      'ChangesRequested' => (t('Changes requested'), s.tertiary),
      'Rejected' || 'Suspended' => (t('Not published'), s.error),
      _ => p['intake'] == 'Open' ? (t('Live'), K.success) : (t('${p['intake']}'), s.onSurfaceVariant),
    };
  }

  @override
  Widget build(BuildContext context) => Loader(
        key: _loader,
        load: () => session.get('my/posts'),
        builder: (context, data, reload) => _list(
          context,
          data as List,
          reload,
          (p) {
            final (label, color) = _state(context, p);
            final applicants = p['activeApplicants'] as int? ?? 0;
            return Pressable(
              label: '${p['title']}',
              onTap: () => _open(p),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
                    Text('${p['title']}'.isEmpty ? t('Untitled draft') : '${p['title']}', style: Theme.of(context).textTheme.titleMedium),
                    Row(spacing: 8, children: [
                      Pill(label, color: color),
                      if (applicants > 0) Pill('${digits(applicants)} ${t('applicants')}', color: Theme.of(context).colorScheme.tertiary, icon: FluentIcons.people_24_filled),
                      const Spacer(),
                      Text(relative(p['updatedAt']), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]),
                    if (p['moderation'] == 'ChangesRequested' && p['moderationReason'] != null) Text('“${p['moderationReason']}”'),
                  ]),
                ),
              ),
            );
          },
          Message(
            icon: FluentIcons.briefcase_24_regular,
            title: t('No posts yet'),
            body: t('No posts body'),
            action: t('Post work'),
            onAction: () => _edit(null),
          ),
        ),
      );

  Future<void> _edit(String? id) async {
    await push(context, JobEditor(jobId: id));
    _loader.currentState?.reload();
  }

  Future<void> _open(Map p) async {
    final id = '${p['id']}';
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (p['isPublished'] == true)
            ListTile(leading: const Icon(FluentIcons.people_24_regular), title: Text(t('See applicants')), onTap: () => Navigator.pop(context, 'candidates')),
          if (p['isEditable'] == true)
            ListTile(leading: const Icon(FluentIcons.edit_24_regular), title: Text(t('Edit post')), onTap: () => Navigator.pop(context, 'edit')),
          if (p['isPublished'] == true)
            ListTile(leading: const Icon(FluentIcons.eye_24_regular), title: Text(t('View public page')), onTap: () => Navigator.pop(context, 'view')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'candidates':
        await push(context, Candidates(jobId: id));
      case 'edit':
        await _edit(id);
      case 'view':
        await push(context, JobDetail(id: id));
    }
    _loader.currentState?.reload();
  }
}

class _Agreements extends StatelessWidget {
  const _Agreements();
  @override
  Widget build(BuildContext context) {
    return Loader(
      load: () => session.get('my/engagements'),
      builder: (context, data, reload) => _list(
        context,
        data as List,
        reload,
        (e) => Pressable(
          label: '${e['title']}',
          onTap: () async {
            await push(context, EngagementDetail(id: '${e['id']}'));
            reload();
          },
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              leading: Icon(e['asPoster'] == true ? FluentIcons.briefcase_24_regular : FluentIcons.hat_graduation_24_regular,
                  color: Theme.of(context).colorScheme.primary),
              title: Text('${e['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${e['asPoster'] == true ? t('You hired') : t('You were hired')} · ${t('Engagement${e['status']}')}'),
              trailing: const Icon(FluentIcons.chevron_right_24_regular),
            ),
          ),
        ),
        Message(icon: FluentIcons.handshake_24_regular, title: t('No agreements yet'), body: t('No agreements body')),
      ),
    );
  }
}

class _Talents extends StatefulWidget {
  const _Talents();
  @override
  State<_Talents> createState() => _TalentsState();
}

class _TalentsState extends State<_Talents> {
  final _loader = GlobalKey<LoaderState>();

  Future<void> _edit(String? id) async {
    await push(context, GigEditor(gigId: id));
    _loader.currentState?.reload();
  }

  Future<void> _status(Map g, String status) async {
    if (status == 'Deleted' &&
        !await confirmSheet(context, title: t('Delete this talent?'), body: t('Delete talent body'), confirm: t('Delete'), cancel: t('Cancel'), destructive: true)) {
      return;
    }
    try {
      final r = await session.post('my/gigs/${g['id']}/status', {'status': status}) as Map;
      if (mounted) toast(context, '${r['message']}');
      _loader.currentState?.reload();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Loader(
        key: _loader,
        load: () => session.get('my/gigs'),
        builder: (context, data, reload) => _list(
          context,
          data as List,
          reload,
          (g) {
            final active = g['status'] == 'Active';
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                title: Text('${g['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(active ? t('Live') : t('Hidden')),
                onTap: () => push(context, GigDetail(id: '${g['id']}')),
                trailing: PopupMenuButton<String>(
                  tooltip: t('More'),
                  onSelected: (v) => v == 'edit' ? _edit('${g['id']}') : _status(g, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(t('Edit talent'))),
                    PopupMenuItem(value: active ? 'Archived' : 'Active', child: Text(active ? t('Hide') : t('Show again'))),
                    PopupMenuItem(value: 'Deleted', child: Text(t('Delete'))),
                  ],
                ),
              ),
            );
          },
          Message(
            icon: FluentIcons.sparkle_24_regular,
            title: t('No talents yet'),
            body: t('Offer talent body'),
            action: t('Offer your talent'),
            onAction: () => _edit(null),
          ),
        ),
      );
}
