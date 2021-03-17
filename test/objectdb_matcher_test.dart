import 'package:objectdb/objectdb.dart';
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

  test('regex', () {
    var match = createMatcher({
      'test': RegExp(
          r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')
    });

    expect(match({'test': '10.2.1.0'}), true);
    expect(match({'test': '10.2.1.300'}), false);
    expect(match({'test': 5}), false);
    expect(match({}), false);
  });

  group('operator', () {
    group('logical', () {
      test('and', () {
        var match = createMatcher({
          Op.and: {
            'a': 1,
            'b': 2,
          }
        });

        expect(match({'a': 1, 'b': 2}), true);
        expect(match({'a': 1, 'b': 3}), false);
        expect(match({'a': 1}), false);
        expect(match({'b': 2}), false);
        expect(match({}), false);
      });
      test('or', () {
        var match = createMatcher({
          Op.or: {
            'a': 1,
            'b': 2,
          }
        });

        expect(match({'a': 1, 'b': 2}), true);
        expect(match({'a': 1, 'b': 3}), true);
        expect(match({'a': 1}), true);
        expect(match({'b': 2}), true);
        expect(match({'a': 2, 'b': 1}), false);
        expect(match({}), false);
      });
      test('not', () {
        var match = createMatcher({
          Op.not: {'test': 'word'},
        });

        expect(match({'test': 'not'}), true);
        expect(match({'test': 'word'}), false);
      });
    });

    group('comparison', () {
      test('lt', () {
        var match = createMatcher({
          Op.lt: {'test': 5}
        });

        expect(match({'test': 3}), true);
        expect(match({'test': 5}), false);
        expect(match({'test': 8}), false);
        expect(match({'test': 'abc'}), false);
        expect(match({}), false);

        match = createMatcher({
          Op.lt: {'test': 'lmn'}
        });

        expect(match({'test': 'abc'}), true);
        expect(match({'test': 'lmn'}), false);
        expect(match({'test': 'xyz'}), false);
        expect(match({'test': 123}), false);
        expect(match({}), false);
      });
      test('lte', () {
        var match = createMatcher({
          Op.lte: {'test': 5}
        });

        expect(match({'test': 3}), true);
        expect(match({'test': 5}), true);
        expect(match({'test': 8}), false);
        expect(match({'test': 'abc'}), false);
        expect(match({}), false);

        match = createMatcher({
          Op.lte: {'test': 'lmn'}
        });

        expect(match({'test': 'abc'}), true);
        expect(match({'test': 'lmn'}), true);
        expect(match({'test': 'xyz'}), false);
        expect(match({'test': 123}), false);
        expect(match({}), false);
      });
      test('gt', () {
        var match = createMatcher({
          Op.gt: {'test': 5}
        });

        expect(match({'test': 3}), false);
        expect(match({'test': 5}), false);
        expect(match({'test': 8}), true);
        expect(match({'test': 'abc'}), false);
        expect(match({}), false);

        match = createMatcher({
          Op.gt: {'test': 'lmn'}
        });

        expect(match({'test': 'abc'}), false);
        expect(match({'test': 'lmn'}), false);
        expect(match({'test': 'xyz'}), true);
        expect(match({'test': 123}), false);
        expect(match({}), false);
      });
      test('gte', () {
        var match = createMatcher({
          Op.gte: {'test': 5}
        });

        expect(match({'test': 3}), false);
        expect(match({'test': 5}), true);
        expect(match({'test': 8}), true);
        expect(match({'test': 'abc'}), false);
        expect(match({}), false);

        match = createMatcher({
          Op.gte: {'test': 'lmn'}
        });

        expect(match({'test': 'abc'}), false);
        expect(match({'test': 'lmn'}), true);
        expect(match({'test': 'xyz'}), true);
        expect(match({'test': 123}), false);
      });
      test('inList', () {
        var match = createMatcher({
          Op.inList: {
            'test': ['a', 'b', 'c']
          }
        });

        expect(match({'test': 'a'}), true);
        expect(match({'test': 'd'}), false);
        expect(match({'test': 2}), false);
        expect(match({}), false);
      });
      test('notInList', () {
        var match = createMatcher({
          Op.notInList: {
            'test': ['a', 'b', 'c']
          }
        });

        expect(match({'test': 'a'}), false);
        expect(match({'test': 'd'}), true);
        expect(match({'test': 2}), true);
        expect(match({}), false);
      });
    });
  });

  test('array', () {});
}
