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

    expect((await db.find({})).length, 426);

    await db.close();
  });

  test('crud', () async {
    var db = ObjectDB(path: path + 'test.db');
    await db.open();

    var res = await db.find({
      Op.lt: {"age": 20},
      "active": true,
    });

    for (var doc in res) {
      expect((doc['age'] < 20 && doc['active'] == true), true);
    }

    await db.close();
  });

  test('operators', () async {});
}
