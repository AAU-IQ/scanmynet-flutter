import 'messages.g.dart';

/// Known `alert_type` values, as an OPEN enum.
///
/// The backend adds members without an API version bump, so anything
/// unrecognised resolves to [unknown] rather than throwing. The raw string
/// stays available on [ReportAlert.alertType].
enum AlertType {
  firewall('firewall'),
  missingUpnp('missing_upnp'),
  doubleNat('double_nat'),
  incompleteSpeedTest('incomplete_speed_test'),
  incompleteScan('incomplete_scan'),
  missingLocation('missing_location'),
  oldRouter('old_router'),
  networkUtilizationAlert('network_utilization_alert'),
  multicastDisabled('multicast_disabled'),
  clientIsolationEnabled('client_isolation_enabled'),
  highNetworkUtilization('high_network_utilization'),
  duplicateSsid('duplicate_ssid'),
  rangeExtender('range_extender'),
  meshNetwork('mesh_network'),
  networkSpeedLoss('network_speed_loss'),

  /// A value this SDK version does not know. Read the raw string instead.
  unknown('');

  const AlertType(this.wireValue);

  /// The `alert_type` string as sent by the backend.
  final String wireValue;

  static AlertType fromWire(String? value) => AlertType.values.firstWhere(
        (t) => t.wireValue == value,
        orElse: () => AlertType.unknown,
      );
}

/// Known `action_type` values, as an OPEN enum. See [AlertType].
enum ActionType {
  incompleteSpeedtest('incomplete_speedtest'),
  highRouterUsageScan('high_router_usage_scan'),
  downloadSpeed('download_speed'),
  closerToTheRouter('closer_to_the_router'),
  connectedTo2ghzNetwork('connected_to_2ghz_network'),
  recommendedChannel('recommended_channel'),

  /// A value this SDK version does not know. Read the raw string instead.
  unknown('');

  const ActionType(this.wireValue);

  /// The `action_type` string as sent by the backend.
  final String wireValue;

  static ActionType fromWire(String? value) => ActionType.values.firstWhere(
        (t) => t.wireValue == value,
        orElse: () => ActionType.unknown,
      );
}

/// Branch on [type], never on `alertValue` — values are display-ready English
/// strings, some templated at runtime, and are not stable identifiers.
extension ReportAlertType on ReportAlert {
  AlertType get type => AlertType.fromWire(alertType);
}

/// Branch on [type], never on `actionValue`. See [ReportAlertType].
extension ReportActionType on ReportAction {
  ActionType get type => ActionType.fromWire(actionType);
}
