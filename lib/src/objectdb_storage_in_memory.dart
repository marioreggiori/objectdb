import 'dart:convert';
import 'package:objectdb/src/objectdb_filter.dart';
import 'package:objectdb/src/objectdb_matcher.dart';
import 'package:objectid/objectid.dart';
import 'package:objectdb/src/objectdb_storage_interface.dart';

class InMemoryStorage extends StorageInterface {
  List<Map<dynamic, dynamic>> _data = [];

  Map<dynamic, dynamic> _jsonClone(Map<dynamic, dynamic> data) =>
      jsonDecode(jsonEncode(data));

  @override
  Future<ObjectId> insert(Map data) async {
    ObjectId _id = ObjectId();
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
      return Stream.fromIterable([_jsonClone(this._data.firstWhere(match))]);
    } else {
      return Stream.fromIterable([_jsonClone(this._data.lastWhere(match))]);
    }
  }

  @override
  Future remove(Map query) async {
    List match = this
        ._data
        .where(createMatcher(query))
        .map((doc) => doc['_id'])
        .toList();

    int count = match.length;
    _data.removeWhere(createMatcher(query));
    return count;
  }

  @override
  Future update(Map query, Map changes, [bool replace = false]) async {
    // count updated entries
    int count = 0;
    // create matcher for query
    var matcher = createMatcher(query);
    // iterate all data
    for (var i = 0; i < this._data.length; i++) {
      // skip if query does not match
      if (!matcher(_data[i])) continue;
      count++;

      _data[i] = applyUpdate(_data[i], changes, replace);
    }

    return count;
  }
}
