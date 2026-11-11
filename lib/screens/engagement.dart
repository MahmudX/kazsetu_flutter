import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'chat.dart';
import 'person.dart';
import 'report.dart';

/// One accepted agreement, from either side: terms, meeting place, contact, completion, review.
class EngagementDetail extends StatefulWidget {
  const EngagementDetail({super.key, required this.id});
  final String id;
  @override
  State<EngagementDetail> createState() => _EngagementDetailState();
}

class _EngagementDetailState extends State<EngagementDetail> {
  final _loader = GlobalKey<LoaderState>();
  bool _busy = false;

  Future<void> _act(String path, [Object? body, bool party = false]) async {
    setState(() => _busy = true);
    try {
      final r = await session.post('engagements/${widget.id}/$path', body) as Map;
      if (!mounted) return;
      if (party) celebrate(context);
      toast(context, '${r['message']}');
      await _loader.currentState?.reload();
      session.refreshMe();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(t('Agreement')),
          actions: [
            IconButton(
              tooltip: t('Report a problem'),
              icon: const Icon(FluentIcons.flag_24_regular),
              onPressed: () => showReportSheet(context, engagementId: widget.id),
            ),
          ],
        ),
        body: Loader(
          key: _loader,
          load: () => session.get('engagements/${widget.id}'),
          builder: (context, e, reload) => RefreshIndicator(onRefresh: reload, child: _body(context, e as Map)),
        ),
      );

