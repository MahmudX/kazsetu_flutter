import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'gigs.dart';
import 'job_detail.dart';

/// The categories and districts rarely change; one fetch per app run.
Map<String, dynamic>? _lookups;

class FindWork extends StatefulWidget {
  const FindWork({super.key});
  @override
  State<FindWork> createState() => _FindWorkState();
}

class _FindWorkState extends State<FindWork> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;
  final Map<String, Object?> _filters = {'status': 'active', 'sort': 'newest'};
  final _jobs = <Map<String, dynamic>>[];
  int _page = 1;
  bool _hasNext = false, _loading = false;
  Object? _error;
  int _generation = 0; // drops responses from superseded searches
  bool _talents = false; // Find work (jobs) or Find talent (gigs)

  void _onSession() => setState(() {}); // greeting and language follow the session

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
    _scroll.addListener(() {
      if (_hasNext && !_loading && _scroll.position.extentAfter < 600) _load(more: true);
    });
    _load();
    if (_lookups == null) {
      session.get('lookups').then((v) {
        if (mounted) setState(() => _lookups = v as Map<String, dynamic>);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    _scroll.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = more ? _generation : ++_generation;
    setState(() {
      _loading = true;
      if (!more) _error = null;
    });
    try {
      final page = more ? _page + 1 : 1;
      final result = _talents
          ? await session.get('gigs', {'q': _search.text.trim(), 'page': page}) as Map
          : await session.get('jobs', {..._filters, 'q': _search.text.trim(), 'page': page}) as Map;
      if (!mounted || generation != _generation) return;
      setState(() {
        if (!more) _jobs.clear();
        _jobs.addAll((result[_talents ? 'gigs' : 'jobs'] as List).cast<Map<String, dynamic>>());
        _page = page;
        _hasNext = result['hasNextPage'] as bool;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  void _set(String key, Object? value) {
    HapticFeedback.selectionClick();
    setState(() => _filters[key] = value);
    _load();
  }

  int get _activeFilters =>
      ['district', 'type', 'location'].where((k) => _filters[k] != null).length + (_filters['sort'] == 'soonest' ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = (_lookups?['categories'] as List?) ?? const [];
    final firstName = '${session.me?['displayName'] ?? ''}'.split(' ').first;
    return RefreshIndicator(
      edgeOffset: 180,
      onRefresh: () => _load(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 210,
            backgroundColor: K.deep,
            foregroundColor: Colors.white,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            title: const Logo(height: 30),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    foregroundColor: Colors.white,
                    selectedForegroundColor: K.deep,
                    selectedBackgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(value: false, label: Text(t('Jobs'))),
                    ButtonSegment(value: true, label: Text(t('Talents'))),
                  ],
                  selected: {_talents},
                  onSelectionChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _talents = v.first);
                    _load();
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _Hero(greeting: session.signedIn && firstName.isNotEmpty ? '${t('Hi')}, $firstName' : null),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 450), _load);
                  },
                  decoration: InputDecoration(
                    hintText: _talents ? t('Search talents') : t('Search work'),
                    prefixIcon: const Icon(FluentIcons.search_24_regular),
                    suffixIcon: ListenableBuilder(
                      listenable: _search,
                      builder: (_, _) => _search.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: t('Clear'),
                              icon: const Icon(FluentIcons.dismiss_24_regular),
                              onPressed: () {
                                _search.clear();
                                _load();
                              },
                            ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          ),
          if (!_talents) SliverToBoxAdapter(
            child: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                children: [
                  _CategoryChip(label: t('All'), selected: _filters['category'] == null, onTap: () => _set('category', null)),
                  for (final c in categories)
                    _CategoryChip(
                      label: name(c as Map, 'name'),
                      selected: _filters['category'] == c['id'],
                      onTap: () => _set('category', _filters['category'] == c['id'] ? null : c['id']),
                    ),
                ],
              ),
            ),
          ),
          if (!_talents) SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(children: [
                _CategoryChip(
                  label: t('Open now'),
                  icon: FluentIcons.flash_24_regular,
                  selected: _filters['status'] == 'active',
                  onTap: () => _set('status', _filters['status'] == 'active' ? 'all' : 'active'),
                ),
                const Spacer(),
                Badge(
                  isLabelVisible: _activeFilters > 0,
                  label: Text(digits(_activeFilters)),
                  backgroundColor: theme.colorScheme.tertiary,
                  child: TextButton.icon(
                    onPressed: _openFilters,
                    icon: const Icon(FluentIcons.options_24_regular),
                    label: Text(t('Filters')),
                  ),
                ),
              ]),
            ),
          ),
          if (_error != null && _jobs.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: ErrorMessage(_error!, onRetry: _load))
          else if (_loading && _jobs.isEmpty)
            SliverList.separated(
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: JobCardSkeleton()),
            )
          else if (_jobs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Message(
                icon: FluentIcons.briefcase_search_24_regular,
                title: t('No work matches yet'),
                body: t('Try fewer filters'),
                action: t('Clear'),
                onAction: () {
                  _search.clear();
                  setState(() => _filters
                    ..clear()
                    ..addAll({'status': 'all', 'sort': 'newest'}));
                  _load();
                },
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, _talents ? 16 : 4, 16, 16),
              sliver: SliverList.separated(
                itemCount: _jobs.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  if (i == _jobs.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _hasNext
                            ? const CircularProgressIndicator()
                            : Text(t('You reached the end'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    );
                  }
                  return Entrance(
                    key: ValueKey(_jobs[i]['id']),
                    index: i % 12,
                    child: _talents ? GigCard(gig: _jobs[i]) : JobCard(job: _jobs[i]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final draft = Map<String, Object?>.of(_filters);
    final districts = (_lookups?['districts'] as List?) ?? const [];
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        Widget section(String title, List<Widget> chips) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: chips),
              ]),
            );
        ChoiceChip chip(String key, Object? value, String label) => ChoiceChip(
              label: Text(label),
              selected: draft[key] == value,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setSheet(() => draft[key] = value);
              },
            );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Filters'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                section(t('Sort'), [chip('sort', 'newest', t('Newest')), chip('sort', 'soonest', t('Starting soon'))]),
                section(t('Kind of work'), [
                  chip('type', null, t('All')),
                  for (final type in const ['Task', 'Shift', 'Recurring', 'ShortProject']) chip('type', type, t(type)),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('Remote only')),
                  value: draft['location'] == 'Remote',
                  onChanged: (on) => setSheet(() => draft['location'] = on ? 'Remote' : null),
                ),
                const SizedBox(height: 8),
                section(t('District'), [
                  chip('district', null, t('Any district')),
                  for (final d in districts) chip('district', (d as Map)['id'], name(d, 'name')),
                ]),
                Row(spacing: 12, children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheet(() => draft
                        ..remove('district')
                        ..remove('type')
                        ..remove('location')
                        ..['sort'] = 'newest'),
                      child: Text(t('Clear')),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Show jobs'))),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
    if (applied == true) {
      setState(() => _filters
        ..clear()
        ..addAll(draft));
      _load();
    }
  }
}

