import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import 'candidates.dart';
import 'chat.dart';
import 'person.dart';
import 'report.dart';
import 'find_work.dart';
import 'my_work.dart';

class JobDetail extends StatefulWidget {
  const JobDetail({super.key, required this.id, this.preview});
  final String id;

  /// The listing row from the list, so the page paints instantly while details load.
  final Map<String, dynamic>? preview;
  @override
  State<JobDetail> createState() => _JobDetailState();
}

class _JobDetailState extends State<JobDetail> {
  Map<String, dynamic>? _detail;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await session.get('jobs/${widget.id}') as Map<String, dynamic>;
      if (mounted) setState(() => (_detail = d, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = (_detail?['job'] as Map<String, dynamic>?) ?? widget.preview;
    if (job == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? ErrorMessage(_error!, onRetry: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = _detail;
    final remote = job['locationMode'] == 'Remote';
    final photos = (d?['photos'] as List?) ?? const [];
    final sections = <(String, String)>[
      (t('Schedule'), '${job['scheduleDetails'] ?? ''}'),
      (t('Requirements'), '${job['requirements'] ?? ''}'),
      (t('Payment timing'), '${job['paymentTiming'] ?? ''}'),
      (t('Included expenses'), '${job['includedExpenses'] ?? ''}'),
      (t('Work conditions'), '${job['workConditions'] ?? ''}'),
    ].where((s) => s.$2.trim().isNotEmpty);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: photos.isEmpty ? 150 : 260,
          backgroundColor: K.deep,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          actions: [
            IconButton(
              tooltip: t('Report a problem'),
              icon: const Icon(FluentIcons.flag_24_regular),
              onPressed: () => showReportSheet(context, jobId: widget.id),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: photos.isEmpty
                ? const DecoratedBox(decoration: BoxDecoration(gradient: K.brandGradient))
                : PageView(children: [
                    for (final p in photos) NetPhoto('${(p as Map)['url']}', label: job['title'] as String),
                  ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill(name(job, 'category'), color: scheme.primary),
                Pill(t('${job['workType']}')),
                if (job['negotiable'] == true) Pill(t('Negotiable'), color: K.success),
              ]),
              const SizedBox(height: 12),
              Hero(
                tag: 'title-${job['id']}',
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(job['title'] as String, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 16),
              _PayBanner(job: job),
              const SizedBox(height: 16),
              _Facts(rows: [
                (remote ? FluentIcons.globe_24_regular : FluentIcons.location_24_regular, t('Where'),
                    remote ? t('Remote') : [name(job, 'area'), name(job, 'district')].where((s) => s.isNotEmpty).join(', ')),
                (FluentIcons.calendar_ltr_24_regular, t('Starts'), date(job['startsAt'])),
                if (job['endsAt'] != null) (FluentIcons.calendar_checkmark_24_regular, t('Ends'), date(job['endsAt'])),
                if (job['applyBy'] != null)
                  (FluentIcons.clock_24_regular, t('Apply by'), '${date(job['applyBy'])} · ${relative(job['applyBy'])}'),
                if ((job['headcount'] as int? ?? 1) > 1)
                  (FluentIcons.people_24_regular, t('people needed'), '${digits(job['filledPositions'] ?? 0)}/${digits(job['headcount'])} ${t('filled')}'),
              ]),
              const SizedBox(height: 24),
              Text(t('About the work'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('${job['description']}', style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
              if ((job['tags'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final tag in job['tags'] as List) Pill('#$tag', icon: FluentIcons.tag_24_regular),
                ]),
              ],
              for (final s in sections) ...[
                const SizedBox(height: 20),
                Text(s.$1, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(s.$2, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
              ],
              const SizedBox(height: 24),
              if (d != null) _PosterCard(job: job, detail: d) else const Shimmer(child: Bone(height: 84, radius: 18)),
              if ((d?['reviews'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 24),
                Text(t('Reviews'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final r in d!['reviews'] as List) _ReviewTile(review: r as Map),
              ],
            ]),
          ),
        ),
        if ((d?['similarJobs'] as List?)?.isNotEmpty == true) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
              child: Text(t('Similar work'), style: theme.textTheme.titleMedium),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 214,
              child: PageView(
                controller: PageController(viewportFraction: 0.86),
                padEnds: false,
                children: [
                  for (final s in d!['similarJobs'] as List)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: JobCard(job: (s as Map).cast<String, dynamic>(), compact: true),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ]),
      bottomNavigationBar: d == null ? null : _ApplyBar(detail: d, onChanged: _load),
    );
  }
}

class _PayBanner extends StatelessWidget {
  const _PayBanner({required this.job});
  final Map job;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(FluentIcons.money_24_regular, color: scheme.tertiary, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pay(job), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w800)),
            if (job['budgetBasis'] == 'Total') Text(t('Total budget'), style: TextStyle(color: scheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.rows});
  final List<(IconData, String, String)> rows;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          for (final (icon, label, value) in rows)
            ListTile(
              dense: true,
              leading: Icon(icon, color: scheme.primary),
              title: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.job, required this.detail});
  final Map job, detail;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rating = detail['posterRating'] as num?;
    final completed = detail['posterCompletedJobs'] as int? ?? 0;
    final verified = (detail['posterVerified'] as List?)?.isNotEmpty == true;
    final mine = detail['eligibilityStatus'] == 'IsPoster';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => push(context, Person(keyOrHandle: '${job['posterHandle'] ?? job['posterId']}')),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Avatar(name: '${job['posterName']}', url: job['posterPictureUrl'] as String?, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
              Text(t('Posted by'), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
              Row(children: [
                Flexible(child: Text('${job['posterName']}', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                if (verified) ...[
                  const SizedBox(width: 4),
                  Icon(FluentIcons.shield_checkmark_24_filled, size: 18, color: scheme.primary, semanticLabel: 'verified'),
                ],
              ]),
              Text(
                [
                  if (rating != null) '★ ${digits(rating.toStringAsFixed(1))} (${digits(detail['posterReviewCount'])} ${t('reviews')})',
                  if (completed > 0) '${digits(completed)} ${t('jobs completed')}',
                  if (rating == null && completed == 0) t('New on KazSetu'),
                ].join(' · '),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ]),
          ),
          if (!mine)
            IconButton.filledTonal(
              tooltip: t('Message'),
              icon: const Icon(FluentIcons.chat_24_regular),
              onPressed: () async {
                if (!await requireSignIn(context) || !context.mounted) return;
                try {
                  final r = await session.post('chat/start', {'jobId': job['id']}) as Map;
                  if (context.mounted) await push(context, ChatThread(otherUserId: '${r['otherUserId']}', jobId: '${job['id']}'));
                } on ApiError catch (e) {
                  if (context.mounted) toast(context, e.message, error: true);
                }
              },
            ),
        ]),
      ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Map review;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: '${review['reviewerName']}', size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${review['reviewerName']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('★' * (review['rating'] as int), style: const TextStyle(color: Color(0xFFE0A53A)), semanticsLabel: '${review['rating']}/5'),
              ]),
              Text('${review['text']}'),
            ]),
          ),
        ]),
      );
}

