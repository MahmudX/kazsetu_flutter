
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'photos.dart';

/// "MedicalDoctor" -> "Medical doctor". The NID has its own label.
String credentialName(String type) {
  if (type == 'Nid') return t('National ID (NID)');
  final words = type.replaceAllMapped(RegExp('(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'), (_) => ' ').toLowerCase();
  return words[0].toUpperCase() + words.substring(1);
}

/// PRD 21: the member's credentials, their review state, and the way to send a new one.
class Verification extends StatefulWidget {
  const Verification({super.key});
  @override
  State<Verification> createState() => _VerificationState();
}

class _VerificationState extends State<Verification> {
  final _loader = GlobalKey<LoaderState>();

  Future<void> _open(String type) async {
    await push(context, CredentialCapture(type: type));
    _loader.currentState?.reload();
    session.refreshMe();
  }

  Future<void> _pickLicence(List licences) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LicencePicker(licences: licences.cast<String>()),
    );
    if (picked != null && mounted) await _open(picked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Verification'))),
        body: Loader(
          key: _loader,
          load: () => session.get('verification'),
          builder: (context, data, reload) {
            final items = (data['credentials'] as List).cast<Map>();
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _Intro(),
                const SizedBox(height: 16),
                for (var i = 0; i < items.length; i++)
                  Entrance(
                    index: i,
                    id: 'cred-${items[i]['type']}',
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CredentialCard(item: items[i], onOpen: () => _open('${items[i]['type']}')),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _pickLicence(data['licences'] as List),
                  icon: const Icon(FluentIcons.add_24_regular),
                  label: Text(t('Add a professional licence')),
                ),
              ]),
            );
          },
        ),
      );
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: K.brandGradient, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        const Icon(FluentIcons.shield_checkmark_24_filled, color: Colors.white, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
            Text(t('Get a checked badge'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
            Text(t('Verification intro'), style: TextStyle(color: scheme.surface.withValues(alpha: 0.85))),
          ]),
        ),
      ]),
    );
  }
}

(String, Color, IconData) credentialState(BuildContext context, Map item) {
  final scheme = Theme.of(context).colorScheme;
  if (item['inReview'] == true) return (t('In review'), K.warning, FluentIcons.hourglass_half_24_regular);
  return switch ('${item['status']}') {
    'Approved' when item['expired'] == true => (t('Expired'), scheme.error, FluentIcons.calendar_cancel_24_regular),
    'Approved' => (t('Checked'), K.success, FluentIcons.checkmark_circle_24_filled),
    'NeedsInformation' => (t('Needs a new photo'), scheme.tertiary, FluentIcons.camera_24_regular),
    'Rejected' => (t('Not approved'), scheme.error, FluentIcons.dismiss_circle_24_regular),
    'Revoked' => (t('Revoked'), scheme.error, FluentIcons.dismiss_circle_24_regular),
    _ => (t('Not checked yet'), scheme.onSurfaceVariant, FluentIcons.shield_24_regular),
  };
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({required this.item, required this.onOpen});
  final Map item;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = credentialState(context, item);
    return Pressable(
      label: credentialName('${item['type']}'),
      onTap: onOpen,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
                Text(credentialName('${item['type']}'), style: Theme.of(context).textTheme.titleMedium),
                Pill(label, color: color),
                if (item['expiresOn'] != null) Text('${t('Expires')} ${digits(item['expiresOn'])}'),
                if (item['reviewNote'] != null) Text('“${item['reviewNote']}”', style: const TextStyle(fontStyle: FontStyle.italic)),
              ]),
            ),
            const Icon(FluentIcons.chevron_right_24_regular),
          ]),
        ),
      ),
    );
  }
}

class _LicencePicker extends StatefulWidget {
  const _LicencePicker({required this.licences});
  final List<String> licences;
  @override
  State<_LicencePicker> createState() => _LicencePickerState();
}

class _LicencePickerState extends State<_LicencePicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final shown = widget.licences.where((l) => credentialName(l).toLowerCase().contains(_q.toLowerCase())).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(prefixIcon: const Icon(FluentIcons.search_24_regular), hintText: t('Search licences')),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(FluentIcons.certificate_24_regular),
              title: Text(credentialName(shown[i])),
              onTap: () => Navigator.pop(context, shown[i]),
            ),
          ),
        ),
      ]),
    );
  }
}

enum _SideState { empty, uploading, done, failed }

/// One credential: photograph the front (and back), each uploaded on its own so a failed side
/// retries without resending the other, then send both for review.
class CredentialCapture extends StatefulWidget {
  const CredentialCapture({super.key, required this.type});
  final String type;
  @override
  State<CredentialCapture> createState() => _CredentialCaptureState();
}

class _CredentialCaptureState extends State<CredentialCapture> {
  Map? _item;
  final _state = [_SideState.empty, _SideState.empty];
  final _bytes = <Uint8List?>[null, null];
  final _errors = <String?>[null, null];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await session.get('verification') as Map;
      final item = (data['credentials'] as List).cast<Map>().where((c) => c['type'] == widget.type).firstOrNull;
      if (!mounted) return;
      setState(() {
        _item = item ?? {'type': widget.type, 'backRequired': widget.type == 'Nid'};
        if (item?['frontReady'] == true && _state[0] == _SideState.empty) _state[0] = _SideState.done;
        if (item?['backReady'] == true && _state[1] == _SideState.empty) _state[1] = _SideState.done;
      });
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  bool get _backRequired => _item?['backRequired'] == true;
  bool get _locked => _item?['inReview'] == true || (_item?['status'] == 'Approved' && _item?['expired'] != true);
  bool get _ready => _state[0] == _SideState.done && (!_backRequired || _state[1] == _SideState.done) && !_state.contains(_SideState.uploading);

