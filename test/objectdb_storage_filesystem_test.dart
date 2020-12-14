@TestOn('vm')
import 'dart:io';

import 'package:objectdb/src/objectdb_base.dart';
import 'package:objectdb/src/objectdb_storage_filesystem.dart';
import 'package:test/test.dart';

import 'objectdb_storage.dart';

var tmpPrefix = Directory.current.path + '/test/temp/';

void main() async {
  var crudTestFile = tmpPrefix + 'storage_crud_fs.db';
  var upgradeTestFile = tmpPrefix + 'storage_fs_upgrade.db';

  for (var fileName in [crudTestFile, upgradeTestFile]) {
    var file = File(fileName);
    if (file.existsSync()) file.deleteSync();
    tearDownAll(file.deleteSync);
  }

  group('filesystem crud', testWithAdapter(FileSystemStorage(crudTestFile)));

  test('filesystem upgrade', () async {
    var db = ObjectDB(FileSystemStorage(upgradeTestFile));
    db.insertMany([
      {'firstName': 'Mia', 'lastName': 'Smith'},
      {'firstName': 'John', 'lastName': 'Miller'},
    ]);

    await db.close();

    db = ObjectDB(
      FileSystemStorage(upgradeTestFile),
      version: 2,
      onUpgrade: (db, lastVersion) async {
        for (var entry in await db.find()) {
          db.update(
            {'_id': entry['_id']},
            {
              'name': {'first': entry['firstName'], 'last': entry['lastName']}
            },
            true,
          );
        }
      },
    );

    var res = await db.find();
    expect(res.length, 2);
    expect(res[0]['name']['first'], 'Mia');
    expect(res[1]['name']['last'], 'Miller');

    await db.close();
  });
}
