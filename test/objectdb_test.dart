import 'dart:io';
import 'package:test/test.dart';
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

  ObjectDB db;

  db =
      await ObjectDB(path + 'test.db', v: 5, onUpgrade: (db, oldVersion) async {
    print('Old version: $oldVersion');
    return;
  }).open();

  // fetch all documents
  var all = await db.find({});

  test('query 1', () async {
    var testKeys = [];
    var test = await db.find({
      Op.lt: {'age': 20},
      'active': true,
    });

    var count = 0;

    for (var doc in test) {
      testKeys.add(doc['_id']);
      if (!(doc['age'] < 20 && doc['active'] == true)) throw 'failed';
      count++;
    }

    print('First query count: $count');

    for (var doc in all) {
      if (testKeys.contains(doc['_id'])) continue;
      if ((doc['age'] < 20 && doc['active'] == true)) throw 'failed';
      count++;
    }

    expect(count, all.length);
  });

  test('query 2', () async {
    var testKeys = [];
    var test = await db.find({
      Op.or: {
        Op.lt: {'age': 20},
        Op.inList: {
          'state': ['Florida', 'Virginia', 'New Jersey']
        },
      },
      'active': true,
    });

    var count = 0;

    for (var doc in test) {
      testKeys.add(doc['_id']);
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
      if (testKeys.contains(doc['_id'])) continue;
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

  test('regex', () async {
    List res = await db.find({
      'name.first': RegExp('en'),
      Op.or: {
        'active': false,
        Op.inList: {
          'state': ['Alaska', 'Ohio']
        },
      }
    });

    testResult(result, bool shouldBeTrue) {
      var regex = RegExp('en');
      if (((regex.hasMatch(result['name']['first']) &&
              (result['active'] == false ||
                  ['Alaska', 'Ohio'].contains(result['state'])))) !=
          shouldBeTrue) throw 'invalid';
    }

    res.forEach((result) => testResult(result, true));
  });

  test('type checking', () async {
    List<Map<dynamic, dynamic>> res1 = await db.find({'active': true});
    Map<dynamic, dynamic> res2 = await db.first({'active': true});
    Map<dynamic, dynamic> res3 = await db.last({'active': true});

    ObjectId id = await db.insert({'test': 1});
    List<ObjectId> ids = await db.insertMany([
      {'test': 1},
      {'test': 2}
    ]);

    print(id);
    print(ids);

    int countUpdate = await db.update({'active': false}, {'status': true});
    int removeCount = await db.remove({'state': 'Alaska'});

    print('update count ' + countUpdate.toString());
    print('remove count ' + removeCount.toString());
  });

  test('operators', () async {
    // todo
  });

  test('close db', () async {
    db.close();
  });

  test('upgrade db', () async {
    db = await ObjectDB(path + 'test.db', v: 6,
        onUpgrade: (db, oldVersion) async {
      if (oldVersion < 6) {
        db.update({}, {
          Op.increment: {'age': 5}
        });
      }
      return;
    }).open();

    var res = await db.first({});

    expect(res['age'], 57);

    await db.close();
  });

  test('upgrade db again', () async {
    db = await ObjectDB(path + 'test.db', v: 6,
        onUpgrade: (db, oldVersion) async {
      if (oldVersion < 6) {
        db.update({}, {
          Op.increment: {'age': 5}
        });
      }
      return;
    }).open();

    var res = await db.first({});

    expect(res['age'], 57);

    await db.close();
  });
}
