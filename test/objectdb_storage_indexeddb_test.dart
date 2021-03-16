@TestOn('browser')

import 'package:objectdb/src/objectdb_storage_indexeddb.dart';
import 'package:test/test.dart';

import 'objectdb_storage.dart';
import 'package:objectdb/objectdb.dart';

void main() async {
  group('indexeddb crud', testWithAdapter(IndexedDBStorage("test-db")));

  test('indexeddb upgrade', () async {
    var dbName = 'upgrade';

    var db = ObjectDB(IndexedDBStorage(dbName));
    db.insertMany([
      {'firstName': 'Mia', 'lastName': 'Smith'},
      {'firstName': 'John', 'lastName': 'Miller'},
    ]);

    await db.close();

    db = ObjectDB(
      IndexedDBStorage(dbName),
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
