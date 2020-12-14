import 'package:objectdb/src/objectdb_base.dart';
import 'package:objectdb/src/objectdb_storage_in_memory.dart';
import 'package:test/test.dart';

void main() async {
  group('init db', () {
    test('onUpgrade', () async {
      var db = ObjectDB(InMemoryStorage(), onUpgrade: (db, version) async {
        await db.insert({'test': '1'});
        print(await db.find({}));
      });
      await db.close();
    });
  });
}
