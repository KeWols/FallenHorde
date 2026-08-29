import 'package:fallen_horde/game/persistence/scoreboard_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('empty board always stores a finished run', () async {
    final storage = ScoreboardStorage();
    final entries = await storage.maybeInsert(42);
    expect(entries, hasLength(1));
    expect(entries.first.score, 42);
    final loaded = await storage.load();
    expect(loaded.single.score, 42);
  });

  test('keeps the best ten scores', () async {
    final storage = ScoreboardStorage();
    for (var i = 1; i <= 12; i++) {
      await storage.maybeInsert(i);
    }
    final loaded = await storage.load();
    expect(loaded, hasLength(10));
    expect(loaded.first.score, 12);
    expect(loaded.last.score, 3);
  });
}
