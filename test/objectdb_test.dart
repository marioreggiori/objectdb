import 'package:test/test.dart';
import 'dart:io';
import 'package:objectdb/objectdb.dart';

void main() async {
  // init test.db
  File file;
  final path = Directory.current.path + '/test/';
  file = File(path + 'test.db');
  if (file.existsSync()) {
    file.deleteSync();
  }
  file = File(path + 'init.db');
  file.copySync(path + 'test.db');

  test('initialize database', () async {
    var db = ObjectDB(path: path + 'test.db');
    await db.open();

    expect((await db.find({})).length, 429);

    await db.close();
  });

  var db = ObjectDB(path: path + 'test.db');
  await db.open();

  // fetch all documents
  var all = await db.find({});

  test('query 1', () async {
    var testKeys = [];
    var test = await db.find({
      Op.lt: {"age": 20},
      "active": true,
    });

    var count = 0;

    for (var doc in test) {
      testKeys.add(doc['id']);
      expect((doc['age'] < 20 && doc['active'] == true), true);
      count++;
    }

    print('First query count: $count');

    for (var doc in all) {
      if (testKeys.contains(doc['id'])) continue;
      expect((doc['age'] < 20 && doc['active'] == true), false);
      count++;
    }

    expect(count, all.length);
  });

  test('query 2', () async {
    var testKeys = [];
    var test = await db.find({
      Op.or: {
        Op.lt: {"age": 20},
        Op.inList: {
          "state": ['Florida', 'Virginia', 'New Jersey']
        },
      },
      "active": true,
    });

    var count = 0;

    for (var doc in test) {
      testKeys.add(doc['id']);
      expect(
          ((doc['age'] < 20 ||
                  ['Florida', 'Virginia', 'New Jersey']
                      .contains(doc['state'])) &&
              doc['active'] == true),
          true);
      count++;
    }

    print('Second query count: $count');

    for (var doc in all) {
      if (testKeys.contains(doc['id'])) continue;
      expect(
          ((doc['age'] < 20 ||
                  ['Florida', 'Virginia', 'New Jersey']
                      .contains(doc['state'])) &&
              doc['active'] == true),
          false);
      count++;
    }

    expect(count, all.length);
  });

  test('operators', () async {});

  db.close();
}
