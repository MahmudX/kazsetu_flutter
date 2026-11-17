import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kazsetu_mobile/api.dart';
import 'package:kazsetu_mobile/ui.dart';

// A 1x1 PNG.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

Future<void> _load(DiskImage image) {
  final done = Completer<void>();
  image
      .loadImage(image, PaintingBinding.instance.instantiateImageCodecWithSize)
      .addListener(ImageStreamListener((_, _) => done.complete(), onError: done.completeError));
  return done.future;
}

void main() {
  testWidgets('a photo is downloaded once, then read from the phone', (tester) async {
    var downloads = 0;
    // The app's session (and so its HTTP client) is created on first use: here, with a fake server.
    http.runWithClient(() => session, () => MockClient((_) async {
          downloads++;
          return http.Response.bytes(_png, 200);
        }));
    final url = 'https://example.test/photo-${DateTime.now().microsecondsSinceEpoch}.png';

    await tester.runAsync(() async {
      // Tests have no Android cache directory; use a temporary one.
      DiskImage.folder = Future.value(await Directory.systemTemp.createTemp('photos'));
      await _load(DiskImage(url));
      await _load(DiskImage(url));
      expect(downloads, 1);

      // Pruning to zero bytes empties the cache, so the next view downloads again.
      await pruneDiskImages(maxBytes: 0);
      expect(await (await DiskImage.folder).list().where((e) => e is File).isEmpty, isTrue);
      await _load(DiskImage(url));
      expect(downloads, 2);
    });
  });
}
