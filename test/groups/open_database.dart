import '../../lib/src/objectdb_base.dart';
import '../utils.dart';

void openAndCloseWithCleanup() async {
  var db = await ObjectDB(dbPath("openAndCloseWithCleanup")).open();
  await db.close();
}

void openAndCloseWithoutCleanup() async {
  var db = await ObjectDB(dbPath("openAndCloseWithoutCleanup")).open(false);
  await db.close();
}
