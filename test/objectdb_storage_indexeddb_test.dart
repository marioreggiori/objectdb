@TestOn('browser')

import 'package:objectdb/src/objectdb_storage_indexeddb.dart';
import 'package:test/test.dart';

import 'objectdb_storage.dart' as storage;
import 'objectdb_upgrade.dart' as upgrade;

void main() async {
  group('indexeddb crud', storage.testWithAdapter(IndexedDBStorage('test-db')));
  group('indexeddb upgrade',
      upgrade.testWithAdapter(() => IndexedDBStorage('upgrade')));
}
