import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'food_form_screen.dart';

/// Photograph a nutrition label; on-device OCR (fully offline) extracts
/// calories/macros, which land in the editable confirmation form — nothing
/// is saved until the user reviews it. Camera permission is requested here,
/// at the moment it's needed.
class LabelScanScreen extends ConsumerStatefulWidget {
  const LabelScanScreen({super.key});

  @override
  ConsumerState<LabelScanScreen> createState() => _LabelScanScreenState();
}

class _LabelScanScreenState extends ConsumerState<LabelScanScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _capture(ImageSource source) async {
    final ocr = ref.read(ocrServiceProvider);
    if (!ocr.isSupported) {
      setState(() => _error = 'On-device OCR is only available on the phone.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shot = await ImagePicker().pickImage(source: source);
      if (shot == null) {
        setState(() => _busy = false);
        return;
      }
      final result = await ocr.scanLabel(shot.path);
      if (!mounted) return;
      if (!result.foundAnything) {
        setState(() {
          _busy = false;
          _error =
              "Couldn't read numbers off that label — try a straighter, closer shot, or enter it manually.";
        });
        return;
      }
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FoodFormScreen(scanned: result)),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Scan failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('SCAN LABEL')),
      body: LedgerBackground(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.document_scanner_outlined, size: 72, color: c.accent),
              const SizedBox(height: 16),
              const Center(
                child: MonoLabel(
                    'OCR runs on this phone. No network. No upload.',
                    size: 11),
              ),
              const SizedBox(height: 40),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else ...[
                StampButton(
                    label: 'Photograph the label',
                    onPressed: () => _capture(ImageSource.camera)),
                const SizedBox(height: 16),
                StampButton(
                    label: 'Pick from photos',
                    primary: false,
                    rotation: 0.01,
                    onPressed: () => _capture(ImageSource.gallery)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 24),
                LedgerCard(
                  borderColor: c.negative,
                  child: Text(_error!,
                      style: TextStyle(color: c.negative, fontSize: 14)),
                ),
                const SizedBox(height: 16),
                StampButton(
                  label: 'Enter manually instead',
                  primary: false,
                  onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FoodFormScreen())),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
