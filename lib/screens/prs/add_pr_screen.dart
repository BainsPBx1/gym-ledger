import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

/// Log a personal record — separate from regular set logging, with its own
/// celebratory treatment on save. Photo/video permission is requested here,
/// contextually, only if the user attaches media.
class AddPrScreen extends ConsumerStatefulWidget {
  const AddPrScreen({super.key});

  @override
  ConsumerState<AddPrScreen> createState() => _AddPrScreenState();
}

class _AddPrScreenState extends ConsumerState<AddPrScreen> {
  final _exercise = TextEditingController();
  final _weight = TextEditingController();
  DateTime _date = DateTime.now();
  String? _mediaPath; // picked, not yet imported
  String? _mediaType;

  @override
  void dispose() {
    _exercise.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool video) async {
    final picker = ImagePicker();
    final XFile? file = video
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      setState(() {
        _mediaPath = file.path;
        _mediaType = video ? 'video' : 'photo';
      });
    }
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    final name = _exercise.text.trim();
    if (weight == null || weight <= 0 || name.isEmpty) return;

    String? storedPath;
    if (_mediaPath != null) {
      final photos = ref.read(photoServiceProvider);
      if (_mediaType == 'photo') {
        storedPath = (await photos.importPhoto(_mediaPath!, 'prs'))?.$1;
      } else {
        storedPath = await photos.importVideo(_mediaPath!);
      }
    }

    final previousBest = await ref.read(prDaoProvider).bestFor(name);
    await ref.read(prDaoProvider).insert(PrEntry(
          exercise: name,
          weightKg: weight,
          date: _date,
          mediaPath: storedPath,
          mediaType: storedPath == null ? null : _mediaType,
        ));
    ref.read(prsVersionProvider.notifier).state++;
    if (!mounted) return;

    // The celebratory moment: full-screen NEW RECORD flash.
    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _CelebrationScreen(
          exercise: name,
          weightKg: weight,
          beatBy: previousBest == null ? null : weight - previousBest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('NEW RECORD')),
      body: LedgerBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _exercise,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Exercise'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontFamily: monoFont, fontSize: 22),
              decoration:
                  const InputDecoration(labelText: 'Weight', suffixText: 'kg'),
            ),
            const SizedBox(height: 12),
            LedgerCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Row(
                children: [
                  Icon(Icons.event, color: c.inkFaint),
                  const SizedBox(width: 12),
                  Text(DateFormat('EEE d MMM yyyy').format(_date),
                      style: const TextStyle(fontFamily: monoFont)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.ink, width: 2),
                        minimumSize: const Size(0, 52)),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Photo'),
                    onPressed: () => _pickMedia(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.ink, width: 2),
                        minimumSize: const Size(0, 52)),
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                    onPressed: () => _pickMedia(true),
                  ),
                ),
              ],
            ),
            if (_mediaPath != null) ...[
              const SizedBox(height: 12),
              if (_mediaType == 'photo')
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(_mediaPath!),
                      height: 180, fit: BoxFit.cover),
                )
              else
                const MonoLabel('Video attached', size: 11),
            ],
            const SizedBox(height: 24),
            StampButton(label: 'Stamp it', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Full-screen scoreboard flash shown once when a PR is saved.
class _CelebrationScreen extends StatefulWidget {
  final String exercise;
  final double weightKg;
  final double? beatBy;
  const _CelebrationScreen(
      {required this.exercise, required this.weightKg, this.beatBy});

  @override
  State<_CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<_CelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    final beat = widget.beatBy;
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: c.paper,
        body: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Stack(
              children: [
                CustomPaint(
                  size: MediaQuery.sizeOf(context),
                  painter: _SparkPainter(t: _ctrl.value, color: c.accent),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MonoLabel('* * * NEW RECORD * * *', size: 14),
                      const SizedBox(height: 12),
                      Transform.scale(
                        scale: 0.85 + 0.15 * Curves.elasticOut.transform(
                            (_ctrl.value * 2).clamp(0.0, 1.0)),
                        child: PixelNumber(
                          '${widget.weightKg == widget.weightKg.roundToDouble() ? widget.weightKg.round() : widget.weightKg} KG',
                          size: 96,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.exercise.toUpperCase(),
                          style: TextStyle(
                              fontFamily: monoFont,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: c.ink)),
                      if (beat != null && beat > 0) ...[
                        const SizedBox(height: 8),
                        MonoLabel(
                            '+${beat == beat.roundToDouble() ? beat.round() : beat.toStringAsFixed(1)} kg over your old best',
                            size: 12,
                            color: c.secondary),
                      ],
                      const SizedBox(height: 48),
                      const MonoLabel('tap to continue', size: 10),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final double t;
  final Color color;
  _SparkPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 40; i++) {
      final angle = rnd.nextDouble() * math.pi * 2;
      final speed = 0.25 + rnd.nextDouble() * 0.75;
      final dist = Curves.easeOut.transform(t) * speed * size.shortestSide;
      final cx = size.width / 2 + math.cos(angle) * dist;
      final cy = size.height / 2 + math.sin(angle) * dist;
      final fade = (1 - t).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: fade * 0.9);
      // Pixel-style square sparks.
      final s = 3.0 + rnd.nextDouble() * 4;
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: s, height: s), paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}
