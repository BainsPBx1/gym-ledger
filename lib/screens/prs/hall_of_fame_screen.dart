import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'add_pr_screen.dart';
import 'pr_media_screen.dart';

/// The Hall of Fame: a scoreboard of personal records, most recent at the
/// top. Visually distinct from everyday logging — this is the high-score
/// table, not a ledger page.
class HallOfFameScreen extends ConsumerWidget {
  const HallOfFameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    final prs = ref.watch(prsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('HALL OF FAME')),
      body: LedgerBackground(
        child: prs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 72, color: c.inkFaint),
                      const SizedBox(height: 12),
                      const MonoLabel('No records on the board yet', size: 12),
                      const SizedBox(height: 24),
                      StampButton(
                        label: 'Claim your first PR',
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddPrScreen())),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _PrCard(pr: list[i], rank: i + 1),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 60, // FAB gets loose full-body constraints; must be bounded
          child: StampButton(
            label: '+ New record',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddPrScreen())),
          ),
        ),
      ),
    );
  }
}

class _PrCard extends ConsumerWidget {
  final PrEntry pr;
  final int rank;
  const _PrCard({required this.pr, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    return LedgerCard(
      borderColor: rank == 1 ? c.accent : null,
      padding: const EdgeInsets.all(14),
      onTap: pr.mediaPath == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => PrMediaScreen(pr: pr))),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: PixelNumber('#$rank',
                size: 30, color: rank == 1 ? c.accent : c.inkFaint),
          ),
          if (pr.mediaPath != null &&
              pr.mediaType == 'photo' &&
              File(pr.mediaPath!).existsSync()) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(pr.mediaPath!),
                  width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
          ] else if (pr.mediaType == 'video') ...[
            Icon(Icons.videocam, size: 32, color: c.secondary),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pr.exercise,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                MonoLabel(DateFormat('d MMM yyyy').format(pr.date), size: 10),
              ],
            ),
          ),
          PixelNumber(_trim(pr.weightKg), size: 40),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: MonoLabel(' kg', size: 11),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: c.inkFaint),
            tooltip: 'Remove record',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Remove this record?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Keep')),
                    TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Remove')),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(prDaoProvider).delete(pr.id!);
                ref.read(prsVersionProvider.notifier).state++;
              }
            },
          ),
        ],
      ),
    );
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';
}
