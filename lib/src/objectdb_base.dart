import 'dart:async';
import 'package:execution_queue/execution_queue.dart';
import 'package:objectdb/src/objectdb_filter.dart';
import 'package:objectdb/src/objectdb_meta.dart';
import 'package:objectdb/src/objectdb_listener.dart';
import 'package:objectdb/src/objectdb_schema.dart';
import 'package:objectdb/src/objectdb_storage_interface.dart';
import 'package:objectid/objectid.dart';

typedef SchemaDBItemCreator<S> = S Function(Map<dynamic, dynamic>);

/// SchemaDB
class SchemaDB<T extends Schema> extends _ObjectDB<T> {
  final SchemaDBItemCreator<T> _creator;
  SchemaDB(storage, this._creator, {version = 1, OnUpgrade? onUpgrade})
      : super(storage, v: version, onUpgrade: onUpgrade);

  @override
  T createItem(Map<dynamic, dynamic> data) {
    var obj = _creator(data);
    obj['_id'] = data['_id'];
    return obj;
  }

  @override
  Map<dynamic, dynamic> itemToMap(T item) => item.toMapWithId();
}

/// ObjectDB
class ObjectDB extends _ObjectDB<Map<dynamic, dynamic>> {
  ObjectDB(storage, {version = 1, OnUpgrade? onUpgrade})
      : super(storage, v: version, onUpgrade: onUpgrade);

  @override
  Map<dynamic, dynamic> createItem(Map<dynamic, dynamic> data) => data;

  @override
  Map<dynamic, dynamic> itemToMap(Map<dynamic, dynamic> item) => item;
}

typedef OnUpgrade<T> = Future Function(
    UpdateController storage, int oldVersion);

abstract class CRUDController<T> {
  final StorageInterface _storage;
  final ExecutionQueue _executionQueue = ExecutionQueue();
  final List<Listener> _listeners = [];

  CRUDController(this._storage);

  /// convert dynamic map to concrete type T (opposite of itemToMap)
  T createItem(Map<dynamic, dynamic> data) {
    throw UnimplementedError();
  }

  /// convert concrete type T to dynamic map (opposite of createItem)
  Map<dynamic, dynamic> itemToMap(T item) {
    throw UnimplementedError();
  }

  /// get all documents that match [query] with optional change-[listener]
  Future<List<T>> find(
      [Map<dynamic, dynamic> query = const {}, ListenerCallback? listener]) {
    try {
      if (listener != null) {
        _listeners.add(Listener(query, listener));
      }
      return _executionQueue.add<List<T>>(() async =>
          await (await _storage.find(query)).map<T>(createItem).toList());
    } catch (e) {
      rethrow;
    }
  }

  /// get first document that matches [query]
  Future<T> first([Map<dynamic, dynamic> query = const {}]) {
    try {
      return _executionQueue.add<T>(() async =>
          createItem(await (await _storage.find(query, Filter.first)).first));
    } catch (e) {
      rethrow;
    }
  }

  /// get last document that matches [query]
  Future<T> last([Map<dynamic, dynamic> query = const {}]) {
    try {
      return _executionQueue.add<T>(() async =>
          createItem(await (await _storage.find(query, Filter.last)).first));
    } catch (e) {
      rethrow;
    }
  }

  /// insert document
  Future<ObjectId> insert(T doc) =>
      _executionQueue.add<ObjectId>(() => _storage.insert(itemToMap(doc)));

  /// insert many documents
  Future<List<ObjectId>> insertMany(List<T> docs) {
    return _executionQueue.add<List<ObjectId>>(() async {
      var _ids = <ObjectId>[];
      for (var doc in docs) {
        _ids.add(await _storage.insert(itemToMap(doc)));
      }
      return _ids;
    });
  }

  /// remove documents that match [query]
  Future<int> remove(query) =>
      _executionQueue.add<int>(() => _storage.remove(query));

  /// update database, takes [query], [changes] and an optional [replace] flag
  Future<int> update(Map<dynamic, dynamic> query, Map<dynamic, dynamic> changes,
      [bool replace = false]) {
    return _executionQueue
        .add<int>(() => _storage.update(query, changes, replace));
  }

  /// trigger storage cleanup (f.e. condense storage file)
  Future cleanup() => _executionQueue.add(_storage.cleanup);

  /// returns future to await all previous db actions
  Future wait() => _executionQueue.add(() async {});
}

class UpdateController extends CRUDController<Map<dynamic, dynamic>> {
  UpdateController(StorageInterface storage) : super(storage);

  @override
  Map<dynamic, dynamic> createItem(Map<dynamic, dynamic> data) => data;

  @override
  Map<dynamic, dynamic> itemToMap(Map<dynamic, dynamic> item) => item;
}

/// Database class
class _ObjectDB<T> extends CRUDController<T> {
  // database version
  final int v;

  // database metadata (saved in first line of file)
  late final Meta _meta;

  // default (empty) onUpgrade handler
  OnUpgrade<T>? onUpgrade;

  _ObjectDB(storage, {this.v = 1, this.onUpgrade}) : super(storage) {
    _executionQueue.add(_open);
  }

  /// Opens flat file database
  Future _open() async {
    _meta = await _storage.open(v);
    if (onUpgrade != null && _meta.clientVersion < v) {
      var controller = UpdateController(_storage);
      await onUpgrade!(controller, _meta.clientVersion);
      await controller.cleanup();
    }
  }

  /// close db
  Future close() => _executionQueue.add(_storage.close);
}
