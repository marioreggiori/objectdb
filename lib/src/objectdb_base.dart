import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:execution_queue/execution_queue.dart';
import 'package:deeply/deeply.dart';
import 'package:objectdb/src/objectdb_operators.dart';
import 'package:objectdb/src/objectdb_filter.dart';
import 'package:objectdb/src/objectdb_meta.dart';
import 'package:objectdb/src/objectdb_objectid.dart';
import 'package:objectdb/src/objectdb_exceptions.dart';
import 'package:objectdb/src/objectdb_listener.dart';

class CRUDController {
  static ExecutionQueue _executionQueue;
  ObjectDB db;

  CRUDController(ExecutionQueue queue, {this.db}) {
    _executionQueue = queue;
  }

  setDB(ObjectDB db) {
    this.db = db;
  }

  /// get all documents that match [query]
  Future<List<Map<dynamic, dynamic>>> find(Map<dynamic, dynamic> query,
      [listener listener]) {
    try {
      if (listener != null) {
        db.listeners.add(Listener(query, listener));
      }
      return _executionQueue
          .add<List<Map<dynamic, dynamic>>>(() => db._find(query));
    } catch (e) {
      rethrow;
    }
  }

  /// get first document that matches [query]
  Future<Map<dynamic, dynamic>> first(Map<dynamic, dynamic> query) {
    try {
      return _executionQueue
          .add<Map<dynamic, dynamic>>(() => db._find(query, Filter.first));
    } catch (e) {
      rethrow;
    }
  }

  /// get last document that matches [query]
  Future<Map<dynamic, dynamic>> last(Map<dynamic, dynamic> query) {
    try {
      return _executionQueue
          .add<Map<dynamic, dynamic>>(() => db._find(query, Filter.last));
    } catch (e) {
      rethrow;
    }
  }

  /// insert document
  Future<ObjectId> insert(Map<dynamic, dynamic> doc) {
    return _executionQueue.add<ObjectId>(() => db._insert(doc));
  }

  /// insert many documents
  Future<List<ObjectId>> insertMany(List<Map<dynamic, dynamic>> docs) {
    return _executionQueue.add<List<ObjectId>>(() {
      List<ObjectId> _ids = [];
      docs.forEach((doc) {
        _ids.add(db._insert(doc));
      });
      return _ids;
    });
  }

  /// remove documents that match [query]
  Future<int> remove(query) {
    // todo: count
    return _executionQueue.add<int>(() => db._remove(query));
  }

  /// update database, takes [query], [changes] and an optional [replace] flag
  Future<int> update(Map<dynamic, dynamic> query, Map<dynamic, dynamic> changes,
      [bool replace = false]) {
    return _executionQueue.add<int>(() => db._update(query, changes, replace));
  }
}

/// Database class
class ObjectDB extends CRUDController {
  final String path;
  final int clientVersion;
  File _file;
  IOSink _writer;
  List<Map<dynamic, dynamic>> _data;
  static ExecutionQueue _executionQueue = ExecutionQueue();
  Map<String, Op> _operatorMap = Map();
  Meta _meta = Meta(1, 1);
  CRUDController crudController;
  Function onUpgrade = (CRUDController db, int oldVersion) async {
    return;
  };

  List<Listener> listeners = List<Listener>();

  ObjectDB(this.path, {this.clientVersion = 1, this.onUpgrade})
      : super(_executionQueue) {
    this.setDB(this);
    this._file = File(this.path);
    Op.values.forEach((Op op) {
      _operatorMap[op.toString()] = op;
    });
  }

  /// Opens flat file database
  Future<ObjectDB> open([bool tidy = true]) {
    return _executionQueue.add<ObjectDB>(() => this._open(tidy));
  }

  Future _open(bool tidy) async {
    var backupFile = File(this.path + '.bak');
    if (backupFile.existsSync()) {
      if (this._file.existsSync()) {
        this._file.deleteSync();
      }
      backupFile.renameSync(this.path);
      this._file = File(this.path);
    }

    if (!this._file.existsSync()) {
      this._file.createSync();
    }
    var reader = this._file.openRead();
    this._data = [];

    int oldVersion = null;

    bool firstLine = true;
    await reader
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .forEach((line) {
      if (line != '') {
        if (firstLine) {
          firstLine = false;
          if (line.startsWith("\$objectdb")) {
            try {
              _meta = Meta.fromMap(json.decode(line.substring(9)));
              if (_meta.clientVersion != clientVersion) {
                oldVersion = _meta.clientVersion;
                _meta.clientVersion = clientVersion;
              }
            } catch (e) {
              // no valid meta -> default meta
            }
            return;
          }
        }
        try {
          this._fromFile(line);
        } catch (e) {
          // skip invalid line
        }
      }
    });
    this._writer = this._file.openWrite(mode: FileMode.writeOnlyAppend);

    if (oldVersion != null) {
      var queue = ExecutionQueue();
      await onUpgrade(CRUDController(queue, db: this), oldVersion);
      await queue.add<bool>(() => true);
      return await this._tidy();
    }

    if (tidy) {
      return await this._tidy();
    }
    return this;
  }

