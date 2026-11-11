import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';
import 'photos.dart';

/// PRD 06: post or edit a job in five short steps. The server owns every rule; this only gathers
/// input, shows the server's field errors on the step they belong to, and keeps what was typed.
class JobEditor extends StatefulWidget {
  const JobEditor({super.key, this.jobId, this.describe});
  final String? jobId;
  final String? describe;
  @override
  State<JobEditor> createState() => _JobEditorState();
}

// Which step shows each server field, so an error takes the poster straight to it.
const _stepOf = {
  'title': 0, 'description': 0, 'categoryId': 0, 'tags': 0,
  'workType': 1, 'payAmount': 1, 'payMaximum': 1, 'paymentUnit': 1, 'budgetBasis': 1, 'headcount': 1,
  'locationMode': 2, 'areaId': 2, 'startsAt': 2, 'endsAt': 2, 'applyBy': 2, 'untilFilled': 2,
  'scheduleDetails': 3, 'requirements': 3, 'paymentTiming': 3, 'includedExpenses': 3, 'workConditions': 3,
  'contactChannel': 4, 'affirm': 4, 'photoIds': 4,
};

class _JobEditorState extends State<JobEditor> {
  final _pages = PageController();
  int _step = 0;
  Map<String, dynamic>? _model;
  late Map<String, dynamic> _in; // JobEditorInput, edited in place
  bool _readOnly = false, _busy = false;
  Map<String, String> _errors = {};
  Object? _loadError;
  String? _district;
  final _photos = <Map<String, dynamic>>[];
  final _c = <String, TextEditingController>{};

