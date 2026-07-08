import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'food_form_screen.dart';
import 'log_meal_sheet.dart';

/// The user's own food library — searchable by name or tag.
class FoodPickerScreen extends ConsumerStatefulWidget {
  const FoodPickerScreen({super.key});

  @override
  ConsumerState<FoodPickerScreen> createState() => _FoodPickerScreenState();
}

class _FoodPickerScreenState extends ConsumerState<FoodPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('MY LIBRARY')),
      body: LedgerBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search name or tag',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Food>>(
                future: _query.isEmpty
                    ? ref.read(foodDaoProvider).all()
                    : ref.read(foodDaoProvider).search(_query),
                builder: (context, snap) {
                  final foods = snap.data ?? const <Food>[];
                  if (snap.connectionState == ConnectionState.done &&
                      foods.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MonoLabel(
                              _query.isEmpty
                                  ? 'Library is empty — every food here is yours'
                                  : 'No matches',
                              size: 12,
                              color: c.inkFaint),
                          const SizedBox(height: 16),
                          StampButton(
                            label: 'Create a food',
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const FoodFormScreen())),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: foods.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final f = foods[i];
                      return LedgerCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        onTap: () => logFood(context, ref, f),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  MonoLabel(
                                    '${f.servingDesc} · P${f.proteinG.round()} '
                                    'C${f.carbsG.round()} F${f.fatG.round()}'
                                    '${f.tags.isNotEmpty ? ' · ${f.tags}' : ''}',
                                    size: 10,
                                  ),
                                ],
                              ),
                            ),
                            Text('${f.calories.round()}',
                                style: TextStyle(
                                    fontFamily: monoFont,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: c.ink)),
                            const MonoLabel(' kcal', size: 10),
                            IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  size: 20, color: c.inkFaint),
                              tooltip: 'Edit food',
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          FoodFormScreen(existing: f))),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
