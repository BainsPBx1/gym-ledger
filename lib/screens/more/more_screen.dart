import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'reminders_screen.dart';
import 'storage_screen.dart';
import 'targets_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    final settings = ref.watch(settingsProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();

    // Gentle backup nudge — there is no cloud safety net by design.
    final lastExport = settings.lastExportAt;
    final exportStale = lastExport == null ||
        DateTime.now().difference(lastExport).inDays >= 30;

    Future<void> export(bool asJson) async {
      final path = await ref
          .read(exportServiceProvider)
          .exportToFile(asJson: asJson);
      if (path != null) {
        await ref
            .read(settingsProvider.notifier)
            .save(settings.copyWith(lastExportAt: DateTime.now()));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Backed up to $path')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('MORE')),
      body: LedgerBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (exportStale)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LedgerCard(
                  borderColor: c.accent,
                  child: Row(
                    children: [
                      Icon(Icons.save_alt, color: c.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lastExport == null
                              ? "Your data lives only on this phone. Worth saving a backup file when you get a minute."
                              : 'Last backup was ${DateFormat('d MMM').format(lastExport)} — a fresh one wouldn\'t hurt.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const MonoLabel('Plan', size: 12),
            const SizedBox(height: 8),
            _tile(context, Icons.track_changes, 'Targets',
                '${settings.targets.calories} kcal · P${settings.targets.proteinG} C${settings.targets.carbsG} F${settings.targets.fatG}',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TargetsScreen()))),
            const SizedBox(height: 8),
            _tile(context, Icons.notifications_outlined, 'Gym reminders',
                'Time windows, no location tracking',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RemindersScreen()))),
            const SizedBox(height: 20),
            const MonoLabel('Appearance', size: 12),
            const SizedBox(height: 8),
            LedgerCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: RadioGroup<String>(
                groupValue: settings.themeMode,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .save(settings.copyWith(themeMode: v)),
                child: Column(
                  children: [
                    for (final (mode, label, icon) in [
                      ('system', 'Match system', Icons.brightness_auto),
                      ('light', 'Ledger (light)', Icons.light_mode_outlined),
                      ('dark', 'Scoreboard (dark)', Icons.dark_mode_outlined),
                    ])
                      RadioListTile<String>(
                        value: mode,
                        title: Row(children: [
                          Icon(icon, size: 20, color: c.inkFaint),
                          const SizedBox(width: 10),
                          Text(label),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const MonoLabel('Data', size: 12),
            const SizedBox(height: 8),
            _tile(context, Icons.storage_outlined, 'Storage',
                'What\'s taking space on this phone',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StorageScreen()))),
            const SizedBox(height: 8),
            _tile(context, Icons.code, 'Export JSON', 'Everything, one file',
                () => export(true)),
            const SizedBox(height: 8),
            _tile(context, Icons.table_chart_outlined, 'Export CSV',
                'Meals and sets for spreadsheets', () => export(false)),
            const SizedBox(height: 20),
            const MonoLabel('Privacy', size: 12),
            const SizedBox(height: 8),
            LedgerCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Biometric app lock'),
                subtitle: const MonoLabel('Face / fingerprint on launch',
                    size: 10),
                value: settings.biometricLock,
                onChanged: (v) async {
                  if (v) {
                    // Contextual: check capability the moment it's enabled.
                    final bio = ref.read(biometricServiceProvider);
                    if (!await bio.canUse()) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No biometrics available on this device')));
                      }
                      return;
                    }
                    if (!await bio.authenticate()) return;
                  }
                  await ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(biometricLock: v));
                },
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: MonoLabel(
                  'No accounts. No cloud. Your data never leaves your phone.',
                  size: 10,
                  color: c.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    final c = context.ledger;
    return LedgerCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: c.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                MonoLabel(subtitle, size: 10),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.inkFaint),
        ],
      ),
    );
  }
}
