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

  final db = await ObjectDB(path: path + 'test.db').open(false);

  var result = await db.find({
    Op.or: {
      Op.inArray: {
        "state": ['Alaska', 'Nebraska']
      },
      "active": true,
    },
    Op.gt: {"age": 70}
  });

  for (var i in result) {
    print(i);
  }

  print(result.length);

  await db.close();
}

void main() {
  run();
}
