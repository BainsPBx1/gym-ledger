import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'barcode_scan_screen.dart';
import 'food_form_screen.dart';
import 'food_picker_screen.dart';
import 'label_scan_screen.dart';
import 'photo_match_screen.dart';

/// Entry points for logging a meal. Everything stays on-device: the library
/// is user-built, barcodes are local keys, OCR runs offline.
void showLogMealSheet(BuildContext context, WidgetRef ref) {
  final c = context.ledger;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.card,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      side: BorderSide(color: c.ink, width: 2),
    ),
    builder: (sheetCtx) {
      Widget option(IconData icon, String title, String subtitle,
          Widget Function() screen) {
        return ListTile(
          minVerticalPadding: 14,
          leading: Icon(icon, color: c.accent, size: 28),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          subtitle: MonoLabel(subtitle, size: 10),
          onTap: () {
            Navigator.pop(sheetCtx);
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => screen()));
          },
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const SizedBox(height: 12),
            const MonoLabel('Log a meal', size: 13),
            const SizedBox(height: 4),
            option(Icons.menu_book, 'From my library',
                'Foods you saved before', () => const FoodPickerScreen()),
            option(Icons.qr_code_scanner, 'Scan barcode',
                'Local lookup only — never sent anywhere',
                () => const BarcodeScanScreen()),
            option(Icons.document_scanner, 'Scan nutrition label',
                'On-device OCR, works offline', () => const LabelScanScreen()),
            option(Icons.photo_camera, 'Match a meal photo',
                'Auto-fill from a meal you logged before',
                () => const PhotoMatchScreen()),
              option(Icons.add_box, 'New food',
                  'Type it in yourself', () => const FoodFormScreen()),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

/// Servings prompt shown after picking a food; logs the meal on confirm.
Future<void> logFood(BuildContext context, WidgetRef ref, Food food,
    {String? photoPath, String? photoHash}) async {
  final ctrl = TextEditingController(text: '1');
  final servings = await showDialog<double>(
    context: context,
    builder: (dCtx) => AlertDialog(
      backgroundColor: dCtx.ledger.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: dCtx.ledger.ink, width: 2),
      ),
      title: Text(food.name),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontFamily: monoFont, fontSize: 20),
        decoration: InputDecoration(
            labelText: 'Servings (${food.servingDesc})'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () =>
              Navigator.pop(dCtx, double.tryParse(ctrl.text.trim()) ?? 1),
          child: const Text('Log it'),
        ),
      ],
    ),
  );
  if (servings == null || servings <= 0) return;

  await ref.read(mealDaoProvider).insert(MealLog(
        foodId: food.id,
        name: food.name,
        servings: servings,
        calories: food.calories * servings,
        proteinG: food.proteinG * servings,
        carbsG: food.carbsG * servings,
        fatG: food.fatG * servings,
        loggedAt: DateTime.now(),
        photoPath: photoPath,
        photoHash: photoHash,
      ));
  ref.read(mealsVersionProvider.notifier).state++;
  if (context.mounted) {
    Navigator.popUntil(context, (r) => r.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${food.name} logged')));
  }
}
