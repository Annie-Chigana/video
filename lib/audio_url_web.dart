import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

String _mimeFor(String? name) {
  final ext = (name ?? '').toLowerCase().split('.').last;
  switch (ext) {
    case 'm4a':
    case 'mp4':
    case 'aac':
      return 'audio/mp4';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
    case 'oga':
      return 'audio/ogg';
    case 'flac':
      return 'audio/flac';
    default:
      return 'audio/mpeg';
  }
}

/// Wraps the bytes in a browser Blob and returns a `blob:` URL.
/// Instant, and no base64 encoding on the main thread.
String createAudioUrl(Uint8List bytes, String? fileName) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: _mimeFor(fileName)),
  );
  return web.URL.createObjectURL(blob);
}

void revokeAudioUrl(String url) => web.URL.revokeObjectURL(url);