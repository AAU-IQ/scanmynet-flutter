import 'package:flutter/material.dart';
import 'package:scanmynet_sdk_example/domain/models/scan_ui_state.dart';

/// Animated progress display shown while a scan is running.
///
/// The native SDK reports progress in discrete steps, so the raw percent jumps
/// (e.g. 0 → 16 → 46). To keep it feeling smooth, both the fill bar and the
/// percent label ease toward each new target with a single tween, and the bar
/// carries a moving shimmer so it still reads as "working" during long steps.
class ScanProgressCard extends StatelessWidget {
  const ScanProgressCard({super.key, required this.state});

  final ScanUiState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = (state.percent / 100).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        // One tween drives the whole readout: when a new step bumps `target`,
        // it animates from the current value (not from 0) to the new target.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: target),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Scanning your network',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProgressBar(fraction: value),
                const SizedBox(height: 12),
                Text(
                  _humanizeStep(state.stepLabel),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
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

/// A rounded progress bar with a visible gradient fill and a looping shimmer
/// that sweeps across the filled portion to signal ongoing activity.
class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  // Vivid base fill so progress reads clearly against the light track.
  static const Color _fillStart = Color(0xFF1565C0); // deep blue
  static const Color _fillEnd = Color(0xFF00B8D4); // cyan

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Keep a thin sliver visible even at 0 so the bar never looks empty/broken.
    final widthFactor = widget.fraction.clamp(0.02, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        height: 14,
        child: Stack(
          children: [
            // Tinted track for contrast against the bright fill.
            Positioned.fill(
              child: ColoredBox(
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
            // Fill sized to the current fraction: a saturated blue→cyan base
            // with a translucent highlight that sweeps across on top, so the
            // base colour never washes out.
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_fillStart, _fillEnd]),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _shimmer,
                    builder: (context, _) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: const [
                              Color(0x00FFFFFF),
                              Color(0x59FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: _shimmerStops(_shimmer.value),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds three monotonically-increasing gradient stops whose middle (bright)
/// band tracks the shimmer phase across [0,1].
List<double> _shimmerStops(double phase) {
  // Keep the centre off the edges so the three stops stay strictly ascending.
  final mid = phase.clamp(0.001, 0.999);
  final lo = (mid - 0.18).clamp(0.0, 1.0);
  final hi = (mid + 0.18).clamp(0.0, 1.0);
  return [lo, mid, hi];
}

/// Turns a `camelCase` step name into a readable phrase, e.g.
/// `connectionQualityTest` -> `Connection Quality Test`.
String _humanizeStep(String? raw) {
  if (raw == null || raw.isEmpty) return 'Working…';
  final spaced = raw
      .replaceAllMapped(
        RegExp('([a-z])([A-Z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      .replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
