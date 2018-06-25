import 'dart:io';
import 'package:objectdb/objectdb.dart';

void run() async {
  File file;
  final path = Directory.current.path + '/test/';
  file = File(path + 'test.db');
  if (file.existsSync()) {
    file.deleteSync();
  }
  file = File(path + 'init.db');
  file.copySync(path + 'test.db');

  final db = ObjectDB(path: path + 'test.db');
  await db.open();

  db.insert({"a": "1"});
  db.insert({"a": "2"});
  db.insert({"a": "3"});
  db.insert({"a": "4"});
  db.insert({"a": "5"});
  db.insert({"a": "6"});
  db.insert({"a": "7"});
  db.insert({"a": "8"});
  db.insert({"a": "9"});

  db.update({Op.gt:{"a":"0"}}, {"b":"c"});

  print(await db.find({
    Op.gt: {"a": 0},
  }));

  await db.close();
}

void main() {
  run();
}
