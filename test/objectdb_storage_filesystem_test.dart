@TestOn('vm')
import 'dart:io';

import 'package:objectdb/src/objectdb_storage_filesystem.dart';
import 'package:test/test.dart';

import 'objectdb_storage.dart' as storage;
import 'objectdb_upgrade.dart' as upgrade;

var tmpPrefix = Directory.current.path + '/test/temp/';

void main() async {
  var crudTestFile = tmpPrefix + 'storage_crud_fs.db';
  var upgradeTestFile = tmpPrefix + 'storage_fs_upgrade.db';

  for (var fileName in [crudTestFile, upgradeTestFile]) {
    var file = File(fileName);
    if (file.existsSync()) file.deleteSync();
    tearDownAll(file.deleteSync);
  }

  group('filesystem crud',
      storage.testWithAdapter(FileSystemStorage(crudTestFile)));
  group('filesystem upgrade',
      upgrade.testWithAdapter(() => FileSystemStorage(upgradeTestFile)));
}