  Widget _body(BuildContext context, Map e) {
    final theme = Theme.of(context);
    final status = '${e['status']}';
    final active = status == 'Accepted' || status == 'CompletionPending';
    final poster = e['isPoster'] == true;
    final terms = {'payAmount': e['agreedAmount'], 'paymentUnit': e['agreedUnit']};
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
      Text('${e['jobTitle']}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Pill(t('Engagement$status'), color: status == 'VerifiedCompleted' ? K.success : active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
      const SizedBox(height: 16),
      // The other side, with one tap to talk.
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          leading: Avatar(name: '${e['otherName']}', url: e['otherPictureUrl'] as String?, size: 44),
          title: Text('${e['otherName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(poster ? t('Worker') : t('Poster')),
          onTap: () => push(context, Person(keyOrHandle: '${e['otherHandle'] ?? e['otherId']}')),
          trailing: IconButton.filledTonal(
            tooltip: t('Message'),
            onPressed: () => push(context, ChatThread(otherUserId: '${e['otherId']}')),
            icon: const Icon(FluentIcons.chat_24_regular),
          ),
        ),
      ),
      SectionTitle(t('Agreed terms')),
      Card(
        child: Column(children: [
          ListTile(leading: const Icon(FluentIcons.money_24_regular), title: Text(t('Pay')), subtitle: Text(pay(terms))),
          ListTile(leading: const Icon(FluentIcons.calendar_ltr_24_regular), title: Text(t('Starts')), subtitle: Text(date(e['agreedStart']))),
          if (e['agreedEnd'] != null)
            ListTile(leading: const Icon(FluentIcons.calendar_checkmark_24_regular), title: Text(t('Ends')), subtitle: Text(date(e['agreedEnd']))),
        ]),
      ),
      SectionTitle(t('Meeting place')),
      _meeting(context, e, poster, active),
      if (e['sharedContactChannel'] != null) ...[
        SectionTitle(t('Contact')),
        Card(
          child: ListTile(
            leading: const Icon(FluentIcons.call_24_regular),
            title: Text('${e['sharedContactName']}'),
            subtitle: Text('${e['sharedContactChannel']}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: t('Copy'),
                icon: const Icon(FluentIcons.copy_24_regular),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${e['sharedContactChannel']}'));
                  toast(context, t('Copied'));
                },
              ),
              if (RegExp(r'^\+?[0-9 -]{7,}$').hasMatch('${e['sharedContactChannel']}'))
                IconButton.filledTonal(
                  tooltip: t('Call'),
                  icon: const Icon(FluentIcons.call_24_filled),
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: '${e['sharedContactChannel']}')),
                ),
            ]),
          ),
        ),
      ],
      if (active) ...[
        SectionTitle(t('Is the work done?')),
        _completion(context, e),
      ],
      if (e['canReview'] == true) ...[
        SectionTitle(t('Leave a review')),
        _ReviewForm(onSubmit: (rating, text) => _act('review', {'rating': rating, 'text': text})),
      ],
      if (e['myRating'] != null) ...[
        SectionTitle(t('Your review')),
        Text('${'★' * (e['myRating'] as int)}  ${e['myReviewText'] ?? ''}'),
        if (e['myReviewPublished'] != true)
          Text(t('Review private until both'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      ],
      if (e['theirRating'] != null) ...[
        SectionTitle(t('Their review')),
        Text('${'★' * (e['theirRating'] as int)}  ${e['theirReviewText'] ?? ''}'),
      ],
      SectionTitle(t('History')),
      _Timeline(events: (e['timeline'] as List).cast<Map>()),
      if (active) ...[
        const SizedBox(height: 24),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: _busy
              ? null
              : () async {
                  if (await confirmSheet(context, title: t('Cancel this agreement?'), body: t('Cancel agreement body'), confirm: t('Cancel agreement'), cancel: t('Keep it'), destructive: true)) {
                    await _act('cancel');
                  }
                },
          icon: const Icon(FluentIcons.dismiss_circle_24_regular),
          label: Text(t('Cancel agreement')),
        ),
      ],
    ]);
  }

  Widget _meeting(BuildContext context, Map e, bool poster, bool active) {
    final address = e['meetingAddress'] as String?;
    final theme = Theme.of(context);
    if (address == null) {
      return Card(
        child: ListTile(
          leading: const Icon(FluentIcons.location_24_regular),
          title: Text(poster ? t('Add where to meet') : t('The poster will add the place')),
          subtitle: Text(t('Address private')),
          trailing: poster && active ? FilledButton(onPressed: () => _editMeeting(e), child: Text(t('Add'))) : null,
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
          Row(children: [
            Icon(FluentIcons.location_24_filled, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(child: SelectableText(address, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          if ((e['meetingInstructions'] as String?)?.isNotEmpty == true) Text('${e['meetingInstructions']}'),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}'), mode: LaunchMode.externalApplication),
              icon: const Icon(FluentIcons.map_24_regular),
              label: Text(t('Open in maps')),
            ),
            if (poster && active) TextButton(onPressed: () => _editMeeting(e), child: Text(t('Change'))),
            if (!poster && e['meetingAcknowledged'] != true)
              FilledButton(onPressed: _busy ? null : () => _act('acknowledge'), child: Text(t('I have seen it'))),
          ]),
        ]),
      ),
    );
  }

  Future<void> _editMeeting(Map e) async {
    final address = TextEditingController(text: '${e['meetingAddress'] ?? ''}');
    final notes = TextEditingController(text: '${e['meetingInstructions'] ?? ''}');
    final ok = await confirmSheet(
      context,
      title: t('Where to meet'),
      body: t('Address private'),
      confirm: t('Save'),
      cancel: t('Cancel'),
      extra: [
        const SizedBox(height: 12),
        TextField(controller: address, maxLines: 2, decoration: InputDecoration(labelText: t('Exact address'))),
        const SizedBox(height: 10),
        TextField(controller: notes, maxLines: 3, decoration: InputDecoration(labelText: t('Directions (optional)'))),
      ],
    );
    final body = {'address': address.text, 'instructions': notes.text};
    address.dispose();
    notes.dispose();
    if (ok) await _act('meeting', body);
  }

  Widget _completion(BuildContext context, Map e) {
    final mine = e['myConfirmed'] == true;
    final theirs = e['otherConfirmed'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
          Row(children: [
            _Check(done: mine, label: t('You')),
            const SizedBox(width: 18),
            _Check(done: theirs, label: '${e['otherName']}'),
          ]),
          Text(t('Completion both'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (!mine)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Theme.of(context).colorScheme.onTertiary),
              onPressed: _busy
                  ? null
                  : () async {
                      if (await confirmSheet(context, title: t('Confirm the work is done?'), body: t('Confirm done body'), confirm: t('Yes, it is done'), cancel: t('Not yet'))) {
                        await _act('complete', null, true);
                      }
                    },
              icon: const Icon(FluentIcons.checkmark_circle_24_filled),
              label: Text(t('Mark as done')),
            ),
        ]),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.done, required this.label});
  final bool done;
  final String label;
  @override
  Widget build(BuildContext context) => Flexible(
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(done ? FluentIcons.checkmark_circle_24_filled : FluentIcons.circle_24_regular,
                key: ValueKey(done), color: done ? K.success : Theme.of(context).colorScheme.outline),
          ),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ]),
      );
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.onSubmit});
  final Future<void> Function(int rating, String text) onSubmit;
  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  int _rating = 0;
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StarPicker(value: _rating, onChanged: (v) => setState(() => _rating = v), labelFor: (i) => '${digits(i)} / ${digits(5)}'),
            TextField(controller: _text, maxLength: 1000, maxLines: 3, decoration: InputDecoration(hintText: t('Review hint'))),
            const SizedBox(height: 8),
            FilledButton(onPressed: _rating == 0 ? null : () => widget.onSubmit(_rating, _text.text), child: Text(t('Send review'))),
          ]),
        ),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<Map> events;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      for (var i = 0; i < events.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 28,
              child: Column(children: [
                Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                if (i < events.length - 1) Expanded(child: Container(width: 2, color: scheme.outlineVariant)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t('Event${events[i]['type']}')} · ${t('Actor${events[i]['actor']}')}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(date(events[i]['when']), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
