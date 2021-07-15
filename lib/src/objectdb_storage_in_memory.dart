import 'dart:convert';
import 'package:objectdb/src/objectdb_filter.dart';
import 'package:objectdb/src/objectdb_matcher.dart';
import 'package:objectid/objectid.dart';
import 'package:objectdb/src/objectdb_storage_interface.dart';

/// Stores data in-memory
class InMemoryStorage extends StorageInterface {
  final List<Map<dynamic, dynamic>> _data = [];

  Map<dynamic, dynamic> _jsonClone(Map<dynamic, dynamic> data) =>
      jsonDecode(jsonEncode(data));

  @override
  Future<ObjectId> insert(Map data) async {
    var _id = ObjectId();
    data['_id'] = _id.hexString;
    // create new object
    _data.add(_jsonClone(data));
    return _id;
  }

  @override
  Future<Stream<Map<dynamic, dynamic>>> find(Map query,
      [Filter filter = Filter.all]) async {
    var match = createMatcher(query);
    if (filter == Filter.all) {
      return Stream.fromIterable(
          _data.where(match).map<Map<dynamic, dynamic>>(_jsonClone));
    }
    if (filter == Filter.first) {
      return Stream.fromIterable([_jsonClone(_data.firstWhere(match))]);
    } else {
      return Stream.fromIterable([_jsonClone(_data.lastWhere(match))]);
    }
  }

  @override
  Future<int> remove(Map query) async {
    var matcher = createMatcher(query);
    var match = _data.where(matcher).map((doc) => doc['_id']).toList();

    var count = match.length;
    _data.removeWhere(matcher);
    return count;
  }

  @override
  Future update(Map query, Map changes, [bool replace = false]) async {
    // count updated entries
    var count = 0;
    // create matcher for query
    var matcher = createMatcher(query);
    // iterate all data
    for (var i = 0; i < _data.length; i++) {
      // skip if query does not match
      if (!matcher(_data[i])) continue;
      count++;

      _data[i] = StorageInterface.applyUpdate(_data[i], changes, replace);
    }

    return count;
  }

  @override
  Future<ObjectId?> save(Map query, Map changesOrData) {
    var matcher = createMatcher(query);
    var toUpdate = _data.where((element) => matcher(element)).toList();
    if (toUpdate.isEmpty) {
      return insert(changesOrData);
    } else if (toUpdate.length == 1) {
      toUpdate.forEach((element) {
        changesOrData['_id'] = element['_id'];
        StorageInterface.applyUpdate(element, changesOrData, true);
      });
      return Future.value(ObjectId.fromHexString(toUpdate.first['_id']));
    } else {
      return Future.value(null);
    }
  }
}
