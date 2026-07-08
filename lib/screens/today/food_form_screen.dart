import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../services/ocr_service.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'log_meal_sheet.dart';

/// Create or edit a custom food. Every food in the app is user-created —
/// there is no pre-loaded database. Doubles as the editable confirmation
/// form for OCR results ([scanned]) and newly scanned barcodes ([barcode]).
class FoodFormScreen extends ConsumerStatefulWidget {
  final Food? existing;
  final String? barcode;
  final LabelScanResult? scanned;
  const FoodFormScreen({super.key, this.existing, this.barcode, this.scanned});

  @override
  ConsumerState<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends ConsumerState<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _tags;
  late final TextEditingController _serving;
  late final TextEditingController _cal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  bool _logAfterSave = false;

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    final s = widget.scanned;
    String num(double? v) => v == null
        ? ''
        : v == v.roundToDouble()
            ? '${v.round()}'
            : '$v';
    _name = TextEditingController(text: f?.name ?? '');
    _tags = TextEditingController(text: f?.tags ?? '');
    _serving = TextEditingController(text: f?.servingDesc ?? '1 serving');
    _cal = TextEditingController(text: num(f?.calories ?? s?.calories));
    _protein = TextEditingController(text: num(f?.proteinG ?? s?.proteinG));
    _carbs = TextEditingController(text: num(f?.carbsG ?? s?.carbsG));
    _fat = TextEditingController(text: num(f?.fatG ?? s?.fatG));
    _logAfterSave = widget.existing == null;
  }

  @override
  void dispose() {
    for (final c in [_name, _tags, _serving, _cal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    double parse(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
    final dao = ref.read(foodDaoProvider);
    final food = Food(
      id: widget.existing?.id,
      name: _name.text.trim(),
      barcode: widget.existing?.barcode ?? widget.barcode,
      tags: _tags.text.trim(),
      calories: parse(_cal),
      proteinG: parse(_protein),
      carbsG: parse(_carbs),
      fatG: parse(_fat),
      servingDesc: _serving.text.trim().isEmpty
          ? '1 serving'
          : _serving.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    Food saved = food;
    if (widget.existing == null) {
      final id = await dao.insert(food);
      saved = Food(
        id: id,
        name: food.name,
        barcode: food.barcode,
        tags: food.tags,
        calories: food.calories,
        proteinG: food.proteinG,
        carbsG: food.carbsG,
        fatG: food.fatG,
        servingDesc: food.servingDesc,
        createdAt: food.createdAt,
      );
    } else {
      await dao.update(food);
    }
    if (!mounted) return;
    if (_logAfterSave) {
      await logFood(context, ref, saved);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    final fromScan = widget.scanned != null;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null ? 'NEW FOOD' : 'EDIT FOOD')),
      body: LedgerBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (fromScan)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LedgerCard(
                    borderColor: c.secondary,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.document_scanner,
                            color: c.secondary, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: MonoLabel(
                              'Read from label — check before saving',
                              size: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.barcode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MonoLabel('Barcode ${widget.barcode} (local key only)',
                      size: 11),
                ),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name it' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated, optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serving,
                decoration: const InputDecoration(
                    labelText: 'Serving (e.g. 100 g, 1 scoop)'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numField(_cal, 'Calories', required: true)),
                const SizedBox(width: 12),
                Expanded(child: _numField(_protein, 'Protein g')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numField(_carbs, 'Carbs g')),
                const SizedBox(width: 12),
                Expanded(child: _numField(_fat, 'Fat g')),
              ]),
              const SizedBox(height: 16),
              if (widget.existing == null)
                SwitchListTile(
                  value: _logAfterSave,
                  onChanged: (v) => setState(() => _logAfterSave = v),
                  title: const Text('Log it right after saving'),
                  contentPadding: EdgeInsets.zero,
                ),
              const SizedBox(height: 16),
              StampButton(
                  label: widget.existing == null
                      ? 'Save to my library'
                      : 'Save changes',
                  onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label,
      {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontFamily: monoFont),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (!required && (v == null || v.trim().isEmpty)) return null;
        final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
        return (n == null || n < 0) ? 'Number' : null;
      },
    );
  }
}
