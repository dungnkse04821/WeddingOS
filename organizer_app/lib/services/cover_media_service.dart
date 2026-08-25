import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'supabase_service.dart';

class CoverMediaService {
  static const _bucket = 'wedding_media';
  static const maxBytes = 5 * 1024 * 1024;
  final ImagePicker _picker;
  CoverMediaService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  Future<Uint8List?> pickAndOptimize() async {
    final source = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (source == null) return null;
    final bytes = await source.readAsBytes();
    if (!isSupportedRaster(bytes)) throw const FormatException('IMAGE_NOT_SUPPORTED');
    final output = await FlutterImageCompress.compressWithList(bytes, format: CompressFormat.webp, minWidth: 1440, minHeight: 1440, quality: 88);
    if (output.length > maxBytes) throw const FormatException('IMAGE_TOO_LARGE');
    return Uint8List.fromList(output);
  }

  Future<void> upload(String weddingId, Uint8List webp) async {
    if (webp.length > maxBytes) throw const FormatException('IMAGE_TOO_LARGE');
    await SupabaseService.instance.client.storage.from(_bucket).uploadBinary(
      'weddings/$weddingId/cover.webp', webp,
      fileOptions: const FileOptions(
        contentType: 'image/webp',
        upsert: true,
        cacheControl: '3600',
      ),
    );
  }

  Future<String?> loadSignedUrl(String weddingId) async {
    try {
      return await SupabaseService.instance.client.storage
          .from(_bucket)
          .createSignedUrl(_coverPath(weddingId), 1800);
    } catch (_) {
      return null;
    }
  }

  static String _coverPath(String weddingId) => 'weddings/$weddingId/cover.webp';

  static bool isSupportedRaster(Uint8List b) => b.length >= 12 &&
    ((b[0] == 0xff && b[1] == 0xd8) ||
     (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47) ||
     (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50));
}
