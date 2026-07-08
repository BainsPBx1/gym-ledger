import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

/// Full-screen viewer for a PR's photo or video.
class PrMediaScreen extends StatefulWidget {
  final PrEntry pr;
  const PrMediaScreen({super.key, required this.pr});

  @override
  State<PrMediaScreen> createState() => _PrMediaScreenState();
}

class _PrMediaScreenState extends State<PrMediaScreen> {
  VideoPlayerController? _video;
  String? _error;

  bool get _isVideo => widget.pr.mediaType == 'video';

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      final file = File(widget.pr.mediaPath!);
      _video = VideoPlayerController.file(file)
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _video!.play();
          }
        }).catchError((Object e) {
          if (mounted) setState(() => _error = '$e');
        });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    final pr = widget.pr;
    String trim(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
    final exists =
        pr.mediaPath != null && File(pr.mediaPath!).existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${pr.exercise.toUpperCase()} — ${trim(pr.weightKg)} KG'),
      ),
      body: !exists
          ? const Center(
              child: MonoLabel('Media file is gone', size: 12,
                  color: Colors.white70))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text("Couldn't play this video: $_error",
                        style: const TextStyle(color: Colors.white70)),
                  ),
                )
              : _isVideo
                  ? _videoView(c)
                  : Center(
                      child: InteractiveViewer(
                        maxScale: 5,
                        child: Image.file(File(pr.mediaPath!)),
                      ),
                    ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 24, top: 8),
        child: Text(
          DateFormat('EEEE d MMMM yyyy').format(pr.date),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: monoFont, color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }

  Widget _videoView(LedgerColors c) {
    final v = _video!;
    if (!v.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      onTap: () =>
          setState(() => v.value.isPlaying ? v.pause() : v.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: v.value.aspectRatio,
              child: VideoPlayer(v),
            ),
          ),
          if (!v.value.isPlaying)
            Icon(Icons.play_circle_outline,
                size: 88, color: Colors.white.withValues(alpha: 0.85)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              v,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: c.accent,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
