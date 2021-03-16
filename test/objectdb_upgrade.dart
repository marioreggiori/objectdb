import 'package:objectdb/objectdb.dart';
import 'package:objectdb/src/objectdb_storage_interface.dart';
import 'package:test/test.dart';

typedef void Group();

typedef StorageInterface Creator();

Group testWithAdapter(Creator create) {
  return () {
    test('', () async {
      var db = ObjectDB(create());
      db.insertMany([
        {'firstName': 'Mia', 'lastName': 'Smith'},
        {'firstName': 'John', 'lastName': 'Miller'},
      ]);

      await db.close();

      db = ObjectDB(
        create(),
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
  };
}
