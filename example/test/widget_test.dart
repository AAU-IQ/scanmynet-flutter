// Basic widget test for the example app.

import 'package:flutter_test/flutter_test.dart';

import 'package:scanmynet_sdk_example/app.dart';

void main() {
  testWidgets('renders the scan home screen with a Run scan button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ScanMyNetApp());

    expect(find.text('Run scan'), findsOneWidget);
    expect(find.text('Customer name / key'), findsOneWidget);
  });
}
