import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'workout_screen.dart' show weekdayFull;

/// The guided workout: everything was preset at home, so at the gym the user
/// just follows along. Each set shows its planned weight x reps pre-filled —
/// only the actuals get adjusted — DONE logs it (locked, permanently), the
/// rest countdown runs, and when it ends the app asks before starting the
/// next set: play when ready, or add more time.
class GuidedSessionScreen extends ConsumerStatefulWidget {
  final Split split;
  final int weekday;
  final List<PlanExercise> exercises;
  const GuidedSessionScreen({
    super.key,
    required this.split,
    required this.weekday,
    required this.exercises,
  });

  @override
  ConsumerState<GuidedSessionScreen> createState() =>
      _GuidedSessionScreenState();
}

enum _Phase { working, resting, done }

class _GuidedSessionScreenState extends ConsumerState<GuidedSessionScreen> {
  int? _sessionId;
  final Map<int, List<PlanSet>> _plans = {}; // exerciseId -> preset sets

  var _phase = _Phase.working;
  int _exerciseIndex = 0;
  int _setIndex = 0;
  int _loggedCount = 0;
  late final DateTime _startedAt;

  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();

  Timer? _timer;
  int _restRemaining = 0;
  bool _restOver = false;

  PlanExercise get _exercise => widget.exercises[_exerciseIndex];
  List<PlanSet> get _sets => _plans[_exercise.id] ?? const [];

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _begin();
  }

  Future<void> _begin() async {
    final dao = ref.read(splitDaoProvider);
    for (final e in widget.exercises) {
      final sets = await dao.setsFor(e.id!);
      _plans[e.id!] = sets.isEmpty
          ? [
              // Unplanned exercise still gets 3 generic sets.
              for (var i = 0; i < 3; i++)
                PlanSet(
                    exerciseId: e.id!,
                    setIndex: i,
                    targetWeightKg: 0,
                    targetReps: 8)
            ]
          : sets;
    }
    _sessionId = await ref.read(workoutDaoProvider).startSession(WorkoutSession(
          templateName:
              '${widget.split.name} · ${weekdayFull[widget.weekday - 1]}',
          startedAt: _startedAt,
        ));
    ref.read(workoutsVersionProvider.notifier).state++;
    // A workout has started — today's gym-window reminder is now moot.
    final windows = await ref.read(gymWindowDaoProvider).all();
    if (windows.isNotEmpty) {
      await ref
          .read(notificationServiceProvider)
          .rescheduleAll(windows, workedOutToday: true);
    }
    if (mounted) setState(_prefill);
  }

  void _prefill() {
    final plan = _setIndex < _sets.length ? _sets[_setIndex] : null;
    final w = plan?.targetWeightKg ?? 0;
    _weightCtrl.text =
        w == 0 ? '' : (w == w.roundToDouble() ? '${w.round()}' : '$w');
    _repsCtrl.text = '${plan?.targetReps ?? 8}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  bool get _isLastSetOfExercise => _setIndex >= _sets.length - 1;
  bool get _isLastExercise => _exerciseIndex >= widget.exercises.length - 1;

  String? get _upNextLabel {
    if (!_isLastSetOfExercise) {
      return '${_exercise.name} — set ${_setIndex + 2} of ${_sets.length}';
    }
    if (!_isLastExercise) {
      return widget.exercises[_exerciseIndex + 1].name;
    }
    return null;
  }

  Future<void> _logSet() async {
    if (_sessionId == null) return;
    final weight =
        double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'));
    final reps = int.tryParse(_repsCtrl.text.trim());
    if (weight == null || reps == null || reps <= 0) return;

    await ref.read(workoutDaoProvider).logSet(SetLog(
          sessionId: _sessionId!,
          exercise: _exercise.name,
          weightKg: weight,
          reps: reps,
          loggedAt: DateTime.now(),
        ));
    _loggedCount++;
    ref.read(workoutsVersionProvider.notifier).state++;

    if (_isLastSetOfExercise && _isLastExercise) {
      await _finish();
      return;
    }
    // Rest, then ask before the next set starts.
    setState(() {
      _phase = _Phase.resting;
      _restRemaining = _exercise.restSeconds;
      _restOver = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_restRemaining > 1) {
          _restRemaining--;
        } else {
          _restRemaining = 0;
          _restOver = true; // countdown done — now it asks; user hits play
          _timer?.cancel();
        }
      });
    });
  }

  void _startNextSet() {
    _timer?.cancel();
    setState(() {
      if (_isLastSetOfExercise) {
        _exerciseIndex++;
        _setIndex = 0;
      } else {
        _setIndex++;
      }
      _phase = _Phase.working;
      _prefill();
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    if (_sessionId != null) {
      await ref.read(workoutDaoProvider).endSession(_sessionId!, DateTime.now());
      ref.read(workoutsVersionProvider.notifier).state++;
    }
    if (mounted) setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return PopScope(
      canPop: _phase == _Phase.done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Leaving mid-workout ends the session; logged sets stay (locked).
        final leave = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('End workout?'),
            content: Text(
                '$_loggedCount set${_loggedCount == 1 ? '' : 's'} already in the ledger — those stay.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('Keep going')),
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text('End it')),
            ],
          ),
        );
        if (leave == true && mounted) {
          await _finish();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: LedgerBackground(
          child: SafeArea(
            child: switch (_phase) {
              _Phase.working => _workingView(c),
              _Phase.resting => _restingView(c),
              _Phase.done => _doneView(c),
            },
          ),
        ),
      ),
    );
  }

  Widget _workingView(LedgerColors c) {
    if (_sessionId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final plan = _setIndex < _sets.length ? _sets[_setIndex] : null;
    String trim(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoLabel(
              'Exercise ${_exerciseIndex + 1}/${widget.exercises.length} · ${widget.split.name}',
              size: 11),
          const SizedBox(height: 12),
          Text(_exercise.name,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          PixelNumber('SET ${_setIndex + 1} OF ${_sets.length}', size: 40),
          if (plan != null && plan.targetWeightKg > 0) ...[
            const SizedBox(height: 4),
            MonoLabel(
                'planned ${trim(plan.targetWeightKg)} kg × ${plan.targetReps}',
                size: 12,
                color: c.secondary),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: monoFont, fontSize: 30),
                  decoration: const InputDecoration(labelText: 'kg'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('×',
                    style: TextStyle(fontSize: 28, color: c.inkFaint)),
              ),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _repsCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: monoFont, fontSize: 30),
                  decoration: const InputDecoration(labelText: 'reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MonoLabel('Adjust to what you actually lifted — then stamp it',
              size: 10, color: c.inkFaint),
          const Spacer(),
          SizedBox(
            height: 64,
            child: StampButton(label: '✓ Done — log set', onPressed: _logSet),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: Text('End workout',
                  style: TextStyle(color: c.inkFaint)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _restingView(LedgerColors c) {
    final m = _restRemaining ~/ 60;
    final s = _restRemaining % 60;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Center(
              child: MonoLabel(_restOver ? 'READY?' : 'REST', size: 16)),
          const Spacer(),
          Center(
            child: _restOver
                ? Column(
                    children: [
                      Icon(Icons.play_circle_outline,
                          size: 96, color: c.accent),
                      const SizedBox(height: 8),
                      const MonoLabel('rest over — start when ready', size: 12),
                    ],
                  )
                : PixelNumber('$m:${s.toString().padLeft(2, '0')}', size: 140),
          ),
          const SizedBox(height: 24),
          if (_upNextLabel != null)
            Center(
              child: Column(
                children: [
                  const MonoLabel('up next', size: 11),
                  const SizedBox(height: 4),
                  Text(_upNextLabel!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: c.ink)),
                ],
              ),
            ),
          const Spacer(),
          if (!_restOver)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: StampButton(
                      label: '-15s',
                      primary: false,
                      onPressed: () => setState(() {
                        _restRemaining = (_restRemaining - 15).clamp(0, 5940);
                        if (_restRemaining == 0) {
                          _restOver = true;
                          _timer?.cancel();
                        }
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: StampButton(
                      label: '+15s',
                      primary: false,
                      rotation: 0.01,
                      onPressed: () =>
                          setState(() => _restRemaining += 15),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 56,
              child: StampButton(
                label: '+30s more rest',
                primary: false,
                onPressed: () => setState(() {
                  _restOver = false;
                  _restRemaining = 30;
                  _timer?.cancel();
                  _timer =
                      Timer.periodic(const Duration(seconds: 1), (_) {
                    if (!mounted) return;
                    setState(() {
                      if (_restRemaining > 1) {
                        _restRemaining--;
                      } else {
                        _restRemaining = 0;
                        _restOver = true;
                        _timer?.cancel();
                      }
                    });
                  });
                }),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: StampButton(
              label: '▶ Start next set',
              rotation: 0.012,
              onPressed: _startNextSet,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _doneView(LedgerColors c) {
    final mins = DateTime.now().difference(_startedAt).inMinutes;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Center(child: MonoLabel('WORKOUT COMPLETE', size: 14)),
          const SizedBox(height: 16),
          Center(child: PixelNumber('$_loggedCount', size: 110)),
          const Center(child: MonoLabel('sets in the ledger', size: 12)),
          const SizedBox(height: 12),
          Center(
            child: MonoLabel(
                '${widget.split.name} · ${weekdayFull[widget.weekday - 1]} · $mins min',
                size: 11,
                color: c.inkFaint),
          ),
          const Spacer(),
          SizedBox(
            height: 60,
            child: StampButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
