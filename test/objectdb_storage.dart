import 'package:objectdb/objectdb.dart';
import 'package:objectdb/src/objectdb_storage_interface.dart';
import 'package:test/test.dart';
import 'dart:math';
import 'package:collection/collection.dart';
import 'sample_data.dart' as sample;

typedef Group = void Function();

Group testWithAdapter(StorageInterface adapter) {
  return () {
    var db = ObjectDB(adapter);

    setUp(() async {
      await db.remove({});
    });

    test('saveInsert', () async {
      var data = await insertSampleData(db);
      var objectId = await db.save({
        Op.and: {
          'age': 111,
        }
      }, {
        'name': 'saveTest',
        'newsletter': false,
        'age': 111,
      });
      expect(objectId, isNotNull);

      expect((await db.find({'age': 111})).length, equals(1));
    });

    test('saveUpdate', () async {
      var data = await insertSampleData(db);
      var objectId1 = await db.insert({
        'name': 'saveTest',
        'newsletter': false,
        'age': 111,
      });
      var objectId = await db.save({
        Op.and: {
          'age': 111,
        }
      }, {
        'name': 'saveUpdateTest',
        'newsletter': true,
        'age': 111,
      });
      expect(objectId, isNotNull);

      // expect((await db.find({'age': 111})).length, equals(1));
    });

    test('saveUpdateFail', () async {
      var data = await insertSampleData(db);
      var objectId = await db.save({
        Op.and: {
          'newsletter': false,
        }
      }, {
        'name': 'saveTest',
        'newsletter': false,
        'age': 111,
      });
      expect(objectId, isNull);
    });

    // test simple insert
    test('insert', () async {
      var data = await insertSampleData(db);

      expect(deepEq(data, await db.find()), true);
    });

    // test simple update
    test('update', () async {
      var data = await insertSampleData(db);
      // ignore: unawaited_futures
      db.cleanup();
      // ignore: unawaited_futures
      db.update({
        Op.gte: {
          'age': 43,
        }
      }, {
        'newsletter': false,
        'null': null,
      });

      data = data.map((e) {
        if (e['age'] >= 43) {
          e['newsletter'] = false;
          e['null'] = null;
        }
        return e;
      }).toList();

      expect(deepEq(data, await db.find()), true);
    });

    // test simple delete
    test('delete', () async {
      var data = await insertSampleData(db);

      // ignore: unawaited_futures
      List list = await db.find({'newsletter': false});
      expect(list.length, greaterThan(0));

      var count = await db.remove({'newsletter': false});
      expect(count, equals(list.length));
      data.removeWhere((element) => !element['newsletter']);

      expect(deepEq(data, await db.find()), true);
    });

    // test simple find
    test('find', () async {});

    tearDownAll(() async {
      await db.close();
    });
  };
}

///
///
///
///
///
///
/// HELPER

Function deepEq = const DeepCollectionEquality.unordered().equals;

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

Future<List<Map<dynamic, dynamic>>> insertSampleData(ObjectDB db) =>
    Future.wait(getSampleData(200).map((entry) async {
      entry['_id'] = (await db.insert(entry)).hexString;
      return entry;
    }));

List<Map<dynamic, dynamic>> getSampleData(int i) => List.generate(
    i,
    (index) => sampleEntry(
        sample.firstNames[_rnd.nextInt(sample.firstNames.length)],
        sample.lastNames[_rnd.nextInt(sample.lastNames.length)],
        _rnd.nextInt(100),
        _rnd.nextBool()));

Map sampleEntry(String firstName, String lastName, int age, bool newsletter) =>
    {
      'name': {'first': firstName, 'last': lastName},
      'age': age,
      'newsletter': newsletter,
    };