/// The one primary action, always in reach. Its label says exactly why when it cannot apply.
class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.detail, required this.onChanged});
  final Map<String, dynamic> detail;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final status = detail['eligibilityStatus'] as String;
    final cost = detail['cost'] as int;
    final scheme = Theme.of(context).colorScheme;
    final (String label, VoidCallback? action, String? hint) = switch (status) {
      'Eligible' => ('${t('Apply')} · ${digits(cost)} ${t(cost == 1 ? 'credit' : 'credits')}', () => _apply(context), null),
      'NotSignedIn' => (t('Sign in to apply'), () => _signIn(context), null),
      'AlreadyApplied' => (t('View my application'), () => _openApplication(context), null),
      'IsPoster' => (t('See applicants'), () => push(context, Candidates(jobId: '${detail['job']['id']}')), null),
      'InsufficientCredits' => (t('Not enough credits'), null, '${t('You have')} ${digits(detail['balance'])} · ${t('Costs')} ${digits(cost)}'),
      'IntakePaused' => (t('Applications paused'), null, null),
      'NeedsCredential' => (t('Needs a checked licence'), null, null),
      'AccountInactive' => (t('Account not active'), null, null),
      _ => (t('Not accepting applications'), null, null),
    };
    return Material(
      color: scheme.surface,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (hint != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(hint, style: TextStyle(color: scheme.onSurfaceVariant))),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: scheme.tertiary, foregroundColor: scheme.onTertiary),
                onPressed: action,
                child: Text(label),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    if (await requireSignIn(context)) await onChanged();
  }

  void _openApplication(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ApplicationDetail(id: detail['myApplicationId'] as String),
      ));

  Future<void> _apply(BuildContext context) async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ApplySheet(detail: detail),
    );
    if (applied == true && context.mounted) {
      celebrate(context);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(FluentIcons.checkmark_circle_24_filled, color: K.success, size: 56),
          title: Text(t('Applied!')),
          content: Text(t('Applied body'), textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      session.refreshMe();
      await onChanged();
    }
  }
}

class _ApplySheet extends StatefulWidget {
  const _ApplySheet({required this.detail});
  final Map<String, dynamic> detail;
  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final _note = TextEditingController();
  bool _available = false, _sending = false, _showAttestError = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_available) {
      HapticFeedback.mediumImpact();
      setState(() => _showAttestError = true);
      return;
    }
    setState(() => (_sending = true, _error = null));
    try {
      await session.post('jobs/${widget.detail['job']['id']}/apply', {
        'appliedVersion': widget.detail['publishedVersion'],
        'note': _note.text,
        'availabilityAttested': true,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      HapticFeedback.mediumImpact();
      setState(() => (_sending = false, _error = e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = widget.detail['cost'] as int;
    final balance = widget.detail['balance'] as int;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Apply for this work'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${widget.detail['job']['title']}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          TextField(
            controller: _note,
            maxLength: 1000,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: t('Note to poster'), hintText: t('Note hint'), alignLabelWithHint: true),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _available,
            onChanged: (v) => setState(() => (_available = v, _showAttestError = false)),
            title: Text(t('I am available'), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${t('Starts')}: ${date(widget.detail['job']['startsAt'])}'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _showAttestError
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(t('Confirm availability'), style: TextStyle(color: theme.colorScheme.error)),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(FluentIcons.wallet_24_regular, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${t('Costs')} ${digits(cost)} ${t('credits')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' · ${t('You have')} ${digits(balance)}'),
                  TextSpan(text: '\n${t('Refund note')}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5)),
                ])),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, foregroundColor: theme.colorScheme.onTertiary),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(FluentIcons.send_24_filled),
              label: Text(t('Send application')),
            ),
          ),
        ]),
      ),
    );
  }
}
