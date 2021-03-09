import 'package:test/test.dart';

import '../../lib/src/objectdb_base.dart';
import '../utils.dart';
import 'package:collection/collection.dart';

Function mEq = const MapEquality().equals;
Function lEq = const DeepCollectionEquality.unordered().equals;

void insertSingleFlatObject() async {
  var db = await createNew();

  var data = {"a": 1, "b": "c", "d": true, "e": 1.2};
  db.insert(Map.from(data));
  var res = await db.find({});
  var res0 = Map.from(res[0]);
  res0.remove('_id');
  expect(mEq(data, res0), true);

  await db.close();
}

void insertManyFlatObjects() async {
  var db = await createNew();

  var data = [
    {"a": 1, "b": "c", "d": true, "e": 1.2},
    {"a": 1, "b": "c", "d": true, "e": 1.2},
    {"a": 1, "b": "c", "d": true, "e": 1.2},
  ];

  db.insertMany(List.from(data));
  expect(testEqual(data, await db.find({})), true);

  await db.close();
}

bool testEqual(List insert, List res) {
  return lEq(
      insert,
      List.from(res).map((e) {
        //e.remove('_id');
        return e;
      }).toList());
}

void insertNestedObject() async {}
