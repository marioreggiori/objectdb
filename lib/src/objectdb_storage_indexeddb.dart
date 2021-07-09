import 'package:objectdb/src/objectdb_filter.dart';
import 'package:objectdb/src/objectdb_matcher.dart';
import 'package:objectdb/src/objectdb_storage_interface.dart';
import 'package:objectid/src/objectid/objectid.dart';
import 'package:objectdb/src/objectdb_meta.dart';

import 'dart:indexed_db';
import 'dart:html';

/// Stores data in indexeddb (browser only)
class IndexedDBStorage extends StorageInterface {
  final String _name;
  late final Database _db;
  IndexedDBStorage(this._name);
  int _version = 1;

  @override
  Future<Meta> open([int version = 1]) async {
    _version = version;
    _db = await window.indexedDB!.open(_name, version: 1, onUpgradeNeeded: (e) {
      Database db = e.target.result;
      if (!db.objectStoreNames!.contains('_')) {
        db.createObjectStore('_');
      }
    });

    var res = await _db
        .transaction('_', 'readonly')
        .objectStore('_')
        .getObject('\$objectdb');

    if (res == null) {
      await cleanup();
      return Meta(1);
    }

    return Meta(res['client_version']);
  }

  @override
  Future close() async {
    _db.close();
  }

  @override
  Future cleanup() async {
    await _db
        .transaction('_', 'readwrite')
        .objectStore('_')
        .put(Meta(_version).toMap(), '\$objectdb');
  }

  @override
  Future<Stream<Map>> find(Map query, [Filter filter = Filter.all]) async {
    var match = createMatcher(query);
    var tx = _db.transaction('_', 'readonly');
    var cur = tx.objectStore('_').openCursor(autoAdvance: true);
    var res = cur
        .where((entry) => entry.key != '\$objectdb' && match(entry.value))
        .map<Map<dynamic, dynamic>>((entry) => entry.value);

    if (filter == Filter.last) {
      return Stream.fromIterable([await res.last]);
    }

    return res;
  }

  @override
  Future<ObjectId> insert(Map data) async {
    var _id = ObjectId();
    data['_id'] = _id.hexString;
    var tx = _db.transaction('_', 'readwrite');
    await tx.objectStore('_').add(data, _id.hexString);
    return _id;
  }

  @override
  Future<int> remove(Map query) async {
    var match = createMatcher(query);
    var tx = _db.transaction('_', 'readwrite');
    var cur = tx.objectStore('_').openCursor(autoAdvance: true);
    var i = 0;
    await cur.where((entry) => match(entry.value)).forEach((element) {
      i++;
      element.delete();
    });
    return i;
  }

  @override
  Future update(Map query, Map changes, [bool replace = false]) async {
    var match = createMatcher(query);
    var tx = _db.transaction('_', 'readwrite');
    var cur = tx.objectStore('_').openCursor(autoAdvance: true);
    var i = 0;
    await cur.where((entry) => match(entry.value)).forEach((element) {
      i++;
      element.update(
          StorageInterface.applyUpdate(element.value, changes, replace));
    });
    return i;
  }

  @override
  Future<ObjectId?> save(Map query, Map changesOrData) async {
    var match = createMatcher(query);
    var tx = _db.transaction('_', 'readwrite');
    var cur = tx.objectStore('_').openCursor(autoAdvance: true);
    var list = await cur.where((entry) => match(entry.value)).toList();
    if (list.isEmpty) {
      return insert(changesOrData);
    } else if (list.length == 1) {
      await list.first.update(
          StorageInterface.applyUpdate(list.first.value, changesOrData, true));
      return list.first.value;
    } else {
      return null;
    }
  }
}
