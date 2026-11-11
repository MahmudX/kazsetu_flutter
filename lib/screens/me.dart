import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import 'job_editor.dart';
import 'person.dart';
import 'profile_edit.dart';
import 'report.dart';
import 'verification.dart';

class Me extends StatefulWidget {
  const Me({super.key});
  @override
  State<Me> createState() => _MeState();
}

class _MeState extends State<Me> {
  Map<String, dynamic>? _credits;

  bool _wasSignedIn = session.signedIn;

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

  void _onSession() {
    if (session.signedIn != _wasSignedIn) {
      _wasSignedIn = session.signedIn;
      _credits = null;
      _load();
    }
    setState(() {});
  }

  Future<void> _load() async {
    if (!session.signedIn) return;
    try {
      final c = await session.get('credits') as Map<String, dynamic>;
      if (mounted) setState(() => _credits = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = session.me;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await session.refreshMe();
          await _load();
        },
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: K.brandGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: session.signedIn
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Avatar(name: '${me?['displayName'] ?? ''}', url: me?['pictureUrl'] as String?, size: 64),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${me?['displayName'] ?? ''}', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                                if (me?['username'] != null) Text('@${me!['username']}', style: const TextStyle(color: Colors.white70)),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 22),
                          _CreditsCard(balance: (_credits?['balance'] ?? me?['balance'] ?? 0) as int),
                        ])
                      : Column(children: [
                          const Logo(height: 56),
                          const SizedBox(height: 16),
                          Text(t('Sign in body'), style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, minimumSize: const Size.fromHeight(52)),
                            onPressed: () => requireSignIn(context).then((_) => _load()),
                            child: Text(t('Sign in')),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AuthScreen(register: true)))
                                .then((_) => _load()),
                            child: Text(t('Create account')),
                          ),
                        ]),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(FluentIcons.local_language_24_regular),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t('Language'), style: const TextStyle(fontWeight: FontWeight.w600))),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [ButtonSegment(value: 'bn', label: Text('বাংলা')), ButtonSegment(value: 'en', label: Text('English'))],
                      selected: {session.lang},
                      onSelectionChanged: (s) {
                        HapticFeedback.selectionClick();
                        session.setLang(s.first);
                      },
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(children: [
                  if (session.signedIn) ...[
                    _Row(icon: FluentIcons.person_edit_24_regular, title: t('Edit profile'), onTap: () => push(context, const ProfileEdit())),
                    _Row(
                      icon: FluentIcons.shield_checkmark_24_regular,
                      title: t('Verification'),
                      subtitle: t('Verification row body'),
                      onTap: () => push(context, const Verification()),
                    ),
                    _Row(
                      icon: FluentIcons.person_24_regular,
                      title: t('My public profile'),
                      onTap: () => push(context, Person(keyOrHandle: '${me?['username'] ?? me?['id']}')),
                    ),
                  ],
                  _Row(icon: FluentIcons.add_circle_24_regular, title: t('Post work'), onTap: () => push(context, const JobEditor())),
                  if (session.signedIn)
                    _Row(icon: FluentIcons.flag_24_regular, title: t('Report a problem'), onTap: () => showReportSheet(context)),
                  _Row(icon: FluentIcons.chat_help_24_regular, title: t('Help'), external: true, onTap: () => openWeb('/support')),
                ]),
              ),
              if (session.signedIn) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(FluentIcons.gift_24_regular),
                  label: Text(t('Ask for more credits')),
                  onPressed: () async {
                    try {
                      final r = await session.post('credits/request') as Map;
                      if (context.mounted) toast(context, '${r['message']}');
                    } on ApiError catch (e) {
                      if (context.mounted) toast(context, e.message, error: true);
                    }
                  },
                ),
              ],
              if (session.signedIn && (_credits?['entries'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 20),
                Text(t('History'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(children: [
                    for (final e in (_credits!['entries'] as List).take(20))
                      ListTile(
                        leading: Icon(
                          (e['amount'] as int) >= 0 ? FluentIcons.arrow_down_24_regular : FluentIcons.arrow_up_24_regular,
                          color: (e['amount'] as int) >= 0 ? K.success : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(t('${e['reason']}')),
                        subtitle: Text(date(e['createdAt'])),
                        trailing: Text(
                          digits('${(e['amount'] as int) > 0 ? '+' : ''}${e['amount']}'),
                          style: TextStyle(fontWeight: FontWeight.w800, color: (e['amount'] as int) >= 0 ? K.success : null),
                        ),
                      ),
                  ]),
                ),
              ],
              if (session.signedIn) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  icon: const Icon(FluentIcons.sign_out_24_regular),
                  label: Text(t('Sign out')),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(t('Sign out?')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel'))),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Sign out'))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await session.signOut();
                    }
                  },
                ),
              ],
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({required this.balance});
  final int balance;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(FluentIcons.wallet_24_filled, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Credits'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              Text(t('Credits explainer'), style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
            ]),
          ),
          CountUp(balance, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.subtitle, required this.onTap, this.external = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool external;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Icon(external ? FluentIcons.open_24_regular : FluentIcons.chevron_right_24_regular, size: 20),
        onTap: onTap,
      );
}
