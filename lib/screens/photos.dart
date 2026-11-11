import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';

final _picker = ImagePicker();

/// Asks camera or gallery, then returns a JPEG the phone already resized and compressed — big
/// camera files never cross the network. Null when the person cancels.
Future<Uint8List?> pickPhoto(
  BuildContext context, {
  required int maxSide,
  int quality = 82,
  bool rearCamera = true,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(FluentIcons.camera_24_regular),
          title: Text(t('Take a photo')),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(FluentIcons.image_multiple_24_regular),
          title: Text(t('Choose from gallery')),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;
  final file = await _picker.pickImage(
    source: source,
    maxWidth: maxSide.toDouble(),
    maxHeight: maxSide.toDouble(),
    imageQuality: quality,
    preferredCameraDevice: rearCamera ? CameraDevice.rear : CameraDevice.front,
    requestFullMetadata: false,
  );
  return file?.readAsBytes();
}

/// Up to [max] listing photos. New photos upload as soon as they are picked (signed direct
/// upload); the form saves only their ids. Items: {id, url} for saved, {id, bytes} for new.
class PhotoStrip extends StatefulWidget {
  const PhotoStrip({super.key, required this.photos, required this.onChanged, this.max = 5, this.locked = false});
  final List<Map<String, dynamic>> photos;
  final VoidCallback onChanged;
  final int max;
  final bool locked;
  @override
  State<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<PhotoStrip> {
  bool _uploading = false;

  Future<void> _add() async {
    if (!session.signedIn) {
      toast(context, t('Sign in to add photos'), error: true);
      return;
    }
    // The server accepts at most 1280 px and 1 MB; quality 82 keeps a phone photo well under.
    final bytes = await pickPhoto(context, maxSide: 1280);
    if (bytes == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final done = await session.uploadPhoto('photos', bytes);
      widget.photos.add({'id': done['fileId'], 'bytes': bytes});
      widget.onChanged();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 104,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final p in widget.photos)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: p['bytes'] != null
                    ? Image.memory(p['bytes'] as Uint8List, width: 104, height: 104, fit: BoxFit.cover, cacheWidth: 312)
                    : NetPhoto('${p['url']}', width: 104, height: 104),
              ),
              if (!widget.locked)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton.filledTonal(
                    tooltip: t('Remove photo'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      widget.photos.remove(p);
                      widget.onChanged();
                    },
                    icon: const Icon(FluentIcons.dismiss_16_filled, size: 16),
                  ),
                ),
            ]),
          ),
        if (!widget.locked && widget.photos.length < widget.max)
          Semantics(
            button: true,
            label: t('Add photo'),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _uploading ? null : _add,
              child: Container(
                width: 104,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outline),
                ),
                child: Center(
                  child: _uploading
                      ? const CircularProgressIndicator()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(FluentIcons.camera_add_24_regular, color: scheme.primary),
                          const SizedBox(height: 4),
                          Text(t('Add photo'), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                        ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
