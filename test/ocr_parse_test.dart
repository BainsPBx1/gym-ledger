import 'package:flutter_test/flutter_test.dart';
import 'package:gym_ledger/services/ocr_service.dart';

void main() {
  test('parses a typical US-style label', () {
    const text = '''
Nutrition Facts
Serving Size 2/3 cup (55g)
Calories 230
Total Fat 8g
Saturated Fat 1g
Trans Fat 0g
Total Carbohydrate 37g
Protein 3g
''';
    final r = OcrService.parseLabelText(text);
    expect(r.calories, 230);
    expect(r.fatG, 8);
    expect(r.carbsG, 37);
    expect(r.proteinG, 3);
  });

  test('prefers kcal over kJ on EU-style energy rows', () {
    const text = '''
Energy 1046 kJ / 250 kcal
Fat 12 g
Carbohydrate 28 g
Protein 6.5 g
''';
    final r = OcrService.parseLabelText(text);
    expect(r.calories, 250);
    expect(r.proteinG, 6.5);
  });

  test('saturated fat does not clobber total fat', () {
    const text = '''
Calories 100
Saturated Fat 5g
Fat 9g
''';
    final r = OcrService.parseLabelText(text);
    expect(r.fatG, 9);
  });

  test('empty text finds nothing', () {
    final r = OcrService.parseLabelText('lorem ipsum');
    expect(r.foundAnything, isFalse);
  });
}
