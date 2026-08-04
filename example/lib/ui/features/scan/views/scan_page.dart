import 'package:flutter/material.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';
import 'package:scanmynet_sdk_example/domain/models/scan_ui_state.dart';
import 'package:scanmynet_sdk_example/ui/features/scan/view_models/scan_view_model.dart';
import 'package:scanmynet_sdk_example/ui/features/scan/views/widgets/customer_key_field.dart';
import 'package:scanmynet_sdk_example/ui/features/scan/views/widgets/report_link_card.dart';
import 'package:scanmynet_sdk_example/ui/features/scan/views/widgets/report_summary_card.dart';
import 'package:scanmynet_sdk_example/ui/features/scan/views/widgets/scan_progress_card.dart';

/// Home screen: collect a customer key, run a scan, show animated progress and
/// the resulting report link. Lean view — all logic lives in [ScanViewModel].
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.viewModel});

  final ScanViewModel viewModel;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _keyController = TextEditingController(text: 'flutter-demo');

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _run() {
    FocusScope.of(context).unfocus();
    final key = _keyController.text.trim();
    widget.viewModel.start(customerKey: key.isEmpty ? 'flutter-demo' : key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ScanMyNet')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final state = widget.viewModel.state;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Network scan',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Run a full ScanMyNet analysis and get a shareable report.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  _EnvironmentSelector(
                    selected: widget.viewModel.environment,
                    enabled: !state.isRunning,
                    onChanged: widget.viewModel.selectEnvironment,
                    customBaseUrl: widget.viewModel.customBaseUrl,
                    onCustomBaseUrlChanged: widget.viewModel.setCustomBaseUrl,
                  ),
                  const SizedBox(height: 20),
                  CustomerKeyField(
                    controller: _keyController,
                    enabled: !state.isRunning,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.isRunning ? null : _run,
                    icon: state.isRunning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(state.isRunning ? 'Scanning…' : 'Run scan'),
                  ),
                  if (state.isRunning) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: widget.viewModel.cancel,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Cancel scan'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _resultSection(state),
                  ),
                  if (widget.viewModel.logs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _LogPanel(lines: widget.viewModel.logs),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _resultSection(ScanUiState state) {
    if (state.isRunning) {
      return ScanProgressCard(key: const ValueKey('progress'), state: state);
    }
    if (state.isFinished && state.reportUrl != null) {
      return Column(
        key: const ValueKey('report'),
        children: [
          ReportLinkCard(reportUrl: state.reportUrl!),
          if (state.report != null) ...[
            const SizedBox(height: 12),
            ReportSummaryCard(report: state.report!),
          ],
        ],
      );
    }
    if (state.hasFailed) {
      return _ErrorCard(key: const ValueKey('error'), message: state.errorMessage);
    }
    return const _IdleHint(key: ValueKey('idle'));
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message ?? 'Scan failed',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live, scrollable feed of native scan events. The newest line is kept pinned
/// to the bottom so a stall (e.g. the scan pausing on the traceroute step) is
/// visible as the last entry with no follow-up.
class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Scan log', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text('${lines.length}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  lines.join('\n'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Environment picker. Disabled while a scan runs. Backed by the SDK's
/// `ScanEnvironment` enum (the former `AppEnvironment`).
///
/// Picking `Custom` reveals a server-root field: unlike the built-in
/// environments, that case carries no URL of its own, and the SDK rejects it
/// without one.
class _EnvironmentSelector extends StatefulWidget {
  const _EnvironmentSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.customBaseUrl,
    required this.onCustomBaseUrlChanged,
  });

  final ScanEnvironment selected;
  final bool enabled;
  final ValueChanged<ScanEnvironment> onChanged;
  final String customBaseUrl;
  final ValueChanged<String> onCustomBaseUrlChanged;

  @override
  State<_EnvironmentSelector> createState() => _EnvironmentSelectorState();
}

class _EnvironmentSelectorState extends State<_EnvironmentSelector> {
  late final TextEditingController _urlController =
      TextEditingController(text: widget.customBaseUrl);

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  static String _label(ScanEnvironment env) =>
      env.name[0].toUpperCase() + env.name.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Environment',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ScanEnvironment>(
            segments: [
              for (final env in ScanEnvironment.values)
                ButtonSegment(value: env, label: Text(_label(env))),
            ],
            selected: {widget.selected},
            showSelectedIcon: false,
            onSelectionChanged: widget.enabled
                ? (selection) => widget.onChanged(selection.first)
                : null,
          ),
        ),
        if (widget.selected == ScanEnvironment.custom) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            enabled: widget.enabled,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: widget.onCustomBaseUrlChanged,
            decoration: const InputDecoration(
              labelText: 'Server root',
              hintText: 'https://smn.example.com/',
              helperText: 'The SDK appends /api/v1/… itself.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Icon(
            Icons.wifi_tethering,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter a customer name and tap Run scan.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
