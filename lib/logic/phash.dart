import 'package:image/image.dart' as img;

/// Difference-hash (dHash) perceptual image hashing, fully on-device.
/// Used for meal photo matching: a new photo's hash is compared against the
/// hashes of previously logged meal photos; close hashes are offered as
/// matches so nutrients can be auto-filled without re-entry.

/// 64-bit dHash as a 16-char hex string.
String dHash(img.Image image) {
  final small = img.copyResize(image,
      width: 9, height: 8, interpolation: img.Interpolation.average);
  final gray = img.grayscale(small);
  var bits = BigInt.zero;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final left = gray.getPixel(x, y).r;
      final right = gray.getPixel(x + 1, y).r;
      bits = (bits << 1) | (left > right ? BigInt.one : BigInt.zero);
    }
  }
  return bits.toRadixString(16).padLeft(16, '0');
}

/// Hamming distance between two hex hashes (0 = identical, 64 = opposite).
int hammingDistance(String a, String b) {
  var x = BigInt.parse(a, radix: 16) ^ BigInt.parse(b, radix: 16);
  var count = 0;
  while (x > BigInt.zero) {
    count += (x & BigInt.one).toInt();
    x >>= 1;
  }
  return count;
}

/// Distance at or below which two meal photos are considered a likely match.
const int matchThreshold = 12;
