import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import 'engagement.dart';

const _active = {'Submitted', 'Shortlisted', 'Accepted'};

class MyWork extends StatefulWidget {
  const MyWork({super.key, required this.onBrowse});
  final VoidCallback onBrowse;
  @override
  State<MyWork> createState() => _MyWorkState();
}

class _MyWorkState extends State<MyWork> {
  List<Map<String, dynamic>>? _items;
  Object? _error;
  bool _past = false;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
    _load();
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    super.dispose();
  }

  bool _wasSignedIn = session.signedIn;
  void _onSession() {
    if (session.signedIn != _wasSignedIn) {
      _wasSignedIn = session.signedIn;
      _load();
    }
  }

  Future<void> _load() async {
    if (!session.signedIn) return;
    try {
      final list = (await session.get('applications') as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => (_items = list, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!session.signedIn) {
      body = const SignInPrompt(icon: FluentIcons.briefcase_24_regular);
    } else if (_items == null) {
      body = _error != null
          ? ErrorMessage(_error!, onRetry: _load)
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (var i = 0; i < 4; i++)
                const Padding(padding: EdgeInsets.only(bottom: 12), child: Shimmer(child: Bone(height: 86, radius: 18))),
            ]);
    } else {
      final shown = _items!.where((a) => _active.contains(a['status']) != _past).toList()
        // Offers first: the thing that needs a decision.
        ..sort((a, b) => (b['hasPendingOffer'] == true ? 1 : 0) - (a['hasPendingOffer'] == true ? 1 : 0));
      body = RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(t('Active')), icon: const Icon(FluentIcons.flash_24_regular)),
                  ButtonSegment(value: true, label: Text(t('Past')), icon: const Icon(FluentIcons.history_24_regular)),
                ],
                selected: {_past},
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  setState(() => _past = s.first);
                },
              ),
            ),
          ),
          if (shown.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Message(
                icon: FluentIcons.document_bullet_list_24_regular,
                title: t('No applications yet'),
                body: t('No applications body'),
                action: _past ? null : t('Browse work'),
                onAction: widget.onBrowse,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => Entrance(
                  key: ValueKey('${shown[i]['id']}$_past'),
                  index: i,
                  child: _ApplicationCard(app: shown[i], onChanged: _load),
                ),
              ),
            ),
        ]),
      );
    }
    return body;
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app, required this.onChanged});
  final Map<String, dynamic> app;
  final Future<void> Function() onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offer = app['hasPendingOffer'] == true;
    final status = '${app['status']}';
    return Pressable(
      label: '${app['taskTitle']}',
      onTap: () async {
        await push(context, ApplicationDetail(id: app['id'] as String));
        onChanged();
      },
      child: Card(
        shape: offer
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: theme.colorScheme.tertiary, width: 2))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
                Text('${app['taskTitle']}', style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(spacing: 8, children: [
                  if (offer)
                    const _Pulse(child: Pill('', filled: true, color: K.coral, icon: FluentIcons.gift_24_filled)),
                  Pill(offer ? t('Offer waiting') : t(status), color: offer ? theme.colorScheme.tertiary : statusColor(context, status)),
                  Text(relative(app['submittedAt']), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5)),
                ]),
              ]),
            ),
            Icon(FluentIcons.chevron_right_24_regular, color: theme.colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

/// A soft heartbeat drawing the eye to something waiting on the person.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => reduceMotion(context)
      ? widget.child
      : ScaleTransition(scale: Tween(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: widget.child);
}

class ApplicationDetail extends StatefulWidget {
  const ApplicationDetail({super.key, required this.id});
  final String id;
  @override
  State<ApplicationDetail> createState() => _ApplicationDetailState();
}

class _ApplicationDetailState extends State<ApplicationDetail> {
  Map<String, dynamic>? _a;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await session.get('applications/${widget.id}') as Map<String, dynamic>;
      if (mounted) setState(() => (_a = a, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(String path, {bool party = false, Object? body}) async {
    setState(() => _busy = true);
    try {
      final r = await session.post(path, body) as Map;
      if (!mounted) return;
      if (party) celebrate(context);
      toast(context, '${r['message']}');
      session.refreshMe();
      await _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({required String title, required String body, required String confirm, bool destructive = false, List<Widget> extra = const []}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body, style: TextStyle(color: scheme.onSurfaceVariant)),
              ...extra,
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: destructive ? scheme.error : scheme.tertiary,
                  foregroundColor: destructive ? scheme.onError : scheme.onTertiary,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirm),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel'))),
            ]),
          ),
        );
      },
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final theme = Theme.of(context);
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? ErrorMessage(_error!, onRetry: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final status = '${a['status']}';
    return Scaffold(
      appBar: AppBar(title: Text(t('Applications'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Text('${a['taskTitle']}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${a['posterName']} · ${date(a['submittedAt'])}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          _Timeline(status: status, hasOffer: a['offerId'] != null),
          const SizedBox(height: 20),
          if (a['offerId'] != null) _offerCard(a),
          if (a['engagementId'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: () => push(context, EngagementDetail(id: '${a['engagementId']}')),
                icon: const Icon(FluentIcons.handshake_24_regular),
                label: Text(t('Open agreement')),
              ),
            ),
          if (a['contactRequestId'] != null) _contactRequest(a),
          if (a['sharedContactChannel'] != null)
            Card(
              child: ListTile(
                leading: const Icon(FluentIcons.call_24_regular),
                title: Text('${a['sharedContactName']}'),
                subtitle: Text('${a['sharedContactChannel']}'),
              ),
            ),
          const SizedBox(height: 12),
          Text(t('Terms you applied to'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(FluentIcons.money_24_regular), title: Text(t('Pay')), subtitle: Text(pay(a))),
              ListTile(
                leading: const Icon(FluentIcons.location_24_regular),
                title: Text(t('Where')),
                subtitle: Text(a['locationMode'] == 'Remote' ? t('Remote') : [name(a, 'area'), name(a, 'district')].where((s) => s.isNotEmpty).join(', ')),
              ),
              ListTile(leading: const Icon(FluentIcons.calendar_ltr_24_regular), title: Text(t('Starts')), subtitle: Text(date(a['startsAt']))),
            ]),
          ),
          if ((a['note'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text(t('Your note'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('${a['note']}'),
          ],
          if (a['refunded'] == true) ...[
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: Pill(t('Credit refunded'), color: K.success, icon: FluentIcons.arrow_undo_24_regular)),
          ],
          if (a['canWithdraw'] == true) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
              icon: const Icon(FluentIcons.arrow_undo_24_regular),
              label: Text(t('Withdraw application')),
              onPressed: _busy
                  ? null
                  : () async {
                      final refundUntil = a['refundableUntil'];
                      if (await _confirm(
                        title: t('Withdraw?'),
                        body: refundUntil != null ? '${t('Refund until')} ${date(refundUntil)}' : t('No refund now'),
                        confirm: t('Withdraw'),
                        destructive: true,
                      )) {
                        await _act('applications/${a['id']}/withdraw');
                      }
                    },
            ),
          ],
        ]),
      ),
    );
  }

  // PRD 15: the worker decides; contact is shared only on an explicit yes.
  Widget _contactRequest(Map<String, dynamic> a) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
            Row(children: [
              const Icon(FluentIcons.contact_card_24_regular),
              const SizedBox(width: 8),
              Expanded(child: Text(t('ContactRequest'), style: Theme.of(context).textTheme.titleMedium)),
            ]),
            Text(t('Contact request body')),
            Row(spacing: 10, children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _act('contact/${a['contactRequestId']}/respond', body: {'accept': false}),
                  child: Text(t('Decline')),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _act('contact/${a['contactRequestId']}/respond', body: {'accept': true}),
                  child: Text(t('Share my contact')),
                ),
              ),
            ]),
          ]),
        ),
      );

  Widget _offerCard(Map<String, dynamic> a) {
    final theme = Theme.of(context);
    final unit = a['offerUnit'] as int? ?? 0;
    final offerTerms = {'payAmount': a['offerAmount'], 'paymentUnit': unit};
    final rows = <(IconData, String, String)>[
      (FluentIcons.money_24_regular, t('Pay'), pay(offerTerms)),
      (FluentIcons.calendar_ltr_24_regular, t('Starts'), date(a['offerStart'])),
      if (a['offerEnd'] != null) (FluentIcons.calendar_checkmark_24_regular, t('Ends'), date(a['offerEnd'])),
      if (a['offerIncludesContact'] == true) (FluentIcons.contact_card_24_regular, t('Contact'), t('Contact will be shared')),
    ];
    final termList = [
      for (final (icon, label, value) in rows)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Icon(icon, size: 20, color: theme.colorScheme.tertiary),
            const SizedBox(width: 10),
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            Expanded(child: Text(value)),
          ]),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [theme.colorScheme.tertiary.withValues(alpha: 0.14), theme.colorScheme.tertiary.withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(FluentIcons.gift_24_filled, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(child: Text(t('You have an offer!'), style: theme.textTheme.titleMedium)),
            if (a['offerExpiresAt'] != null) Pill('${t('Expires')} ${relative(a['offerExpiresAt'])}', color: K.warning),
          ]),
          ...termList,
          if ((a['offerNote'] as String?)?.isNotEmpty == true)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text('“${a['offerNote']}”', style: const TextStyle(fontStyle: FontStyle.italic))),
          const SizedBox(height: 16),
          Row(spacing: 10, children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _confirm(title: t('Decline offer?'), body: t('Decline body'), confirm: t('Decline'), destructive: true)) {
                          await _act('offers/${a['offerId']}/decline');
                        }
                      },
                child: Text(t('Decline')),
              ),
            ),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, foregroundColor: theme.colorScheme.onTertiary),
                onPressed: _busy
                    ? null
                    : () async {
                        // Explicit acceptance of the exact terms shown (PRD 16).
                        if (await _confirm(
                          title: t('Review and accept'),
                          body: t('Accept terms body'),
                          confirm: t('I accept these terms'),
                          extra: termList,
                        )) {
                          await _act('offers/${a['offerId']}/accept', party: true);
                        }
                      },
                child: Text(t('Accept offer')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Where this application is: applied → shortlisted → offer → hired.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.status, required this.hasOffer});
  final String status;
  final bool hasOffer;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ended = {'Rejected', 'Withdrawn', 'Closed'}.contains(status);
    final reached = switch (status) {
      'Accepted' => 3,
      _ when hasOffer => 2,
      'Shortlisted' => 1,
      _ => 0,
    };
    final steps = [t('Applied'), t('Shortlisted'), t('Offer'), t('Hired')];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ended) ...[
            Pill(t(status), color: statusColor(context, status)),
            const SizedBox(height: 12),
          ],
          Row(children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: !ended && i <= reached ? 1 : 0),
                    duration: Duration(milliseconds: reduceMotion(context) ? 0 : 500 + 150 * i),
                    curve: Curves.easeOut,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 3,
                      color: scheme.primary,
                      backgroundColor: scheme.outlineVariant,
                    ),
                  ),
                ),
              _Dot(done: !ended && i <= reached, current: !ended && i == reached),
            ],
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 0; i < steps.length; i++)
              Text(steps[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: !ended && i == reached ? FontWeight.w800 : FontWeight.w500,
                    color: !ended && i <= reached ? scheme.onSurface : scheme.onSurfaceVariant,
                  )),
          ]),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.current});
  final bool done, current;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: current ? 22 : 16,
      height: current ? 22 : 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? scheme.primary : scheme.surface,
        border: Border.all(color: done ? scheme.primary : scheme.outline, width: 2),
        boxShadow: current ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 10)] : null,
      ),
      child: done ? Icon(FluentIcons.checkmark_12_filled, size: current ? 14 : 10, color: scheme.onPrimary) : null,
    );
  }
}
