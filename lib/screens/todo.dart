import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import '../links.dart';

const _icons = {
  'OfferPending': FluentIcons.gift_24_regular,
  'ContactRequest': FluentIcons.contact_card_24_regular,
  'MeetingAcknowledge': FluentIcons.location_24_regular,
  'AddMeetingLocation': FluentIcons.location_add_24_regular,
  'CompletionConfirm': FluentIcons.checkmark_circle_24_regular,
  'ReviewDue': FluentIcons.star_24_regular,
  'NewApplicants': FluentIcons.people_24_regular,
  'ChangesRequested': FluentIcons.edit_24_regular,
};

/// The durable action inbox (PRD 20A): the same list the web shows under "Needs your action".
class Todo extends StatefulWidget {
  const Todo({super.key});
  @override
  State<Todo> createState() => _TodoState();
}

class _TodoState extends State<Todo> {
  List? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!session.signedIn) return;
    try {
      final items = await session.get('activity') as List;
      if (mounted) setState(() => (_items = items, _error = null));
      session.refreshMe(); // keeps the tab badge in step
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(Map item) async {
    await openLink(context, '${item['deepLink']}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;
    if (!session.signedIn) {
      body = const SignInPrompt(icon: FluentIcons.task_list_square_ltr_24_regular);
    } else if (_items == null) {
      body = _error != null ? ErrorMessage(_error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    } else if (_items!.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          SizedBox(
            height: 480,
            child: Message(icon: FluentIcons.checkmark_starburst_24_regular, title: t('All caught up'), body: t('All caught up body')),
          ),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final item = _items![i] as Map;
            final kind = '${item['kind']}';
            final count = item['count'] as int? ?? 1;
            final urgent = kind == 'OfferPending' || (item['due'] != null && DateTime.parse('${item['due']}').difference(DateTime.now()).inHours < 24);
            return Entrance(
              key: ValueKey('$kind${item['deepLink']}'),
              index: i,
              child: Pressable(
                label: t(kind),
                onTap: () => _open(item),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (urgent ? theme.colorScheme.tertiary : theme.colorScheme.primary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_icons[kind] ?? FluentIcons.alert_24_regular, color: urgent ? theme.colorScheme.tertiary : theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 3, children: [
                          Text(count > 1 ? '${t(kind)} · ${digits(count)}' : t(kind), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text('${item['jobTitle']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          if (item['due'] != null)
                            Text(relative(item['due']), style: TextStyle(color: urgent ? theme.colorScheme.tertiary : theme.colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      Icon(FluentIcons.chevron_right_24_regular, color: theme.colorScheme.onSurfaceVariant),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return body;
  }
}
