import 'package:objectdb/objectdb.dart';
import 'package:test/test.dart';

void main() {
  Map<dynamic, dynamic> obj;
  test('set', () {
    expect(
        StorageInterface.applyUpdate({}, {
          Op.set: {'abc': 123}
        }),
        {'abc': 123});

    expect(
        StorageInterface.applyUpdate({
          'abc': 'def'
        }, {
          Op.set: {'abc': 123}
        }),
        {'abc': 123});
  });

  test('max', () {
    expect(
        StorageInterface.applyUpdate({
          'test': 20
        }, {
          Op.max: {'test': 10}
        }),
        {'test': 10});

    expect(
        StorageInterface.applyUpdate({
          'test': 5
        }, {
          Op.max: {'test': 10}
        }),
        {'test': 5});

    expect(
        StorageInterface.applyUpdate({
          'test': 'test'
        }, {
          Op.max: {'test': 10}
        }),
        {'test': 'test'});

    expect(
        StorageInterface.applyUpdate({}, {
          Op.max: {'test': 10}
        }),
        {'test': 0});
  });

  test('min', () {
    expect(
        StorageInterface.applyUpdate({
          'test': 20
        }, {
          Op.min: {'test': 10}
        }),
        {'test': 20});

    expect(
        StorageInterface.applyUpdate({
          'test': 5
        }, {
          Op.min: {'test': 10}
        }),
        {'test': 10});

    expect(
        StorageInterface.applyUpdate({
          'test': 'test'
        }, {
          Op.min: {'test': 10}
        }),
        {'test': 'test'});

    expect(
        StorageInterface.applyUpdate({}, {
          Op.min: {'test': 10}
        }),
        {'test': 10});
  });

  test('increment', () {
    expect(
        StorageInterface.applyUpdate({
          'test': 20
        }, {
          Op.increment: {'test': 10}
        }),
        {'test': 30});

    expect(
        StorageInterface.applyUpdate({
          'test': 20
        }, {
          Op.increment: {'test': -10}
        }),
        {'test': 10});

    expect(
        StorageInterface.applyUpdate({
          'test': 'test'
        }, {
          Op.increment: {'test': 10}
        }),
        {'test': 'test'});

    expect(
        StorageInterface.applyUpdate({}, {
          Op.increment: {'test': 10}
        }),
        {'test': 10});
  });

  test('multiply', () {
    expect(
        StorageInterface.applyUpdate({
          'test': 20
        }, {
          Op.multiply: {'test': 10}
        }),
        {'test': 200});

    expect(
        StorageInterface.applyUpdate({
          'test': 20
        }, {
          Op.multiply: {'test': -10}
        }),
        {'test': -200});

    expect(
        StorageInterface.applyUpdate({
          'test': 'test'
        }, {
          Op.multiply: {'test': 10}
        }),
        {'test': 'test'});

    expect(
        StorageInterface.applyUpdate({}, {
          Op.multiply: {'test': 10}
        }),
        {'test': 0});
  });

  test('unset', () {
    expect(
        StorageInterface.applyUpdate({
          'test': 123
        }, {
          Op.unset: {'test': true}
        }),
        {});

    expect(
        StorageInterface.applyUpdate({
          'test': 123,
          'abc': 456,
        }, {
          Op.unset: {'test': true}
        }),
        {'abc': 456});

    expect(
        StorageInterface.applyUpdate({
          'test': 123,
          'abc': 456,
        }, {
          Op.unset: {'test': 123}
        }),
        {'test': 123, 'abc': 456});

    expect(
        StorageInterface.applyUpdate({
          'abc': 456,
        }, {
          Op.unset: {'test': true}
        }),
        {'abc': 456});
  });

  test('rename', () {
    expect(
        StorageInterface.applyUpdate({
          'test': 123,
        }, {
          Op.rename: {'test': 'toast'}
        }),
        {'toast': 123});

    expect(
        StorageInterface.applyUpdate({
          'test': 123,
        }, {
          Op.rename: {'test2': 'toast2'}
        }),
        {'test': 123});
  });
}
