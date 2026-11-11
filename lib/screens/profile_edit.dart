import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';
import 'photos.dart';

/// The member's own profile: picture, public name, area, introduction, what they can do, and the
/// private contact channel that is shared only with consent.
class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key});
  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  Map<String, dynamic>? _data;
  late Map<String, dynamic> _in;
  String? _district, _picture;
  bool _busy = false, _uploading = false;
  Map<String, String> _errors = {};
  final _c = <String, TextEditingController>{};

  TextEditingController _text(String f) =>
      _c.putIfAbsent(f, () => TextEditingController(text: '${_in[f] ?? ''}')..addListener(() => _in[f] = _c[f]!.text));

  @override
  void initState() {
    super.initState();
    session.get('profile').then((d) {
      if (!mounted) return;
      setState(() {
        _data = d as Map<String, dynamic>;
        _in = Map.of(d['input'] as Map<String, dynamic>);
        _picture = d['pictureUrl'] as String?;
        final area = (d['areas'] as List).cast<Map>().where((a) => a['id'] == _in['areaId']).firstOrNull;
        _district = area == null ? null : '${area['districtId']}';
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

  Future<void> _changePicture() async {
    // Profile pictures: 1280 px, under 1 MB, front camera by default.
    final bytes = await pickPhoto(context, maxSide: 1024, rearCamera: false);
    if (bytes == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final r = await session.uploadPhoto('profile/picture', bytes);
      setState(() => _picture = r['url'] as String?);
      session.refreshMe();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => (_busy = true, _errors = {}));
    try {
      final r = await session.post('profile', _in) as Map;
      if (!mounted) return;
      toast(context, '${r['message']}');
      session.refreshMe();
      Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() => _errors = e.fields);
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(String f, String label, {int lines = 1, int? max, String? helper, TextInputType? keyboard}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: _text(f),
          minLines: lines,
          maxLines: lines + 3,
          maxLength: max,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3, errorText: _errors[f], alignLabelWithHint: lines > 1),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: Text(t('Edit profile'))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
              Center(
                child: Stack(children: [
                  Avatar(name: '${_in['displayName'] ?? ''}', url: _picture, size: 104),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: t('Change photo'),
                      onPressed: _uploading ? null : _changePicture,
                      icon: _uploading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(FluentIcons.camera_24_filled),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              _f('displayName', t('Your name'), max: 100),
              Text(t('District'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final dist in (d['districts'] as List).cast<Map>())
                  ChoiceChip(
                    label: Text(name(dist, 'name')),
                    selected: _district == '${dist['id']}',
                    onSelected: (_) => setState(() => (_district = '${dist['id']}', _in['areaId'] = null)),
                  ),
              ]),
              if (_district != null) ...[
                const SizedBox(height: 12),
                Text(t('Area'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in (d['areas'] as List).cast<Map>().where((a) => '${a['districtId']}' == _district))
                    ChoiceChip(label: Text(name(a, 'name')), selected: _in['areaId'] == a['id'], onSelected: (_) => setState(() => _in['areaId'] = a['id'])),
                ]),
              ],
              const SizedBox(height: 16),
              _f('introduction', t('About you (optional)'), lines: 3, max: 1000),
              _f('availability', t('When you are free (optional)'), max: 500),
              _f('capabilities', t('What you can do (optional)'), helper: t('Capabilities helper'), max: 2000),
              _f('contactChannel', t('Your contact number'), keyboard: TextInputType.phone, helper: t('Contact private helper'), max: 120),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('Tell me about matching work')),
                subtitle: Text(t('Outreach helper')),
                value: _in['outreachOptIn'] == true,
                onChanged: (v) => setState(() => _in['outreachOptIn'] = v),
              ),
            ]),
      bottomNavigationBar: d == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(onPressed: _busy ? null : _save, child: Text(t('Save'))),
              ),
            ),
    );
  }
}
