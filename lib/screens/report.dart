import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'auth.dart';

const _reasons = ['Harassment', 'Fake work', 'Changed terms', 'No show', 'Not paid', 'Technical problem', 'Something else'];

/// PRD 19: a contextual report. What it is about is attached automatically.
Future<void> showReportSheet(BuildContext context, {String? jobId, String? engagementId, String? subjectUserId}) async {
  if (!await requireSignIn(context) || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(jobId: jobId, engagementId: engagementId, subjectUserId: subjectUserId),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({this.jobId, this.engagementId, this.subjectUserId});
  final String? jobId, engagementId, subjectUserId;
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _detail = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await session.post('support', {
        'reason': _reason,
        'detail': _detail.text,
        'jobId': widget.jobId,
        'engagementId': widget.engagementId,
        'subjectUserId': widget.subjectUserId,
      }) as Map;
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, '${r['message']}');
    } on ApiError catch (e) {
      if (mounted) setState(() => _busy = false);
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t('Report a problem'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(t('Report body'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in _reasons)
                ChoiceChip(label: Text(t(r)), selected: _reason == r, onSelected: (_) => setState(() => _reason = r)),
            ]),
            const SizedBox(height: 14),
            TextField(controller: _detail, maxLength: 2000, maxLines: 4, decoration: InputDecoration(labelText: t('What happened? (optional)'))),
            const SizedBox(height: 8),
            FilledButton(onPressed: _reason == null || _busy ? null : _send, child: Text(t('Send report'))),
          ]),
        ),
      );
}
