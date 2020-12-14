import 'package:test/test.dart';

import 'package:objectdb/src/objectdb_storage_in_memory.dart';
import 'objectdb_storage.dart';

void main() async {
  group('in-memory crud', testWithAdapter(InMemoryStorage()));
}
