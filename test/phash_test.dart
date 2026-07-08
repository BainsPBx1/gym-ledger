import 'package:flutter_test/flutter_test.dart';
import 'package:gym_ledger/logic/phash.dart';
import 'package:image/image.dart' as img;

img.Image _gradient({int seed = 0, int w = 200, int h = 150}) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(
          x, y, (x + seed * 3) % 256, (y * 2 + seed) % 256, (x + y) % 256);
    }
  }
  return image;
}

void main() {
  test('hash is stable and 16 hex chars', () {
    final a = dHash(_gradient());
    expect(a, dHash(_gradient()));
    expect(a.length, 16);
  });

  test('resized version of the same image matches', () {
    final original = _gradient();
    final resized = img.copyResize(original, width: 90);
    final d = hammingDistance(dHash(original), dHash(resized));
    expect(d, lessThanOrEqualTo(matchThreshold));
  });

  test('unrelated images do not match', () {
    // Vertical vs horizontal gradient — structurally opposite.
    final a = img.Image(width: 100, height: 100);
    final b = img.Image(width: 100, height: 100);
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 100; x++) {
        a.setPixelRgb(x, y, (x * 255) ~/ 99, (x * 255) ~/ 99, (x * 255) ~/ 99);
        b.setPixelRgb(x, y, ((99 - x) * 255) ~/ 99, ((99 - x) * 255) ~/ 99,
            ((99 - x) * 255) ~/ 99);
      }
    }
    expect(hammingDistance(dHash(a), dHash(b)), greaterThan(matchThreshold));
  });

  test('hamming distance basics', () {
    expect(hammingDistance('0000000000000000', '0000000000000000'), 0);
    expect(hammingDistance('0000000000000000', '000000000000000f'), 4);
    expect(hammingDistance('ffffffffffffffff', '0000000000000000'), 64);
  });
}
