import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Values pulled off a nutrition label photo. Everything lands in an
/// editable confirmation form before anything is saved.
class LabelScanResult {
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String rawText;
  const LabelScanResult({
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.rawText = '',
  });

  bool get foundAnything =>
      calories != null || proteinG != null || carbsG != null || fatG != null;
}

/// On-device OCR (ML Kit on Android, which delegates to the Vision framework
/// path on iOS via the same plugin). No network involved; supported only on
/// mobile — [isSupported] gates the UI elsewhere.
class OcrService {
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<LabelScanResult> scanLabel(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(input);
      return parseLabelText(recognized.text);
    } finally {
      await recognizer.close();
    }
  }

  /// Pulls calories/macros out of raw label text. Pure function, unit-tested
  /// separately from the platform OCR call.
  static LabelScanResult parseLabelText(String text) {
    final lines = text.toLowerCase().split('\n');

    double? calories, protein, carbs, fat;
    final numberRe = RegExp(r'(\d+(?:[.,]\d+)?)');

    double? firstNumber(String line) {
      final m = numberRe.firstMatch(line);
      return m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', '.'));
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // A label line's value is usually on the same line; occasionally the
      // number wraps onto the next line.
      double? value = firstNumber(line.replaceAll(RegExp(r'(per\s*100\s*g?|serving)'), ''));
      value ??= i + 1 < lines.length ? firstNumber(lines[i + 1]) : null;
      if (value == null) continue;

      if (calories == null &&
          (line.contains('calorie') || line.contains('kcal') ||
              line.contains('energy'))) {
        // Energy rows often list kJ first; prefer an explicit kcal figure.
        final kcalMatch =
            RegExp(r'(\d+(?:[.,]\d+)?)\s*kcal').firstMatch(line);
        calories = kcalMatch != null
            ? double.tryParse(kcalMatch.group(1)!.replaceAll(',', '.'))
            : value;
      } else if (protein == null && line.contains('protein')) {
        protein = value;
      } else if (carbs == null && line.contains('carbohydrate')) {
        carbs = value;
      } else if (carbs == null && line.contains('carb')) {
        carbs = value;
      } else if (fat == null &&
          line.contains('fat') &&
          !line.contains('saturat') &&
          !line.contains('trans')) {
        fat = value;
      }
    }

    return LabelScanResult(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      rawText: text,
    );
  }
}
