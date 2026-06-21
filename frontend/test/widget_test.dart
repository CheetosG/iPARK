// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ipark/main.dart';
import 'package:ipark/providers/reservation_provider.dart';

void main() {
  testWidgets('App starts on login screen test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ],
        child: const IparkApp(
          initialRoute: '/login',
        ),
      ),
    );

    // Verify that we are on the login screen by searching for the app name or "SEND OTP"
    expect(find.text('iPark'), findsWidgets);
    expect(find.text('SEND OTP'), findsWidgets);
  });
}