  Future<void> _capture(int side) async {
    // 2400 px keeps small print readable; the phone compresses before anything is sent.
    final bytes = await pickPhoto(context, maxSide: 2400, quality: 88);
    if (bytes == null || !mounted) return;
    _bytes[side] = bytes;
    await _upload(side);
  }

  Future<void> _upload(int side) async {
    setState(() => (_state[side] = _SideState.uploading, _errors[side] = null));
    try {
      await session.upload('verification/${widget.type}/sides/$side', 'photo', _bytes[side]!);
      HapticFeedback.lightImpact();
      if (mounted) setState(() => _state[side] = _SideState.done);
    } on ApiError catch (e) {
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => (_state[side] = _SideState.failed, _errors[side] = e.message));
    }
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      final r = await session.post('verification/${widget.type}/submit') as Map;
      if (!mounted) return;
      celebrate(context);
      toast(context, '${r['message']}');
      await _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(credentialName(widget.type))),
      body: item == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_locked) _LockedBanner(item: item) else ...[
                if (item['reviewNote'] != null)
                  Card(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.08),
                    child: ListTile(
                      leading: Icon(FluentIcons.chat_warning_24_regular, color: theme.colorScheme.tertiary),
                      title: Text(t('The reviewer asked')),
                      subtitle: Text('${item['reviewNote']}'),
                    ),
                  ),
                Text(t('Photograph your document'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                const _Tips(),
                const SizedBox(height: 16),
                _SideTile(
                  title: t('Front'),
                  state: _state[0],
                  bytes: _bytes[0],
                  error: _errors[0],
                  onCapture: () => _capture(0),
                  onRetry: () => _upload(0),
                ),
                const SizedBox(height: 12),
                _SideTile(
                  title: _backRequired ? t('Back') : t('Back (if it has one)'),
                  state: _state[1],
                  bytes: _bytes[1],
                  error: _errors[1],
                  onCapture: () => _capture(1),
                  onRetry: () => _upload(1),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(FluentIcons.lock_closed_24_regular, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t('Evidence privacy'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
                ]),
              ],
            ]),
      bottomNavigationBar: item == null || _locked
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, foregroundColor: theme.colorScheme.onTertiary),
                  onPressed: _ready && !_sending ? _submit : null,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(FluentIcons.send_24_filled),
                  label: Text(t('Send for review')),
                ),
              ),
            ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget tip(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [Icon(icon, size: 18, color: c), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: c)))]),
        );
    return Column(children: [
      tip(FluentIcons.crop_24_regular, t('Tip corners')),
      tip(FluentIcons.weather_sunny_24_regular, t('Tip light')),
      tip(FluentIcons.text_font_24_regular, t('Tip readable')),
    ]);
  }
}

class _SideTile extends StatelessWidget {
  const _SideTile({
    required this.title,
    required this.state,
    required this.bytes,
    required this.error,
    required this.onCapture,
    required this.onRetry,
  });
  final String title;
  final _SideState state;
  final Uint8List? bytes;
  final String? error;
  final VoidCallback onCapture, onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = state == _SideState.done;
    final failed = state == _SideState.failed;
    final border = failed ? scheme.error : done ? K.success : scheme.outline;
    return Semantics(
      button: true,
      label: '$title. ${done ? t('Photo saved.') : t('Tap to take a photo')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: state == _SideState.uploading ? null : onCapture,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: done || failed ? 2 : 1.5),
            color: scheme.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover, cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round())
            else
              // An ID-card-shaped outline so people know what goes where.
              Center(
                child: AspectRatio(
                  aspectRatio: 1.586,
                  child: Container(
                    margin: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant, width: 2),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(done ? FluentIcons.checkmark_circle_24_filled : FluentIcons.camera_24_regular,
                          size: 36, color: done ? K.success : scheme.primary),
                      const SizedBox(height: 6),
                      Text(done ? t('Photo saved.') : '${t('Tap to photograph')} · $title',
                          textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            Positioned(left: 12, top: 12, child: Pill(title, filled: true, color: K.navy)),
            if (state == _SideState.uploading)
              const ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator(color: Colors.white))),
            if (done && bytes != null)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  decoration: const BoxDecoration(color: K.success, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(FluentIcons.checkmark_16_filled, color: Colors.white, size: 18),
                ),
              ),
            if (done || failed)
              Positioned(
                right: 12,
                bottom: 12,
                child: FilledButton.tonalIcon(
                  onPressed: failed ? onRetry : onCapture,
                  icon: Icon(failed ? FluentIcons.arrow_sync_24_regular : FluentIcons.camera_24_regular),
                  label: Text(failed ? t('Try again') : t('Retake')),
                ),
              ),
            if (failed && error != null)
              Positioned(
                left: 12,
                bottom: 12,
                right: 140,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(10)),
                  child: Text(error!, style: TextStyle(color: scheme.onError, fontSize: 12.5)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.item});
  final Map item;
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = credentialState(context, item);
    return Message(
      icon: icon,
      title: label,
      body: item['inReview'] == true
          ? '${t('Sent')} ${date(item['submittedAt'])}. ${t('In review body')}'
          : item['expiresOn'] != null
              ? '${t('Expires')} ${digits(item['expiresOn'])}'
              : t('Checked body'),
    );
  }
}