  Future<ObjectDB> _tidy() async {
    await this._writer.close();
    await this._file.rename(this.path + '.bak');
    this._file = File(this.path);
    IOSink writer = this._file.openWrite();
    writer.writeln('\$objectdb' + this._meta.toString());
    writer.writeAll(this._data.map((data) => json.encode(data)), '\n');
    writer.write('\n');
    await writer.flush();
    await writer.close();

    var backupFile = File(this.path + '.bak');
    await backupFile.delete();

    return await this._open(false);
  }

  void _fromFile(String line) {
    switch (line[0]) {
      case '+':
        {
          this._insertData(json.decode(line.substring(1)));
          break;
        }
      case '-':
        {
          this._removeData(this._decode(json.decode(line.substring(1))));
          break;
        }
      case '~':
        {
          var u = json.decode(line.substring(1));
          this._updateData(this._decode(u['q']), this._decode(u['c']), u['r']);
          break;
        }
      case '{':
        {
          this._insertData(json.decode(line));
          break;
        }
    }
  }

  Function _match(query, [Op op = Op.and]) {
    bool match(Map<dynamic, dynamic> test) {
      keyloop:
      for (dynamic i in query.keys) {
        if (i is Op) {
          bool match = this._match(query[i], i)(test);

          if (op == Op.and && match) continue;
          if (op == Op.and && !match) return false;

          if (op == Op.or && !match) continue;
          if (op == Op.or && match) return true;

          return Op.not == op ? !match : match;
        }

        if (query[i] is ObjectId) {
          query[i] = query[i].toString();
        }

        var keyPath = i.split('.');
        dynamic testVal = test;
        for (dynamic o in keyPath) {
          if (!(testVal is Map<dynamic, dynamic>) || !testVal.containsKey(o)) {
            if (op != Op.or) {
              return false;
            } else {
              continue keyloop;
            }
          }
          testVal = testVal[o];
        }

        if (op != Op.inList &&
            op != Op.notInList &&
            (!(query[i] is RegExp) && (op != Op.and && op != Op.or)) &&
            testVal.runtimeType != query[i].runtimeType) continue;

        switch (op) {
          case Op.and:
          case Op.not:
            {
              if (query[i] is RegExp) {
                if (!query[i].hasMatch(testVal)) return false;
                break;
              }
              if (testVal != query[i]) return false;
              break;
            }
          case Op.or:
            {
              if (query[i] is RegExp) {
                if (query[i].hasMatch(testVal)) return true;
                break;
              }
              if (testVal == query[i]) return true;
              break;
            }
          case Op.gt:
            {
              if (testVal is String) {
                return testVal.compareTo(query[i]) > 0;
              }
              return testVal > query[i];
            }
          case Op.gte:
            {
              if (testVal is String) {
                return testVal.compareTo(query[i]) >= 0;
              }
              return testVal >= query[i];
            }
          case Op.lt:
            {
              if (testVal is String) {
                return testVal.compareTo(query[i]) < 0;
              }
              return testVal < query[i];
            }
          case Op.lte:
            {
              if (testVal is String) {
                return testVal.compareTo(query[i]) <= 0;
              }
              return testVal <= query[i];
            }
          case Op.ne:
            {
              return testVal != query[i];
            }
          case Op.inList:
            {
              return (query[i] is List) && query[i].contains(testVal);
            }
          case Op.notInList:
            {
              return (query[i] is List) && !query[i].contains(testVal);
            }
          default:
            {}
        }
      }

      return op == Op.or ? false : true;
    }

    return match;
  }

  void _push(Method method, dynamic data) {
    listeners.forEach((listener) {
      Function match = _match(listener.query);
      switch (method) {
        case Method.add:
          {
            if (match(data)) {
              listener.callback(Method.add, data);
            }
            break;
          }
        case Method.remove:
          {
            listener.callback(Method.remove, data);
            break;
          }
        case Method.update:
          {
            if (match(data)) {
              listener.callback(Method.update, data);
            } else {
              listener.callback(Method.remove, [data['_id']]);
            }
            break;
          }
      }
    });
  }

  void _insertData(Map data) {
    if (!data.containsKey('_id')) {
      data['_id'] = ObjectId().toString();
    }
    _push(Method.add, data);
    this._data.add(data);
  }

  int _removeData(Map<dynamic, dynamic> query) {
    List match =
        this._data.where(this._match(query)).map((doc) => doc['_id']).toList();
    int count = match.length;
    _push(Method.remove, match);
    this._data.removeWhere(this._match(query));
    return count;
  }

