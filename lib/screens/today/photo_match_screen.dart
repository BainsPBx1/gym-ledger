import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../logic/phash.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

/// Snap a photo of a meal logged before; a perceptual hash comparison
/// (entirely on-device) finds prior entries that look like it, and picking
/// one auto-fills the nutrients — no re-entry.
class PhotoMatchScreen extends ConsumerStatefulWidget {
  const PhotoMatchScreen({super.key});

  @override
  ConsumerState<PhotoMatchScreen> createState() => _PhotoMatchScreenState();
}

class _PhotoMatchScreenState extends ConsumerState<PhotoMatchScreen> {
  bool _busy = false;
  String? _newPhotoPath;
  String? _newPhotoHash;
  List<(MealLog, int)>? _matches; // (prior log, hamming distance)

  Future<void> _capture(ImageSource source) async {
    setState(() => _busy = true);
    final shot = await ImagePicker().pickImage(source: source);
    if (shot == null) {
      setState(() => _busy = false);
      return;
    }
    final photos = ref.read(photoServiceProvider);
    final hash = await photos.hashOf(shot.path);
    if (hash == null) {
      setState(() => _busy = false);
      return;
    }
    final prior = await ref.read(mealDaoProvider).withPhotoHashes();
    final scored = <(MealLog, int)>[];
    final seenNames = <String>{};
    for (final log in prior) {
      final d = hammingDistance(hash, log.photoHash!);
      if (d <= matchThreshold && seenNames.add(log.name)) {
        scored.add((log, d));
      }
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    setState(() {
      _busy = false;
      _newPhotoPath = shot.path;
      _newPhotoHash = hash;
      _matches = scored.take(5).toList();
    });
  }

  Future<void> _logMatch(MealLog prior) async {
    // Save the new photo (compressed) so it strengthens future matching.
    final saved = await ref
        .read(photoServiceProvider)
        .importPhoto(_newPhotoPath!, 'meals');
    await ref.read(mealDaoProvider).insert(MealLog(
          foodId: prior.foodId,
          name: prior.name,
          servings: prior.servings,
          calories: prior.calories,
          proteinG: prior.proteinG,
          carbsG: prior.carbsG,
          fatG: prior.fatG,
          loggedAt: DateTime.now(),
          photoPath: saved?.$1,
          photoHash: saved?.$2 ?? _newPhotoHash,
        ));
    ref.read(mealsVersionProvider.notifier).state++;
    if (mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${prior.name} logged')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('MATCH A MEAL')),
      body: LedgerBackground(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : _matches == null
                  ? _capturePrompt(c)
                  : _results(c),
        ),
      ),
    );
  }

  Widget _capturePrompt(LedgerColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.photo_camera_outlined, size: 72, color: c.accent),
        const SizedBox(height: 16),
        const Center(
          child: MonoLabel('Matched on this phone by look-alike photos',
              size: 11),
        ),
        const SizedBox(height: 40),
        StampButton(
            label: 'Snap the meal',
            onPressed: () => _capture(ImageSource.camera)),
        const SizedBox(height: 16),
        StampButton(
            label: 'Pick from photos',
            primary: false,
            rotation: 0.01,
            onPressed: () => _capture(ImageSource.gallery)),
        const SizedBox(height: 24),
        MonoLabel(
            'Tip: log meals with photos and matching gets better over time',
            size: 10,
            color: c.inkFaint),
      ],
    );
  }

  Widget _results(LedgerColors c) {
    final matches = _matches!;
    if (matches.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Center(
              child:
                  MonoLabel('No look-alikes in your ledger yet', size: 12)),
          const SizedBox(height: 24),
          StampButton(
              label: 'Try another photo',
              primary: false,
              onPressed: () => setState(() => _matches = null)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MonoLabel('Looks like…', size: 13),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final (log, dist) = matches[i];
              final closeness =
                  (100 * (1 - dist / matchThreshold)).clamp(0, 100).round();
              return LedgerCard(
                onTap: () => _logMatch(log),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (log.photoPath != null &&
                        File(log.photoPath!).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(File(log.photoPath!),
                            width: 56, height: 56, fit: BoxFit.cover),
                      )
                    else
                      Icon(Icons.restaurant, size: 40, color: c.inkFaint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          MonoLabel(
                            '${log.calories.round()} kcal · last '
                            '${DateFormat('d MMM').format(log.loggedAt)}',
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                    MonoLabel('~$closeness%', size: 12, color: c.secondary),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        StampButton(
            label: 'None of these',
            primary: false,
            onPressed: () => setState(() => _matches = null)),
      ],
    );
  }
}
