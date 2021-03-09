import 'package:test/test.dart';

import 'groups/open_database.dart' as open_database;
import 'groups/insert_data.dart' as insert_data;
import 'utils.dart';

void main() {
  resetTmp();

  group('open database', () {
    test('simple open and close with cleanup',
        open_database.openAndCloseWithCleanup);

    test('simple open and close without cleanup',
        open_database.openAndCloseWithoutCleanup);
  });

  group('insert data', () {
    test('insert single flat object', insert_data.insertSingleFlatObject);
    test('insert many flat object', insert_data.insertManyFlatObjects);
  });

  group('update data', () {
    //
  });

  group('delete data', () {
    //
  });

  group('cleanup', () {
    //
  });
}
