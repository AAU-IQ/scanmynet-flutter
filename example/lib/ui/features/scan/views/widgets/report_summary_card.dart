import 'package:flutter/material.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';

/// Renders a compact summary pulled from the typed [ReportData] payload that the
/// SDK now returns alongside the report URL.
///
/// The point of this card is to demonstrate that a consuming app can build fully
/// custom UI directly from the structured report — every field is optional, so
/// each row renders only when its value is present.
class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({super.key, required this.report});

  final ReportData report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final speed = report.customerInternetSpeed;
    final wifi = report.userWifiNetwork;
    final router = report.customerRouterDetails;
    final deviceCount = report.localConnectedDevices?.length;
    final alerts = report.alerts ?? const <ReportAlert>[];

    final routerName =
        [router?.make, router?.model].whereType<String>().join(' ').trim();

    // The status the customer sees for the ping, with its colour, from the subscriber's own router entry.
    // Show it as given: the backend rates it by the provider's limits, so do not work it out from the
    // average ping.
    final routerQuality = report.connectionQuality
        ?.where((entry) => entry.isSubscriberRouter == true)
        .firstOrNull;

    // The advice the report page shows, each text by language: pick the phone's language, fall back to English.
    // (An app that supports a fixed set of languages would use its own resolved locale instead.)
    final language = View.of(context).platformDispatcher.locale.languageCode;
    final advice = report.recommendedActions?.firstOrNull;
    final noInstructions = _text(report.noInstructions, language);

    final stats = <_Stat>[
      if (speed?.networkSpeedDown != null)
        _Stat(Icons.download_rounded, 'Download',
            '${speed!.networkSpeedDown!.toStringAsFixed(1)} Mbps'),
      if (speed?.networkSpeedUp != null)
        _Stat(Icons.upload_rounded, 'Upload',
            '${speed!.networkSpeedUp!.toStringAsFixed(1)} Mbps'),
      if (deviceCount != null)
        _Stat(Icons.devices_rounded, 'Devices', '$deviceCount'),
      if (wifi?.ssid != null) _Stat(Icons.wifi_rounded, 'Wi-Fi', wifi!.ssid!),
      if (routerName.isNotEmpty)
        _Stat(Icons.router_rounded, 'Router', routerName),
      if (routerQuality?.pingQuality != null)
        _Stat(
          Icons.network_ping_rounded,
          'Ping',
          '${routerQuality!.averagePingTime?.toStringAsFixed(0) ?? '-'} ms · ${routerQuality.pingQuality}',
          color: _statusColor(routerQuality.pingQualityColor),
        ),
      if (routerQuality?.packetLossQuality != null)
        _Stat(
          Icons.leak_remove_rounded,
          'Packet loss',
          '${routerQuality!.packetLossQuality}',
          color: _statusColor(routerQuality.packetLossQualityColor),
        ),
    ];

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Report payload',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (report.incompleteAnalysis == true)
                  Tooltip(
                    message: 'Analysis incomplete — present as unreliable',
                    child: Icon(Icons.warning_amber_rounded,
                        size: 20, color: scheme.error),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Typed report also delivered to your app — build custom UI from it.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final s in stats) _StatChip(stat: s)],
              ),
            ],
            if (advice != null) ...[
              const SizedBox(height: 16),
              Text('Advice', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(_text(advice.title, language) ?? advice.key ?? '',
                  style: theme.textTheme.bodyMedium),
              if (_text(advice.recommendedAction, language) != null)
                Text(_text(advice.recommendedAction, language)!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ] else if (noInstructions != null) ...[
              // A Good overall status with nothing to do: the backend says so, in both languages.
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(noInstructions, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Alerts (${alerts.length})',
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              for (final alert in alerts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 8, color: scheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert.alertType ?? 'unknown',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A text by language code (`en`, `ar`): the language asked for, else English.
String? _text(Map<String, String>? texts, String language) =>
    texts?[language] ?? texts?['en'];

/// The colour the backend names for a status (`green`, `yellow`, `red`); null shows the default text colour.
Color? _statusColor(String? name) => switch (name) {
      'green' => Colors.green.shade700,
      'yellow' => Colors.amber.shade800,
      'red' => Colors.red.shade700,
      _ => null,
    };

/// A single labelled metric extracted from the report.
class _Stat {
  const _Stat(this.icon, this.label, this.value, {this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stat.label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              Text(stat.value,
                  style: theme.textTheme.bodyMedium?.copyWith(color: stat.color)),
            ],
          ),
        ],
      ),
    );
  }
}
