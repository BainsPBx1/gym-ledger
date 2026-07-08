import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logic/phash.dart';

/// Stores photos inside the app's documents dir, compressed on save
/// (max 1280px long edge, JPEG q80), and computes their perceptual hash.
class PhotoService {
  Future<Directory> _photoDir(String subdir) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'gym_ledger', subdir));
    await dir.create(recursive: true);
    return dir;
  }

  /// Compresses [sourcePath] into app storage. Returns (savedPath, dHash).
  /// [subdir] is one of 'meals', 'prs'.
  Future<(String, String)?> importPhoto(String sourcePath, String subdir) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    var image = decoded;
    const maxEdge = 1280;
    if (image.width > maxEdge || image.height > maxEdge) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxEdge)
          : img.copyResize(image, height: maxEdge);
    }
    final hash = dHash(image);
    final dir = await _photoDir(subdir);
    final path = p.join(
        dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 80));
    return (path, hash);
  }

  /// Copies a video into app storage unmodified (no re-encode on device).
  Future<String> importVideo(String sourcePath) async {
    final dir = await _photoDir('prs');
    final ext = p.extension(sourcePath);
    final path = p.join(
        dir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(sourcePath).copy(path);
    return path;
  }

  /// Hash of an image file without saving it (for photo-match lookups).
  Future<String?> hashOf(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    return decoded == null ? null : dHash(decoded);
  }
}
