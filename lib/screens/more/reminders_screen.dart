import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

/// Gym-window reminders. No location permission, no geofencing — just
/// recurring time windows. If no workout has started by the reminder point
/// inside a window, a local notification fires.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(gymWindowsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GYM REMINDERS')),
      body: LedgerBackground(
        child: windows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const MonoLabel(
                  'No location tracking — pick when you plan to train and '
                  "we'll nudge you if nothing's logged",
                  size: 11),
              const SizedBox(height: 16),
              for (final w in list) ...[
                _WindowCard(window: w),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              StampButton(
                label: '+ Add a window',
                onPressed: () => _editWindow(context, ref, null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowCard extends ConsumerWidget {
  final GymWindow window;
  const _WindowCard({required this.window});

  static const _dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = [
      for (var i = 0; i < 7; i++)
        if ((window.daysMask & (1 << i)) != 0) _dayNames[i]
    ].join(' ');
    return LedgerCard(
      onTap: () => _editWindow(context, ref, window),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_fmt(window.startMinute)} – ${_fmt(window.endMinute)}',
                    style: const TextStyle(
                        fontFamily: monoFont,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                MonoLabel(
                    '$days · nudge after ${window.remindAfterMinutes} min',
                    size: 10),
              ],
            ),
          ),
          Switch(
            value: window.enabled,
            onChanged: (v) async {
              await ref.read(gymWindowDaoProvider).update(GymWindow(
                    id: window.id,
                    daysMask: window.daysMask,
                    startMinute: window.startMinute,
                    endMinute: window.endMinute,
                    remindAfterMinutes: window.remindAfterMinutes,
                    enabled: v,
                  ));
              ref.read(workoutsVersionProvider.notifier).state++;
              await _reschedule(ref);
            },
          ),
        ],
      ),
    );
  }

  String _fmt(int minute) {
    final h = minute ~/ 60, m = minute % 60;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return m == 0 ? '$h12 $ampm' : '$h12:${m.toString().padLeft(2, '0')} $ampm';
  }
}

Future<void> _reschedule(WidgetRef ref) async {
  final windows = await ref.read(gymWindowDaoProvider).all();
  final worked = await ref.read(statsDaoProvider).workedOutToday();
  await ref
      .read(notificationServiceProvider)
      .rescheduleAll(windows, workedOutToday: worked);
}

Future<void> _editWindow(
    BuildContext context, WidgetRef ref, GymWindow? existing) async {
  var daysMask = existing?.daysMask ?? 0x15; // Mon/Wed/Fri
  var start = TimeOfDay(
      hour: (existing?.startMinute ?? 17 * 60) ~/ 60,
      minute: (existing?.startMinute ?? 17 * 60) % 60);
  var end = TimeOfDay(
      hour: (existing?.endMinute ?? 19 * 60) ~/ 60,
      minute: (existing?.endMinute ?? 19 * 60) % 60);
  var remindAfter = existing?.remindAfterMinutes ?? 30;
  const dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  final saved = await showDialog<bool>(
    context: context,
    builder: (dCtx) => StatefulBuilder(
      builder: (dCtx, setState) {
        final c = dCtx.ledger;
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: c.ink, width: 2),
          ),
          title: Text(existing == null ? 'New gym window' : 'Edit window'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(dayNames[i],
                          style: const TextStyle(fontFamily: monoFont)),
                      selected: (daysMask & (1 << i)) != 0,
                      onSelected: (_) =>
                          setState(() => daysMask ^= (1 << i)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: dCtx, initialTime: start);
                        if (t != null) setState(() => start = t);
                      },
                      child: Text('From ${start.format(dCtx)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: dCtx, initialTime: end);
                        if (t != null) setState(() => end = t);
                      },
                      child: Text('To ${end.format(dCtx)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Nudge after')),
                  DropdownButton<int>(
                    value: remindAfter,
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                    ],
                    onChanged: (v) => setState(() => remindAfter = v ?? 30),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await ref.read(gymWindowDaoProvider).delete(existing.id!);
                  if (dCtx.mounted) Navigator.pop(dCtx, false);
                },
                child: Text('Delete',
                    style: TextStyle(color: dCtx.ledger.negative)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('Save')),
          ],
        );
      },
    ),
  );

  if (saved == true && daysMask != 0) {
    final dao = ref.read(gymWindowDaoProvider);
    final w = GymWindow(
      id: existing?.id,
      daysMask: daysMask,
      startMinute: start.hour * 60 + start.minute,
      endMinute: end.hour * 60 + end.minute,
      remindAfterMinutes: remindAfter,
      enabled: existing?.enabled ?? true,
    );
    if (existing == null) {
      // Contextual permission ask — the first moment notifications matter.
      await ref.read(notificationServiceProvider).requestPermission();
      await dao.insert(w);
    } else {
      await dao.update(w);
    }
  }
  ref.read(workoutsVersionProvider.notifier).state++;
  await _reschedule(ref);
}
