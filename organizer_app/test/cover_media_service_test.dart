import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/services/cover_media_service.dart';

void main() {
  Uint8List jpeg() => Uint8List.fromList([0xff, 0xd8, ...List.filled(10, 0)]);
  Uint8List png() => Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, ...List.filled(8, 0)]);
  Uint8List webp() => Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]);

  group('CoverMediaService source validation', () {
    test('accepts JPEG source', () => expect(CoverMediaService.isSupportedRaster(jpeg()), isTrue));
    test('accepts PNG source', () => expect(CoverMediaService.isSupportedRaster(png()), isTrue));
    test('accepts WebP source', () => expect(CoverMediaService.isSupportedRaster(webp()), isTrue));
    test('rejects SVG source', () => expect(CoverMediaService.isSupportedRaster(Uint8List.fromList('<svg/>'.codeUnits)), isFalse));
    test('rejects unsupported source', () => expect(CoverMediaService.isSupportedRaster(Uint8List.fromList([1, 2, 3])), isFalse));
    test('defines a 5 MiB final-byte limit', () => expect(CoverMediaService.maxBytes, 5 * 1024 * 1024));
  });
}