/// The brand header: gradient, a slow drifting glow, the promise in one line.
class _Hero extends StatefulWidget {
  const _Hero({this.greeting});
  final String? greeting;
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) _c.stop();
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: K.brandGradient),
      child: Stack(children: [
        // Moves a cached glow with a transform: no layout, no repaint of the gradient each frame.
        Positioned(
          right: -60,
          top: -30,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Transform.translate(offset: Offset(50 * _c.value, 40 * _c.value), child: child),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [K.coral.withValues(alpha: 0.45), K.coral.withValues(alpha: 0)]),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 82,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.greeting != null)
              Text(widget.greeting!, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
            Text(
              t('Work near you, paid fairly'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        label: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            if (icon != null) Icon(icon, size: 18, color: selected ? scheme.onPrimary : scheme.onSurface),
            Text(label, style: TextStyle(color: selected ? scheme.onPrimary : scheme.onSurface, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// One listing: what, how much, where, when. The pay is the loudest thing on the card.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.compact = false});
  final Map<String, dynamic> job;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remote = job['locationMode'] == 'Remote';
    final place = remote ? t('Remote') : [name(job, 'area'), name(job, 'district')].where((s) => s.isNotEmpty).join(', ');
    final closed = job['intake'] != 'Open';
    return Pressable(
      label: job['title'] as String,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetail(id: job['id'] as String, preview: job))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Pill(name(job, 'category'), color: scheme.primary)),
              const SizedBox(width: 6),
              Pill(t('${job['workType']}')),
              const Spacer(),
              if (job['hasVerifiedCompletion'] == true)
                Pill(t('Completed'), color: K.success, icon: FluentIcons.checkmark_circle_24_filled)
              else if (closed)
                Pill(t('Closed')),
            ]),
            const SizedBox(height: 12),
            Hero(
              tag: 'title-${job['id']}',
              child: Material(
                type: MaterialType.transparency,
                child: Text(job['title'] as String, style: theme.textTheme.titleMedium, maxLines: compact ? 2 : 3, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              pay(job),
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 6, children: [
              _Meta(remote ? FluentIcons.globe_24_regular : FluentIcons.location_24_regular, place),
              _Meta(FluentIcons.calendar_ltr_24_regular, date(job['startsAt'], time: false)),
              if ((job['headcount'] as int? ?? 1) > 1)
                _Meta(
                  FluentIcons.people_24_regular,
                  job['showFillProgress'] == true
                      ? '${digits(job['filledPositions'])}/${digits(job['headcount'])} ${t('filled')}'
                      : '${digits(job['headcount'])} ${t('people needed')}',
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
      Icon(icon, size: 16, color: c),
      Text(text, style: TextStyle(color: c, fontSize: 13.5)),
    ]);
  }
}