  int _updateData(Map<dynamic, dynamic> query, Map<dynamic, dynamic> changes,
      bool replace) {
    int count = 0;
    var matcher = this._match(query);
    for (var i = 0; i < this._data.length; i++) {
      if (!matcher(this._data[i])) continue;
      count++;

      if (replace) this._data[i] = Map<dynamic, dynamic>();

      for (var o in changes.keys) {
        if (o is Op) {
          for (String p in changes[o].keys) {
            var keyPath = p.split('.');
            switch (o) {
              case Op.set:
                {
                  this._data[i] = updateDeeply(
                      keyPath, this._data[i], (value) => changes[o][p]);
                  break;
                }
              case Op.unset:
                {
                  if (changes[o][p] == true) {
                    this._data[i] = removeDeeply(keyPath, this._data[i]);
                  }
                  break;
                }
              case Op.max:
                {
                  this._data[i] = updateDeeply(
                      keyPath,
                      this._data[i],
                      (value) => value > changes[o][p] ? changes[o][p] : value,
                      0);
                  break;
                }
              case Op.min:
                {
                  this._data[i] = updateDeeply(
                      keyPath,
                      this._data[i],
                      (value) => value < changes[o][p] ? changes[o][p] : value,
                      0);
                  break;
                }
              case Op.increment:
                {
                  this._data[i] = updateDeeply(keyPath, this._data[i],
                      (value) => value += changes[o][p], 0);
                  break;
                }
              case Op.multiply:
                {
                  this._data[i] = updateDeeply(keyPath, this._data[i],
                      (value) => value *= changes[o][p], 0);
                  break;
                }
              case Op.rename:
                {
                  this._data[i] =
                      renameDeeply(keyPath, changes[o][p], this._data[i]);
                  break;
                }
              default:
                {
                  throw 'invalid';
                }
            }
          }
        } else {
          this._data[i][o] = changes[o];
        }
      }
      _push(Method.update, this._data[i]);
    }

    return count;
  }

  /// Find data in cached database object
  Future _find(query, [Filter filter = Filter.all]) async {
    return Future.sync((() {
      var match = this._match(query);
      if (filter == Filter.all) {
        return this._data.where(match).toList();
      }
      if (filter == Filter.first) {
        return this._data.firstWhere(match, orElse: () => null);
      } else {
        return this._data.lastWhere(match, orElse: () => null);
      }
    }));
  }

  /// Insert [data] update cache object and write change to file
  ObjectId _insert(data) {
    ObjectId _id = ObjectId();
    data['_id'] = _id.toString();
    try {
      this._writer.writeln('+' + json.encode(data));
      this._insertData(data);
    } catch (e) {
      throw ObjectDBException('data contains invalid data types');
    }
    return _id;
  }

  /// Replace operator string to corresponding enum
  Map _decode(Map query) {
    Map prepared = Map();
    for (var i in query.keys) {
      dynamic key = i;
      if (this._operatorMap.containsKey(key)) {
        key = this._operatorMap[key];
      }
      if (query[i] is Map && query[i].containsKey('\$type')) {
        if (query[i]['\$type'] == 'regex') {
          prepared[key] = RegExp(query[i]['pattern']);
        }
        continue;
      }

      if (query[i] is Map) {
        prepared[key] = this._decode(query[i]);
      } else if (query[i] is int ||
          query[i] is double ||
          query[i] is bool ||
          query[i] is String ||
          query[i] is List) {
        prepared[key] = query[i];
      } else {
        throw ObjectDBException('query contains invalid data types');
      }
    }
    return prepared;
  }

  /// Replace operator enum to corresponding string
  Map _encode(Map query) {
    Map prepared = Map();
    for (var i in query.keys) {
      dynamic key = i;
      if (key is Op) {
        key = key.toString();
      }

      prepared[key] = this._encodeValue(query[i]);
    }
    return prepared;
  }

  _encodeValue(dynamic value) {
    if (value is Map) {
      return this._encode(value);
    }
    if (value is String ||
        value is int ||
        value is double ||
        value is bool ||
        value is List) {
      return value;
    }
    if (value is RegExp) {
      return {'\$type': 'regex', 'pattern': value.pattern};
    }
  }

  int _remove(Map query) {
    this._writer.writeln('-' + json.encode(this._encode(query)));
    return this._removeData(query);
  }

  int _update(query, changes, replace) {
    this._writer.writeln('~' +
        json.encode({
          'q': this._encode(query),
          'c': this._encode(changes),
          'r': replace
        }));
    return this._updateData(query, changes, replace);
  }

  /// 'tidy up' .db file
  Future<ObjectDB> tidy() {
    return _executionQueue.add<ObjectDB>(() => this._tidy());
  }

  /// close db
  Future close() {
    return _executionQueue.add(() async {
      await this._writer.close();
    });
  }
}
