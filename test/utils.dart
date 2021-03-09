import 'dart:io';

import '../lib/src/objectdb_base.dart';

String dbPath(String dbName) {
  return Directory.current.path + '/test/tmp/' + dbName + '.db';
}

void resetTmp() {
  var tmpPath = Directory.current.path + '/test/tmp';
  if (Directory(tmpPath).existsSync()) {
    Directory(tmpPath).deleteSync(recursive: true);
  }
  Directory(tmpPath).createSync();
}

int dbCreateIndex = 0;
Future<ObjectDB> createNew() async {
  return await ObjectDB(dbPath("_____" + (++dbCreateIndex).toString())).open();
}
