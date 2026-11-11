import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import 'chat.dart';
import 'person.dart';
import 'photos.dart';
import 'report.dart';

String _price(Map g) => '${t('From')} ${pay({'payAmount': g['startingPrice'], 'paymentUnit': g['paymentUnit']})}';

/// A talent (gig) in a list: cover photo, what, from how much.
class GigCard extends StatelessWidget {
  const GigCard({super.key, required this.gig});
  final Map<String, dynamic> gig;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = gig['coverPhotoUrl'] as String?;
    return Pressable(
      label: '${gig['title']}',
      onTap: () => push(context, GigDetail(id: '${gig['id']}', preview: gig)),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          SizedBox(
            width: 104,
            height: 116,
            child: cover != null
                ? Hero(tag: 'gig-${gig['id']}', child: NetPhoto(cover, width: 104, height: 116))
                : ColoredBox(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(FluentIcons.sparkle_24_filled, color: theme.colorScheme.primary, size: 32),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
                Pill(name(gig, 'category'), color: theme.colorScheme.primary),
                Text('${gig['title']}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(_price(gig), style: TextStyle(color: theme.colorScheme.tertiary, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class GigDetail extends StatelessWidget {
  const GigDetail({super.key, required this.id, this.preview});
  final String id;
  final Map<String, dynamic>? preview;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Loader(
          load: () => session.get('gigs/$id'),
          skeleton: preview == null ? null : _body(context, preview!, loading: true),
          builder: (context, g, _) => _body(context, g as Map<String, dynamic>),
        ),
      );

  Widget _body(BuildContext context, Map<String, dynamic> g, {bool loading = false}) {
    final theme = Theme.of(context);
    final photos = (g['photos'] as List?) ?? const [];
    final cover = g['coverPhotoUrl'] as String?;
    final mine = g['ownerId'] == session.me?['id'] || (session.me?['username'] != null && session.me?['username'] == g['ownerHandle']);
    return Stack(children: [
      CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 260,
          backgroundColor: K.deep,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          actions: [
            IconButton(
              tooltip: t('Report a problem'),
              icon: const Icon(FluentIcons.flag_24_regular),
              onPressed: () => showReportSheet(context, subjectUserId: '${g['ownerId']}'),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: photos.isNotEmpty
                ? PageView(children: [for (final p in photos) NetPhoto('${(p as Map)['url']}', label: '${g['title']}')])
                : cover != null
                    ? Hero(tag: 'gig-${g['id']}', child: NetPhoto(cover))
                    : const DecoratedBox(decoration: BoxDecoration(gradient: K.brandGradient)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          sliver: SliverList.list(children: [
            Pill(name(g, 'category'), color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text('${g['title']}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_price(g), style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.tertiary, fontWeight: FontWeight.w800)),
            if (g['negotiable'] == true) Text(t('Negotiable'), style: const TextStyle(color: K.success)),
            const SizedBox(height: 6),
            Text(g['locationMode'] == 'Remote' ? t('Remote') : t('In person')),
            SectionTitle(t('About this talent')),
            Text('${g['description']}', style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
            if ((g['tags'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in g['tags'] as List) Pill('#$tag')]),
            ],
            const SizedBox(height: 20),
            if (!loading)
              Card(
                child: ListTile(
                  leading: Avatar(name: '${g['ownerName']}', url: g['ownerPictureUrl'] as String?, size: 44),
                  title: Text('${g['ownerName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(t('View profile')),
                  onTap: () => push(context, Person(keyOrHandle: '${g['ownerHandle'] ?? g['ownerId']}')),
                ),
              ),
          ]),
        ),
      ]),
      if (!loading && !mine)
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, foregroundColor: theme.colorScheme.onTertiary),
              onPressed: () async {
                if (await requireSignIn(context) && context.mounted) {
                  await push(context, ChatThread(otherUserId: '${g['ownerId']}', gigId: '${g['id']}'));
                }
              },
              icon: const Icon(FluentIcons.chat_24_filled),
              label: Text(t('Message about this')),
            ),
          ),
        ),
    ]);
  }
}

/// Offer or edit a talent. Same server rules as the web editor.
class GigEditor extends StatefulWidget {
  const GigEditor({super.key, this.gigId});
  final String? gigId;
  @override
  State<GigEditor> createState() => _GigEditorState();
}

class _GigEditorState extends State<GigEditor> {
  Map<String, dynamic>? _model;
  late Map<String, dynamic> _in;
  final _photos = <Map<String, dynamic>>[];
  final _c = <String, TextEditingController>{};
  Map<String, String> _errors = {};
  bool _busy = false;

  TextEditingController _text(String f) =>
      _c.putIfAbsent(f, () => TextEditingController(text: '${_in[f] ?? ''}')..addListener(() => _in[f] = _c[f]!.text));

  @override
  void initState() {
    super.initState();
    session.get(widget.gigId == null ? 'my/gigs/new' : 'my/gigs/${widget.gigId}').then((m) {
      if (!mounted) return;
      setState(() {
        _model = m as Map<String, dynamic>;
        _in = Map.of(m['input'] as Map<String, dynamic>);
        _photos.addAll(((m['photos'] as Map)['photos'] as List).cast<Map<String, dynamic>>());
      });
    }).catchError((Object e) {
      if (mounted) toast(context, '$e', error: true);
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => (_busy = true, _errors = {}));
    final ids = _photos.map((p) => p['id']).toList();
    try {
      final r = await session.post(widget.gigId == null ? 'my/gigs' : 'my/gigs/${widget.gigId}', {
        ..._in,
        'startingPrice': num.tryParse('${_in['startingPrice']}'.replaceAll(',', '')) ?? 0,
        'photoIds': ids,
        'coverPhotoId': ids.isEmpty ? null : ids.first,
      }) as Map;
      if (!mounted) return;
      celebrate(context);
      toast(context, '${r['message']}');
      Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _errors = e.fields);
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(String field, String label, {int lines = 1, int? max, TextInputType? keyboard}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: _text(field),
          minLines: lines,
          maxLines: lines + 3,
          maxLength: max,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, errorText: _errors[field], alignLabelWithHint: lines > 1),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final m = _model;
    return Scaffold(
      appBar: AppBar(title: Text(widget.gigId == null ? t('Offer your talent') : t('Edit talent'))),
      body: m == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
              _f('title', t('What do you offer?'), max: 100),
              _f('description', t('Describe your service'), lines: 4, max: 3000),
              Text(t('Category'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in (m['categories'] as List).cast<Map>())
                  ChoiceChip(label: Text(name(c, 'name')), selected: _in['categoryId'] == c['id'], onSelected: (_) => setState(() => _in['categoryId'] = c['id'])),
              ]),
              if (_errors['categoryId'] != null) Text(_errors['categoryId']!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [ButtonSegment(value: 'Physical', label: Text(t('In person'))), ButtonSegment(value: 'Remote', label: Text(t('Remote')))],
                selected: {'${_in['locationMode'] ?? 'Physical'}'},
                onSelectionChanged: (s) => setState(() => _in['locationMode'] = s.first),
              ),
              const SizedBox(height: 16),
              _f('startingPrice', t('Starting price (৳)'), keyboard: TextInputType.number),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (u, k) in const [('Task', 'per task'), ('Hour', 'per hour'), ('Day', 'per day'), ('Month', 'per month'), ('Project', 'per project')])
                  ChoiceChip(label: Text(t(k).replaceFirst('/ ', '')), selected: _in['paymentUnit'] == u, onSelected: (_) => setState(() => _in['paymentUnit'] = u)),
              ]),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('Negotiable')), value: _in['negotiable'] == true, onChanged: (v) => setState(() => _in['negotiable'] = v)),
              _f('tags', t('Tags (optional)')),
              Text(t('Photos (first is the cover)'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              PhotoStrip(photos: _photos, onChanged: () => setState(() {})),
              if (m['needsAffirmation'] == true)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _in['affirm'] == true,
                  onChanged: (v) => setState(() => _in['affirm'] = v ?? false),
                  title: Text(t('Accept terms')),
                  subtitle: _errors['affirm'] == null ? null : Text(_errors['affirm']!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ]),
      bottomNavigationBar: m == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(onPressed: _busy ? null : _save, child: Text(widget.gigId == null ? t('Publish talent') : t('Save'))),
              ),
            ),
    );
  }
}
