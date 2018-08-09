import 'dart:io';
import 'package:objectdb/objectdb.dart';

void run() async {
  final path = Directory.current.path + '/test/';
  //File file;
  File file = File(path + 'test.db');
  if (file.existsSync()) {
    file.deleteSync();
  }
  file = File(path + 'init.db');
  file.copySync(path + 'test.db');

  final db = ObjectDB(path + 'test.db');
  await db.open();

  var ids = await db.insertMany([
    {'a': '1'},
    {'a': '2'},
    {'a': '3'},
    {'a': '4'},
  ]);

  print(await db.find({'_id': ids[2]}));

  print(await db.insert({'a': '5'}));
  db.insert({'a': '6'});
  db.insert({'a': '7'});
  db.insert({'a': '8'});
  db.insert({'a': '9'});

  db.update({
    Op.gt: {'a': '0'},
    'a': RegExp('[4-7]'),
  }, {
    Op.max: {'n': 100},
    'b': 'c'
  });

  db.update({
    Op.gt: {'a': '0'},
    'a': RegExp('[4-7]'),
  }, {
    Op.rename: {'b': 'ü'},
    Op.unset: {'n': true},
  });

  //print((await db.remove({'a': RegExp('[3-6]')})));

  print(await db.last({
    Op.gt: {'a': 0},
  }));

  print(await db.find({
    Op.gt: {'a': 0},
  }));

  await db.close();
}

void main() {
  run();
}