  TextEditingController _text(String field) =>
      _c.putIfAbsent(field, () {
        final v = _in[field];
        // A new post starts with an empty amount, not "0".
        final text = v == null || (v is num && v == 0) ? '' : '$v';
        return TextEditingController(text: text)..addListener(() => _in[field] = _c[field]!.text);
      });

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = widget.jobId == null
          ? await session.get('jobs/new', {'describe': widget.describe})
          : await session.get('my/jobs/${widget.jobId}');
      final model = (widget.jobId == null ? r : r['model']) as Map<String, dynamic>;
      setState(() {
        _model = model;
        _readOnly = widget.jobId != null && r['readOnly'] == true;
        _in = Map<String, dynamic>.of(model['input'] as Map<String, dynamic>);
        _photos.addAll(((model['photos'] as Map)['photos'] as List).cast<Map<String, dynamic>>());
        final area = (model['areas'] as List).cast<Map>().where((a) => a['id'] == _in['areaId']).firstOrNull;
        _district = area == null ? null : '${area['districtId']}';
      });
    } catch (e) {
      setState(() => _loadError = e);
    }
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _step = step);
    _pages.animateToPage(step,
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Map<String, Object?> _payload() => {
        ..._in,
        'photoIds': _photos.map((p) => p['id']).toList(),
        // Bengali digits are fine to type; the server expects Latin.
        'payAmount': num.tryParse(_latin('${_in['payAmount'] ?? ''}')) ?? 0,
        'payMaximum': num.tryParse(_latin('${_in['payMaximum'] ?? ''}')),
      };

  Future<void> _send({required bool submit}) async {
    if (!await requireSignIn(context) || !mounted) return;
    setState(() => (_busy = true, _errors = {}));
    try {
      final r = await session.post(submit ? 'my/jobs/submit' : 'my/jobs/save', _payload()) as Map;
      if (!mounted) return;
      if (submit) {
        celebrate(context);
        toast(context, '${r['message']}');
        Navigator.pop(context, true);
      } else {
        _in['id'] = r['jobId'];
        toast(context, '${r['message']}');
      }
    } on ApiError catch (e) {
      HapticFeedback.mediumImpact();
      final fields = e.fields;
      setState(() => _errors = fields);
      if (fields.isNotEmpty) {
        final first = fields.keys.map((f) => _stepOf[f] ?? 4).reduce((a, b) => a < b ? a : b);
        _goTo(first);
      }
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_model == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _loadError != null ? ErrorMessage(_loadError!, onRetry: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final steps = [t('What'), t('Pay'), t('When & where'), t('Details'), t('Publish')];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jobId == null ? t('Post work') : t('Edit post')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == _step,
                    label: '${digits(i + 1)}. ${steps[i]}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _goTo(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _step ? scheme.tertiary : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(steps[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: i == _step ? FontWeight.w800 : FontWeight.w500,
                                color: _errors.keys.any((f) => (_stepOf[f] ?? 4) == i) ? scheme.error : null,
                              )),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
      body: Column(children: [
        if (_model!['notice'] != null)
          MaterialBanner(
            content: Text('${_model!['notice']}'),
            leading: const Icon(FluentIcons.info_24_regular),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(
          child: AbsorbPointer(
            absorbing: _readOnly,
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              children: [_what(), _pay(), _whenWhere(), _details(), _publish()],
            ),
          ),
        ),
      ]),
      bottomNavigationBar: _readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  if (_step > 0)
                    IconButton.outlined(
                      tooltip: t('Go back'),
                      onPressed: () => _goTo(_step - 1),
                      icon: const Icon(FluentIcons.arrow_left_24_regular),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _step < 4
                        ? FilledButton(onPressed: () => _goTo(_step + 1), child: Text(t('Next')))
                        : FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: scheme.tertiary, foregroundColor: scheme.onTertiary),
                            onPressed: _busy ? null : () => _send(submit: true),
                            icon: _busy
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(FluentIcons.send_24_filled),
                            label: Text(t('Submit for review')),
                          ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(onPressed: _busy ? null : () => _send(submit: false), child: Text(t('Save draft'))),
                ]),
              ),
            ),
    );
  }

  Widget _page(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: children,
      );

  Widget _field(String field, String label,
          {String? hint, int lines = 1, int? max, TextInputType? keyboard, String? helper}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: _text(field),
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 4,
          maxLength: max,
          keyboardType: keyboard,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_errors.containsKey(field)) setState(() => _errors.remove(field));
          },
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: helper,
            alignLabelWithHint: lines > 1,
            errorText: _errors[field],
          ),
        ),
      );

  Widget _chips<T>(String field, List<(T, String)> options, {ValueChanged<T>? onPick}) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: _in[field] == value,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() {
                _in[field] = value;
                _errors.remove(field);
              });
              onPick?.call(value);
            },
          ),
      ]);

  Widget _error(String field) => _errors[field] == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_errors[field]!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _what() {
    final categories = (_model!['categories'] as List).cast<Map>();
    return _page([
      Text(t('What do you need done?'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      _field('title', t('Title'), hint: t('Title hint'), max: 100),
      _field('description', t('Describe the work'), hint: t('Description hint'), lines: 4, max: 3000),
      _label(t('Category')),
      _chips<int>('categoryId', [for (final c in categories) (c['id'] as int, name(c, 'name'))]),
      _error('categoryId'),
      const SizedBox(height: 16),
      _field('tags', t('Tags (optional)'), hint: t('Tags hint')),
    ]);
  }

  Widget _pay() {
    final range = _in['payMaximum'] != null && '${_in['payMaximum']}'.isNotEmpty;
    final headcount = (_in['headcount'] as int?) ?? 1;
    final max = (_model!['maxHeadcount'] as int?) ?? 10;
    return _page([
      _label(t('Kind of work')),
      _chips<String>('workType', [for (final w in const ['Task', 'Shift', 'Recurring', 'ShortProject']) (w, t(w))]),
      _label(t('How many people?')),
      Row(children: [
        IconButton.filledTonal(
          tooltip: t('Fewer'),
          onPressed: headcount > 1 ? () => setState(() => _in['headcount'] = headcount - 1) : null,
          icon: const Icon(FluentIcons.subtract_24_regular),
        ),
        SizedBox(
          width: 64,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(digits(headcount),
                key: ValueKey(headcount), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        IconButton.filledTonal(
          tooltip: t('More'),
          onPressed: headcount < max ? () => setState(() => _in['headcount'] = headcount + 1) : null,
          icon: const Icon(FluentIcons.add_24_regular),
        ),
      ]),
      _error('headcount'),
      _label(t('Pay')),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _field('payAmount', range ? t('From (৳)') : t('Amount (৳)'), keyboard: TextInputType.number)),
        if (range) ...[const SizedBox(width: 10), Expanded(child: _field('payMaximum', t('Up to (৳)'), keyboard: TextInputType.number))],
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(t('Give a range')),
        value: range,
        onChanged: (on) => setState(() {
          _in['payMaximum'] = on ? '' : null;
          if (on) {
            _text('payMaximum').text = '';
          }
        }),
      ),
      _label(t('Paid per')),
      _chips<String>('paymentUnit', [
        for (final (u, k) in const [('Task', 'per task'), ('Hour', 'per hour'), ('Day', 'per day'), ('Month', 'per month'), ('Project', 'per project')])
          (u, t(k).replaceFirst('/ ', '')),
      ]),
      if (headcount > 1) ...[
        _label(t('The amount is')),
        _chips<String>('budgetBasis', [('PerWorker', t('For each person')), ('Total', t('Total for everyone'))]),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(t('Negotiable')),
        value: _in['negotiable'] == true,
        onChanged: (v) => setState(() => _in['negotiable'] = v),
      ),
    ]);
  }

  Widget _whenWhere() {
    final districts = (_model!['districts'] as List).cast<Map>();
    final areas = (_model!['areas'] as List).cast<Map>().where((a) => '${a['districtId']}' == _district).toList();
    final physical = _in['locationMode'] != 'Remote';
    final untilFilled = _in['untilFilled'] == true;
    return _page([
      _label(t('Where')),
      _chips<String>('locationMode', [('Physical', t('In person')), ('Remote', t('Remote'))]),
      if (physical) ...[
        _label(t('District')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in districts)
            ChoiceChip(
              label: Text(name(d, 'name')),
              selected: _district == '${d['id']}',
              onSelected: (_) => setState(() {
                _district = '${d['id']}';
                _in['areaId'] = null;
              }),
            ),
        ]),
        if (_district != null) ...[
          _label(t('Area')),
          _chips<int>('areaId', [for (final a in areas) (a['id'] as int, name(a, 'name'))]),
        ],
        _error('areaId'),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(t('Exact address later'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ],
      _label(t('When')),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(t('Until filled')),
        subtitle: Text(t('Until filled body')),
        value: untilFilled,
        onChanged: (v) => setState(() => _in['untilFilled'] = v),
      ),
      if (!untilFilled) ...[
        _DateField(label: t('Starts'), value: _in['startsAt'], error: _errors['startsAt'], onChanged: (v) => setState(() => (_in['startsAt'] = v, _errors.remove('startsAt')))),
        _DateField(label: t('Ends (optional)'), value: _in['endsAt'], error: _errors['endsAt'], onChanged: (v) => setState(() => _in['endsAt'] = v)),
        _DateField(label: t('Apply by'), value: _in['applyBy'], error: _errors['applyBy'], onChanged: (v) => setState(() => (_in['applyBy'] = v, _errors.remove('applyBy')))),
      ],
    ]);
  }

  Widget _details() => _page([
        Text(t('Details help the right people apply'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(t('All optional'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        _field('scheduleDetails', t('Schedule'), hint: t('Schedule hint'), lines: 2, max: 1000),
        _field('requirements', t('Requirements'), hint: t('Requirements hint'), lines: 2, max: 1000),
        _field('paymentTiming', t('Payment timing'), hint: t('Payment timing hint'), max: 500),
        _field('includedExpenses', t('Included expenses'), max: 500),
        _field('workConditions', t('Work conditions'), lines: 2, max: 500),
      ]);

  Widget _publish() {
    final m = _model!;
    final locked = (m['photos'] as Map)['locked'] == true;
    return _page([
      Text(t('Photos (optional)'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      PhotoStrip(
        photos: _photos,
        locked: locked,
        max: 5,
        onChanged: () => setState(() {}),
      ),
      if (m['contactOnFile'] != true) ...[
        const SizedBox(height: 18),
        _field('contactChannel', t('Your contact number'),
            keyboard: TextInputType.phone, helper: t('Contact private helper')),
      ],
      if (m['needsAffirmation'] == true) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _in['affirm'] == true,
          onChanged: (v) => setState(() => (_in['affirm'] = v ?? false, _errors.remove('affirm'))),
          title: Text(t('Accept terms')),
          subtitle: _errors['affirm'] == null
              ? null
              : Text(_errors['affirm']!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
            Text(t('Review'), style: Theme.of(context).textTheme.titleMedium),
            Text('${_in['title']}'.isEmpty ? '—' : '${_in['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (num.tryParse(_latin('${_in['payAmount'] ?? ''}')) case final amount?)
              Text(pay({..._in, 'payAmount': amount, 'payMaximum': num.tryParse(_latin('${_in['payMaximum'] ?? ''}'))}),
                  style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w800)),
            Text(t('Review body'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    ]);
  }
}

String _latin(String s) => s.replaceAllMapped(RegExp('[০-৯]'), (m) => '${m[0]!.codeUnitAt(0) - 0x09E6}').replaceAll(',', '').trim();

/// Picks a Dhaka-local date and time; the server reads it as Asia/Dhaka.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onChanged, this.error});
  final String label;
  final Object? value;
  final String? error;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value == null || '$value'.isEmpty ? null : DateTime.parse('$value');
    final shown = current == null
        ? t('Choose')
        : digits('${current.day}/${current.month}/${current.year}  ${current.hour % 12 == 0 ? 12 : current.hour % 12}:${current.minute.toString().padLeft(2, '0')} ${current.hour < 12 ? 'AM' : 'PM'}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final now = DateTime.now();
          final day = await showDatePicker(
            context: context,
            initialDate: current ?? now,
            firstDate: DateTime(now.year, now.month, now.day),
            lastDate: now.add(const Duration(days: 365)),
          );
          if (day == null || !context.mounted) return;
          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current ?? now.add(const Duration(hours: 1))));
          if (time == null) return;
          final picked = DateTime(day.year, day.month, day.day, time.hour, time.minute);
          onChanged(picked.toIso8601String().split('.').first);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            prefixIcon: const Icon(FluentIcons.calendar_ltr_24_regular),
            suffixIcon: current == null
                ? null
                : IconButton(tooltip: t('Clear'), icon: const Icon(FluentIcons.dismiss_24_regular), onPressed: () => onChanged(null)),
          ),
          child: Text(shown),
        ),
      ),
    );
  }
}
