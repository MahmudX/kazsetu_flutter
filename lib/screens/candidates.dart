import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'chat.dart';
import 'engagement.dart';
import 'person.dart';

/// The poster's applicants for one job: shortlist, decline, offer, ask to share contact.
/// Opening it marks unseen applications viewed (server side), as on the web.
class Candidates extends StatelessWidget {
  const Candidates({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Applicants'))),
        body: Loader(
          load: () => session.get('my/jobs/$jobId/candidates'),
          builder: (context, data, reload) {
            final list = (data['candidates'] as List).cast<Map<String, dynamic>>();
            final open = data['remainingPositions'] as int? ?? 0;
            return RefreshIndicator(
              onRefresh: reload,
              child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
                SliverToBoxAdapter(child: _Header(data: data, open: open)),
                if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Message(icon: FluentIcons.people_24_regular, title: t('No applicants yet'), body: t('No applicants body')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => Entrance(
                        index: i,
                        id: 'cand-${list[i]['applicationId']}',
                        child: _CandidateCard(c: list[i], offerTerms: data, canOffer: open > 0, onChanged: reload),
                      ),
                    ),
                  ),
              ]),
            );
          },
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.open});
  final Map data;
  final int open;
  @override
  Widget build(BuildContext context) {
    final headcount = data['headcount'] as int? ?? 1;
    final filled = (data['acceptedCount'] as int? ?? 0) + (data['reservedCount'] as int? ?? 0);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
        Text('${data['jobTitle']}', style: Theme.of(context).textTheme.titleLarge),
        Row(children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: headcount == 0 ? 0 : filled / headcount),
              duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: v, minHeight: 10, color: Theme.of(context).colorScheme.tertiary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${digits(open)} ${t('of')} ${digits(headcount)} ${t('open')}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        Text(t('Offer reserves a place'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _CandidateCard extends StatefulWidget {
  const _CandidateCard({required this.c, required this.offerTerms, required this.canOffer, required this.onChanged});
  final Map<String, dynamic> c;
  final Map offerTerms;
  final bool canOffer;
  final Future<void> Function() onChanged;
  @override
  State<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends State<_CandidateCard> {
  bool _busy = false;

  Future<void> _act(String path, [Object? body, bool party = false]) async {
    setState(() => _busy = true);
    try {
      final r = await session.post(path, body) as Map;
      if (!mounted) return;
      if (party) celebrate(context);
      toast(context, '${r['message']}');
      await widget.onChanged();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, String hint, String confirm, {List<Widget> extra = const []}) async {
    final controller = TextEditingController();
    final ok = await confirmSheet(
      context,
      title: title,
      confirm: confirm,
      cancel: t('Cancel'),
      extra: [
        ...extra,
        const SizedBox(height: 12),
        TextField(controller: controller, maxLength: 500, maxLines: 3, decoration: InputDecoration(hintText: hint)),
      ],
    );
    final text = controller.text;
    controller.dispose();
    return ok ? text : null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final theme = Theme.of(context);
    final status = '${c['status']}';
    final active = c['isActive'] == true;
    final id = c['applicationId'];
    final verified = (c['workerVerified'] as List?)?.isNotEmpty == true;
    final terms = widget.offerTerms;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => push(context, Person(keyOrHandle: '${c['workerHandle'] ?? c['workerId']}')),
            child: Row(children: [
              Avatar(name: '${c['workerName']}', size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text('${c['workerName']}', style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      Icon(FluentIcons.shield_checkmark_24_filled, size: 18, color: theme.colorScheme.primary, semanticLabel: t('Checked')),
                    ],
                  ]),
                  Text(
                    (c['completedAsWorker'] as int? ?? 0) > 0
                        ? '${digits(c['completedAsWorker'])} ${t('jobs completed')} · ${relative(c['submittedAt'])}'
                        : '${t('New on KazSetu')} · ${relative(c['submittedAt'])}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ]),
              ),
              Pill(c['hasPendingOffer'] == true ? t('Offer sent') : t(status),
                  color: c['hasPendingOffer'] == true ? theme.colorScheme.tertiary : statusColor(context, status)),
            ]),
          ),
          if ((c['note'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text('“${c['note']}”'),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (c['engagementId'] != null)
              FilledButton.icon(
                onPressed: () => push(context, EngagementDetail(id: '${c['engagementId']}')),
                icon: const Icon(FluentIcons.handshake_24_regular),
                label: Text(t('Open agreement')),
              ),
            if (active && c['hasPendingOffer'] != true && widget.canOffer)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, foregroundColor: theme.colorScheme.onTertiary),
                onPressed: _busy
                    ? null
                    : () async {
                        final note = await _ask(t('Send an offer?'), t('Offer note hint'), t('Send offer'), extra: [
                          const SizedBox(height: 8),
                          Text('${pay({'payAmount': terms['offerAmount'], 'payMaximum': terms['offerMaximum'], 'paymentUnit': terms['offerUnit']})} · ${date(terms['offerStart'])}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(t('Offer terms body')),
                        ]);
                        if (note != null) await _act('candidates/$id/offer', {'note': note}, true);
                      },
                icon: const Icon(FluentIcons.gift_24_regular),
                label: Text(t('Offer')),
              ),
            if (c['pendingOfferId'] != null)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await confirmSheet(context, title: t('Withdraw offer?'), body: t('Withdraw offer body'), confirm: t('Withdraw'), cancel: t('Cancel'), destructive: true)) {
                          await _act('offers/${c['pendingOfferId']}/cancel');
                        }
                      },
                child: Text(t('Withdraw offer')),
              ),
            if (status == 'Submitted')
              OutlinedButton(onPressed: _busy ? null : () => _act('candidates/$id/shortlist'), child: Text(t('Shortlist'))),
            if (active && c['contactRequested'] != true && c['contactGranted'] != true)
              OutlinedButton(onPressed: _busy ? null : () => _act('candidates/$id/request-contact'), child: Text(t('Ask to share contact'))),
            IconButton.outlined(
              tooltip: t('Message'),
              onPressed: () => push(context, ChatThread(otherUserId: '${c['workerId']}')),
              icon: const Icon(FluentIcons.chat_24_regular),
            ),
            if (active && c['hasPendingOffer'] != true)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                onPressed: _busy
                    ? null
                    : () async {
                        final reason = await _ask(t('Decline this applicant?'), t('Decline reason hint'), t('Decline'));
                        if (reason != null) await _act('candidates/$id/reject', {'reason': reason});
                      },
                child: Text(t('Decline')),
              ),
          ]),
        ]),
      ),
    );
  }
}
