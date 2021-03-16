import 'package:objectdb/src/objectdb_matcher.dart';
import 'package:test/test.dart';

void main() {
  group('query to matcher', () {
    test('simple', () {
      var match = createMatcher({'a': 5, 'b': 2});
      expect(match({'a': 5, 'b': 2}), true);
      expect(match({'a': 5, 'b': 5}), false);
    });

    test('nested', () {
      var match = createMatcher({'a.b': 4, 'a.c.d.e': 5});
      expect(
          match({
            'a': {
              'b': 4,
              'c': {
                'd': {'e': 5}
              }
            }
          }),
          true);

      expect(
          match({
            'a': {
              'b': 4,
              'c': {'d': 'test'}
            }
          }),
          false);
    });
  });
}
