import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'api.dart';
import 'firebase_options.dart';
import 'i18n.dart';
import 'screens/activity.dart';
import 'screens/auth.dart';
import 'screens/chat.dart';
import 'screens/find_work.dart';
import 'screens/gigs.dart';
import 'screens/job_editor.dart';
import 'screens/language.dart';
import 'screens/me.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await session.load();
  // Microsoft Clarity session analytics. Screens with private data (sign-in, verification,
  // chat, agreements, profile editing) are wrapped in ClarityMask so they are never recorded.
  // Use LogLevel.Verbose while testing to debug initialization.
  runApp(ClarityWidget(
    app: const KazSetuApp(),
    clarityConfig: ClarityConfig(projectId: 'zbzyret3th', logLevel: LogLevel.None),
  ));
}

class KazSetuApp extends StatelessWidget {
  const KazSetuApp({super.key});

  // Built once per language, not on every session change: the theme and route tree stay put
  // while badges and greetings update locally.
  static final _light = buildTheme(Brightness.light);
  static final _dark = buildTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([session.langNotifier, session.langChosen, session.signedInNotifier]),
        builder: (_, _) => MaterialApp(
          title: 'KazSetu',
          debugShowCheckedModeBanner: false,
          theme: _light,
          darkTheme: _dark,
          locale: Locale(session.lang),
          supportedLocales: const [Locale('bn'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // First open asks for the language, then sign-in; the app itself is for members only.
          home: !session.langChosen.value
              ? const LanguageScreen()
              : session.signedIn
                  ? Shell(key: ValueKey(session.lang))
                  : const AuthScreen(),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  // Tabs are built on first visit and kept, so scroll position and filters survive switching.
  final _visited = <int>{0};
  static const _post = 2; // the centre slot opens the post sheet instead of a tab

  void _go(int i) {
    HapticFeedback.selectionClick();
    if (i == _post) {
      _openPostSheet();
      return;
    }
    setState(() => (_tab = i, _visited.add(i)));
  }

  Future<void> _openPostSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t('What would you like to do?'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _PostChoice(
              icon: FluentIcons.briefcase_24_filled,
              title: t('Post work'),
              body: t('Post work sheet body'),
              color: Theme.of(context).colorScheme.tertiary,
              onTap: () => Navigator.pop(context, 'job'),
            ),
            const SizedBox(height: 10),
            _PostChoice(
              icon: FluentIcons.sparkle_24_filled,
              title: t('Offer your talent'),
              body: t('Offer talent body'),
              color: Theme.of(context).colorScheme.primary,
              onTap: () => Navigator.pop(context, 'gig'),
            ),
          ]),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'job') {
      // Guests may draft; saving asks them to sign in (the editor handles it).
      await push(context, const JobEditor());
    } else if (await requireSignIn(context) && mounted) {
      await push(context, const GigEditor());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FindWork(),
      const Activity(),
      const SizedBox.shrink(),
      Inbox(key: ValueKey('inbox${session.signedIn}')),
      const Me(),
    ];
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0); // Back from another tab returns to Find work first
      },
      child: Scaffold(
        body: IndexedStack(index: _tab, children: [
          for (var i = 0; i < pages.length; i++)
            // Hidden tabs keep their state but stop their animations (no off-screen frames).
            TickerMode(enabled: i == _tab, child: _visited.contains(i) ? pages[i] : const SizedBox.shrink()),
        ]),
        bottomNavigationBar: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            final todo = session.actionCount;
            final unread = session.me?['hasUnreadMessages'] == true;
            Widget badge(Widget icon, {int count = 0, bool dot = false}) => Badge(
                  isLabelVisible: count > 0 || dot,
                  smallSize: 9,
                  label: count > 0 ? Text(digits(count)) : null,
                  backgroundColor: scheme.tertiary,
                  child: icon,
                );
            return NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _go,
              destinations: [
                NavigationDestination(
                  icon: const Icon(FluentIcons.briefcase_search_24_regular),
                  selectedIcon: const Icon(FluentIcons.briefcase_search_24_filled),
                  label: t('Find'),
                ),
                NavigationDestination(
                  icon: badge(const Icon(FluentIcons.task_list_square_ltr_24_regular), count: todo),
                  selectedIcon: badge(const Icon(FluentIcons.task_list_square_ltr_24_filled), count: todo),
                  label: t('Activity'),
                ),
                NavigationDestination(
                  icon: Container(
                    width: 52,
                    height: 36,
                    decoration: BoxDecoration(color: scheme.tertiary, borderRadius: BorderRadius.circular(14)),
                    child: Icon(FluentIcons.add_24_filled, color: scheme.onTertiary),
                  ),
                  label: t('Post'),
                ),
                NavigationDestination(
                  icon: badge(const Icon(FluentIcons.chat_24_regular), dot: unread),
                  selectedIcon: badge(const Icon(FluentIcons.chat_24_filled), dot: unread),
                  label: t('Messages'),
                ),
                NavigationDestination(
                  icon: const Icon(FluentIcons.person_24_regular),
                  selectedIcon: const Icon(FluentIcons.person_24_filled),
                  label: t('Me'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PostChoice extends StatelessWidget {
  const _PostChoice({required this.icon, required this.title, required this.body, required this.color, required this.onTap});
  final IconData icon;
  final String title, body;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        label: title,
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(body, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
              const Icon(FluentIcons.chevron_right_24_regular),
            ]),
          ),
        ),
      );
}
