import 'dart:async';

import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../links.dart';
import '../push.dart';
import '../ui.dart';
import 'auth.dart';

/// Conversations, newest first, with unread counts.
class Inbox extends StatefulWidget {
  const Inbox({super.key});
  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  final _loader = GlobalKey<LoaderState>();

  void _onPush() => _loader.currentState?.reload();

  @override
  void initState() {
    super.initState();
    incomingPush.addListener(_onPush);
  }

  @override
  void dispose() {
    incomingPush.removeListener(_onPush);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Messages'))),
        body: !session.signedIn
            ? const SignInPrompt(icon: FluentIcons.chat_24_regular)
            : Loader(
                key: _loader,
                load: () => session.get('chat'),
                skeleton: ListView(children: [
                  for (var i = 0; i < 6; i++)
                    const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8), child: Shimmer(child: Bone(height: 56, radius: 16))),
                ]),
                builder: (context, data, reload) {
                  final items = (data as List).cast<Map>();
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: reload,
                      child: ListView(children: [
                        SizedBox(height: 460, child: Message(icon: FluentIcons.chat_multiple_24_regular, title: t('No messages yet'), body: t('No messages body'))),
                      ]),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      await reload();
                      session.refreshMe();
                    },
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final c = items[i];
                        final unread = c['unreadCount'] as int? ?? 0;
                        return Entrance(
                          index: i,
                          id: 'inbox-${c['otherUserId']}',
                          child: ListTile(
                            minTileHeight: 72,
                            leading: Avatar(name: '${c['otherName']}', url: c['otherPictureUrl'] as String?, size: 48),
                            title: Text('${c['otherName']}', style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600)),
                            subtitle: Text('${c['lastMessage'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, spacing: 4, children: [
                              Text(relative(c['lastMessageAt']), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              if (unread > 0) Badge(label: Text(digits(unread)), backgroundColor: Theme.of(context).colorScheme.tertiary),
                            ]),
                            onTap: () async {
                              await push(context, ChatThread(otherUserId: '${c['otherUserId']}'));
                              _loader.currentState?.reload();
                              session.refreshMe();
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      );
}

/// One conversation. Refreshes every few seconds while it is on screen and the app is in the
/// foreground; sending shows the bubble at once and confirms it when the server answers.
class ChatThread extends StatefulWidget {
  const ChatThread({super.key, required this.otherUserId, this.gigId, this.jobId});
  final String otherUserId;
  final String? gigId, jobId;
  @override
  State<ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<ChatThread> with WidgetsBindingObserver {
  // ponytail: polling, not a socket; switch to SignalR with a header-authenticated connection if
  // message volume makes a 4 s poll wasteful.
  static const _interval = Duration(seconds: 4);
  Map? _thread;
  Object? _error;
  final _messages = <Map>[];
  final _pending = <Map>[];
  final _input = TextEditingController();
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    incomingPush.addListener(_onPush);
    _load();
    _timer = Timer.periodic(_interval, (_) => _load(quiet: true));
  }

  // A push from this person shows their message now rather than at the next poll.
  void _onPush() {
    if (incomingPush.value?.data['userId'] == widget.otherUserId) _load(quiet: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer ??= Timer.periodic(_interval, (_) => _load(quiet: true));
      _load(quiet: true);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    incomingPush.removeListener(_onPush);
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final t = await session.get('chat/${widget.otherUserId}', {'gig': widget.gigId, 'job': widget.jobId}) as Map;
      if (!mounted) return;
      final next = (t['messages'] as List).cast<Map>();
      // Only rebuild when something arrived.
      if (_thread == null || next.length != _messages.length || (next.isNotEmpty && next.last['id'] != _messages.last['id'])) {
        if (_messages.isNotEmpty && next.length > _messages.length && next.last['mine'] != true) HapticFeedback.selectionClick();
        setState(() {
          _thread = t;
          _messages
            ..clear()
            ..addAll(next);
        });
      }
    } catch (e) {
      if (!quiet && mounted) setState(() => _error = e);
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    final about = _thread?['about'] as Map?;
    final draft = {'body': body, 'mine': true, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'pending': true};
    setState(() {
      _sending = true;
      _pending.add(draft);
    });
    _input.clear();
    try {
      await session.post('chat/${widget.otherUserId}/send', {
        'body': body,
        if (about?['isJob'] == true) 'jobId': about!['id'],
        if (about != null && about['isJob'] != true) 'gigId': about['id'],
      });
      HapticFeedback.lightImpact();
      await _load(quiet: true);
      if (mounted) setState(() => _pending.remove(draft));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _pending.remove(draft));
      _input.text = body; // nothing typed is lost
      toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    final theme = Theme.of(context);
    final all = [..._messages, ..._pending].reversed.toList();
    return ClarityMask(child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: thread == null
            ? null
            : Row(children: [
                Avatar(name: '${thread['otherName']}', url: thread['otherPictureUrl'] as String?, size: 36),
                const SizedBox(width: 10),
                Expanded(child: Text('${thread['otherName']}', overflow: TextOverflow.ellipsis)),
              ]),
        actions: [
          if (thread != null)
            IconButton(
              tooltip: t('Profile'),
              icon: const Icon(FluentIcons.person_24_regular),
              onPressed: () => openLink(context, '/people/${thread['otherHandle'] ?? thread['otherUserId']}'),
            ),
        ],
      ),
      body: thread == null
          ? (_error != null ? ErrorMessage(_error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : Column(children: [
              if (thread['about'] != null)
                Material(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  child: ListTile(
                    dense: true,
                    leading: Icon(thread['about']['isJob'] == true ? FluentIcons.briefcase_24_regular : FluentIcons.sparkle_24_regular),
                    title: Text('${t('About')}: ${thread['about']['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => openLink(context, '${thread['about']['url']}'),
                  ),
                ),
              Expanded(
                child: all.isEmpty
                    ? Message(icon: FluentIcons.hand_wave_24_regular, title: t('Say hello'), body: t('Chat safety'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: all.length,
                        itemBuilder: (context, i) => _Bubble(m: all[i], key: ValueKey(all[i]['id'] ?? all[i].hashCode)),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(hintText: t('Write a message'), counterText: '', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: t('Send'),
                      onPressed: _send,
                      icon: const Icon(FluentIcons.send_24_filled),
                    ),
                  ]),
                ),
              ),
            ]),
    ));
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.m});
  final Map m;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = m['mine'] == true;
    final pending = m['pending'] == true;
    final d = dhaka(m['createdAt']);
    final time = d == null ? '' : digits('${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}');
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: AnimatedOpacity(
          opacity: pending ? 0.6 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: mine ? scheme.primary : scheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
              border: mine ? null : Border.all(color: scheme.outlineVariant),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (m['topic'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('↳ ${m['topic']['title']}', style: TextStyle(fontSize: 12, color: mine ? scheme.onPrimary.withValues(alpha: 0.8) : scheme.onSurfaceVariant)),
                ),
              SelectableText('${m['body']}', style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(pending ? '…' : time, style: TextStyle(fontSize: 11, color: mine ? scheme.onPrimary.withValues(alpha: 0.75) : scheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}
