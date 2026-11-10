import 'package:flutter_test/flutter_test.dart';
import 'package:myappliance/app/app.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApplianceApp());

    // Verify that MyAppliance title is rendered on splash screen.
    expect(find.text('MyAppliance'), findsOneWidget);
    expect(find.text('Appliance Health Checker'), findsOneWidget);

    // Pump and settle timer
    await tester.pumpAndSettle();
  });
}
