import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'i18n.dart';

/// KazSetu brand kit (same tokens as the web theme): navy for structure, royal blue for
/// interaction, coral for the one action that matters on a screen.
abstract final class K {
  static const navy = Color(0xFF1B2540);
  static const deep = Color(0xFF012E75); // logo "Kaz"
  static const blue = Color(0xFF2B52D6);
  static const sky = Color(0xFF0068E8); // logo "Setu"
  static const coral = Color(0xFFCF4326);
  static const success = Color(0xFF0F7048);
  static const warning = Color(0xFFB45309);
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B1F4D), deep, blue],
  );
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFF7AA0FF) : K.blue,
    onPrimary: dark ? const Color(0xFF0A1020) : Colors.white,
    secondary: dark ? const Color(0xFF232D47) : K.navy,
    onSecondary: dark ? const Color(0xFFE9ECF3) : Colors.white,
    tertiary: dark ? const Color(0xFFFF7052) : K.coral,
    onTertiary: dark ? const Color(0xFF240A04) : Colors.white,
    error: dark ? const Color(0xFFF16A6A) : const Color(0xFFC81E1E),
    onError: Colors.white,
    surface: dark ? const Color(0xFF171B22) : Colors.white,
    onSurface: dark ? const Color(0xFFE6E9EF) : const Color(0xFF10151F),
    surfaceContainerLowest: dark ? const Color(0xFF0F1319) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF131820) : const Color(0xFFF5F6F8),
    surfaceContainer: dark ? const Color(0xFF1C222B) : const Color(0xFFF0F2F5),
    surfaceContainerHigh: dark ? const Color(0xFF222934) : const Color(0xFFE9ECF1),
    outline: dark ? const Color(0xFF3A4350) : const Color(0xFFD5DAE2),
    outlineVariant: dark ? const Color(0xFF2A313C) : const Color(0xFFE3E6EB),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surfaceContainerLow,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52), shape: shape),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: scheme.outlineVariant),
      showCheckmark: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: shape),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    }),
  );
}

bool reduceMotion(BuildContext context) => MediaQuery.of(context).disableAnimations;

/// Opens a website page (posting work, agreements) in the browser.
Future<void> openWeb(String path) =>
    launchUrl(Uri.parse(absUrl(path)), mode: LaunchMode.externalApplication);

void toast(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
    ));
}

/// Shrinks a little under the finger with a selection tick: every card feels physical.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.label});
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) => setState(() => _down = v);
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      );
}

/// Fades and lifts a list item in, staggered by its index — once per item per app run, so
/// scrolling back never replays it. Runs on the compositor (FadeTransition/SlideTransition: no
/// rebuilds, no saveLayer); final state at once under reduced motion.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.index, required this.child, this.id});
  final int index;
  final Widget child;

  /// Stable identity for "already shown"; defaults to the widget key.
  final Object? id;
  static final _seen = <Object>{};
  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _curve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = widget.id ?? widget.key;
    if (_c != null || reduceMotion(context) || (id != null && !Entrance._seen.add(id))) return;
    final delay = 45 * min<int>(widget.index, 7);
    final total = 360 + delay;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: total))..forward();
    _curve = CurvedAnimation(parent: _c!, curve: Interval(delay / total, 1, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    if (curve == null) return widget.child;
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// Counts up to a number — credit balances feel earned, not printed.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style});
  final int value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text(digits(v.round()), style: style),
      );
}

/// Placeholder that shimmers while a list loads, shaped like the content it will become.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHigh;
    final shine = Theme.of(context).colorScheme.surface;
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          colors: [base, shine, base],
          stops: const [0.25, 0.5, 0.75],
          transform: _Slide(_c.value),
        ).createShader(r),
        child: child,
      ),
      child: widget.child,
    ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.t);
  final double t;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Shimmer(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: const [
              Row(children: [Bone(width: 90, height: 22, radius: 99), Spacer(), Bone(width: 70, height: 22, radius: 99)]),
              Bone(height: 20),
              Bone(width: 180, height: 20),
              Row(spacing: 8, children: [Bone(width: 80), Bone(width: 100)]),
            ]),
          ),
        ),
      );
}

/// Friendly full-screen state for empty lists and errors, with one clear next step.
class Message extends StatelessWidget {
  const Message({super.key, required this.icon, required this.title, this.body, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 40, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      ),
    );
  }
}

class ErrorMessage extends StatelessWidget {
  const ErrorMessage(this.error, {super.key, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Message(
        icon: error is ApiError && (error as ApiError).status == 0 ? FluentIcons.wifi_off_24_regular : FluentIcons.warning_24_regular,
        title: '$error',
        action: t('Try again'),
        onAction: onRetry,
      );
}

/// Small rounded label; color carries meaning only alongside the text.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon, this.filled = false});
  final String text;
  final Color? color;
  final IconData? icon;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
        if (icon != null) Icon(icon, size: 14, color: filled ? Colors.white : c),
        Text(text, style: TextStyle(color: filled ? Colors.white : c, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

Color statusColor(BuildContext context, String status) {
  final s = Theme.of(context).colorScheme;
  return switch (status) {
    'Accepted' => K.success,
    'Shortlisted' => s.primary,
    'Rejected' || 'Closed' || 'Withdrawn' => s.onSurfaceVariant,
    _ => K.warning,
  };
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 40});
  final String name;
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w.characters.first).join().toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: K.navy,
        foregroundImage: url == null
            ? null
            : ResizeImage(NetworkImage(absUrl(url!)), width: (size * MediaQuery.devicePixelRatioOf(context)).round()),
        child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
      ),
    );
  }
}

