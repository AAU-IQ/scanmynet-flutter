import 'package:flutter_test/flutter_test.dart';
import 'package:scanmynet_sdk/scanmynet_sdk.dart';

void main() {
  test('known alert type resolves to its enum member', () {
    final alert = ReportAlert(alertType: 'old_router', alertValue: 'Old Router');
    expect(alert.type, AlertType.oldRouter);
  });

  test('unknown alert type falls back to unknown and keeps the raw value', () {
    final alert = ReportAlert(alertType: 'brand_new_type', alertValue: 'x');
    expect(alert.type, AlertType.unknown);
    expect(alert.alertType, 'brand_new_type');
  });

  test('null alert type resolves to unknown', () {
    expect(ReportAlert().type, AlertType.unknown);
  });

  test('known action type resolves to its enum member', () {
    final action = ReportAction(actionType: 'download_speed', actionValue: 'x');
    expect(action.type, ActionType.downloadSpeed);
  });

  test('unknown action type falls back to unknown', () {
    expect(ReportAction(actionType: 'nope').type, ActionType.unknown);
  });
}
