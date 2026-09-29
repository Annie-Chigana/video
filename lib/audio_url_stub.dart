import 'dart:typed_data';

/// Not used outside web (mobile/desktop play from the file path).
String createAudioUrl(Uint8List bytes, String? fileName) =>
    throw UnsupportedError('Blob URLs are only available on web');

void revokeAudioUrl(String url) {}