/// A burst of brand-colored confetti for the moments that matter: applied, offer accepted.
void celebrate(BuildContext context) {
  HapticFeedback.heavyImpact();
  if (reduceMotion(context)) return;
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Confetti(onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.onDone});
  final VoidCallback onDone;
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward().whenComplete(widget.onDone);
  final _bits = List.generate(70, (i) {
    final r = Random(i * 7919);
    return (
      angle: -pi / 2 + (r.nextDouble() - 0.5) * pi * 1.1,
      speed: 0.55 + r.nextDouble() * 0.7,
      spin: (r.nextDouble() - 0.5) * 12,
      size: 6 + r.nextDouble() * 7,
      color: const [K.coral, K.blue, K.sky, Color(0xFFFFC145), K.success][i % 5],
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_c.value, _bits)),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.bits);
  final double t;
  final List<({double angle, double speed, double spin, double size, Color color})> bits;
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final paint = Paint();
    for (final b in bits) {
      final d = b.speed * size.height * 0.75 * Curves.easeOutCubic.transform(t);
      final gravity = size.height * 0.55 * t * t;
      final p = origin + Offset(cos(b.angle) * d, sin(b.angle) * d + gravity);
      paint.color = b.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(b.spin * t);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// The white logo on brand surfaces; the colored one elsewhere.
class Logo extends StatelessWidget {
  const Logo({super.key, this.height = 36, this.onDark = true});
  final double height;
  final bool onDark;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'KazSetu',
        image: true,
        child: Image.asset(onDark ? 'assets/kazsetu-logo-white.png' : 'assets/kazsetu-logo.png', height: height),
      );
}

/// A network photo decoded at the size it is shown (not the full camera resolution), with a
/// quiet placeholder while it loads and a fallback when it cannot.
class NetPhoto extends StatelessWidget {
  const NetPhoto(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover, this.radius = 0, this.label});
  final String url;
  final double? width, height;
  final BoxFit fit;
  final double radius;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logical = width ?? MediaQuery.sizeOf(context).width;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        absUrl(url),
        width: width,
        height: height,
        fit: fit,
        cacheWidth: (logical * dpr).round(),
        semanticLabel: label,
        excludeFromSemantics: label == null,
        gaplessPlayback: true,
        frameBuilder: (_, child, frame, sync) => sync || frame != null
            ? child
            : SizedBox(width: width, height: height, child: ColoredBox(color: scheme.surfaceContainerHigh)),
        errorBuilder: (_, _, _) => SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: Icon(FluentIcons.image_off_24_regular, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Loads JSON once, shows a skeleton, then data or a retryable error. The builder gets a reload
/// callback for pull-to-refresh and after-action refreshes; stale data stays while reloading.
class Loader extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.skeleton});
  final Future<dynamic> Function() load;
  final Widget Function(BuildContext context, dynamic data, Future<void> Function() reload) builder;
  final Widget? skeleton;
  @override
  State<Loader> createState() => LoaderState();
}

class LoaderState extends State<Loader> {
  dynamic _data;
  Object? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final d = await widget.load();
      if (mounted) setState(() => (_data = d, _error = null, _loaded = true));
    } catch (e) {
      if (!mounted) return;
      if (_loaded) {
        toast(context, '$e', error: true);
      } else {
        setState(() => _error = e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return _error != null
          ? ErrorMessage(_error!, onRetry: () {
              setState(() => _error = null);
              reload();
            })
          : widget.skeleton ?? const Center(child: CircularProgressIndicator());
    }
    return widget.builder(context, _data, reload);
  }
}

/// A bottom sheet confirming an action that cannot be undone, or one that agrees to something.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  String? body,
  required String confirm,
  required String cancel,
  bool destructive = false,
  List<Widget> extra = const [],
}) async {
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
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
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
            OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
          ]),
        ),
      );
    },
  );
  return ok == true;
}

/// Five tappable stars; each is a 48 dp target with its own label (no swipe needed).
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged, required this.labelFor});
  final int value;
  final ValueChanged<int> onChanged;
  final String Function(int) labelFor;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: labelFor(i),
            iconSize: 34,
            onPressed: () {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            icon: AnimatedScale(
              scale: i <= value ? 1.12 : 1,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                i <= value ? FluentIcons.star_24_filled : FluentIcons.star_24_regular,
                color: i <= value ? const Color(0xFFE0A53A) : Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
      ]);
}

/// Section title used across detail screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ]),
      );
}

/// Opens a full-screen page with the platform transition.
Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
