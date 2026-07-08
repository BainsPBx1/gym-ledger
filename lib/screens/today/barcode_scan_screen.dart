import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'food_form_screen.dart';
import 'log_meal_sheet.dart';

/// Scans a barcode and treats it purely as a local key into the user's own
/// food library. Nothing is ever looked up externally. A known barcode goes
/// straight to logging; an unknown one opens the new-food form keyed to it.
/// Camera permission is requested here, contextually, by the scanner itself.
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  bool _handling = false;
  final _manualCtrl = TextEditingController();

  bool get _cameraSupported => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCode(String code) async {
    if (_handling || code.isEmpty) return;
    _handling = true;
    final existing = await ref.read(foodDaoProvider).byBarcode(code);
    if (!mounted) return;
    if (existing != null) {
      await logFood(context, ref, existing);
    } else {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FoodFormScreen(barcode: code)),
      );
    }
    _handling = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('SCAN BARCODE')),
      body: LedgerBackground(
        child: Column(
          children: [
            if (_cameraSupported)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MobileScanner(
                      onDetect: (capture) {
                        final code = capture.barcodes.firstOrNull?.rawValue;
                        if (code != null) _onCode(code);
                      },
                    ),
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: MonoLabel('Camera scanning not available here',
                      size: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MonoLabel('Or type the code', size: 11),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualCtrl,
                          style: const TextStyle(fontFamily: monoFont),
                          decoration:
                              const InputDecoration(labelText: 'Barcode'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                            backgroundColor: c.accent,
                            foregroundColor: c.onAccent,
                            minimumSize: const Size(56, 56)),
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => _onCode(_manualCtrl.text.trim()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MonoLabel('Codes are local IDs — never looked up online',
                      size: 10, color: c.inkFaint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
