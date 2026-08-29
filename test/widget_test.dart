import 'package:fallen_horde/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('main menu shows play scoreboard and settings', (tester) async {
    await tester.pumpWidget(const FallenHordeApp());
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('SCOREBOARD'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });
}
