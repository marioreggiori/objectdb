library objectdb;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:execution_queue/execution_queue.dart';
import 'package:bson_objectid/bson_objectid.dart';

/// Query operators
enum Op {
  and,
  or,
  not,

  lt,
  gt,
  lte,
  gte,
  ne,

  inList,
  notInList
}

enum _Filter {
  all,
  first,
  last,
}

class _Meta {
  final int version;

  factory _Meta(version) {
    return new _Meta.internal(version: version);
  }

  factory _Meta.fromMap(Map<String, dynamic> data) {
    getKey(String key) {
      if (data.containsKey(key)) return data[key];
      return null;
    }

    return new _Meta.internal(version: getKey('version'));
  }

  _Meta.internal({this.version});

  String toString() {
    return json.encode({"version": this.version});
  }
}

/// Database class
class ObjectDB {
  final String path;
  File _file;
  IOSink _writer;
  List<Map<String, dynamic>> _data;
  ExecutionQueue _executionQueue = ExecutionQueue();
  Map<String, Op> _operatorMap = Map();
  _Meta _meta;

  ObjectDB(this.path) {
    this._file = File(this.path);

    Op.values.forEach((Op op) {
      _operatorMap[op.toString()] = op;
    });
  }

  /// Opens flat file database
  Future open([bool tidy = true]) {
    return this._executionQueue.add(() => this._open(tidy));
  }

  Future _open(bool tidy) async {
    if (!this._file.existsSync()) {
      this._file.createSync();
    }
    var reader = this._file.openRead();
    this._data = [];
    bool firstLine = true;
    await reader
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .forEach((line) {
      if (line != '') {
        if (firstLine) {
          firstLine = false;
          if (line.startsWith("\$objectdb")) {
            try {
              this._meta = _Meta.fromMap(json.decode(line.substring(9)));
            } catch (e) {
              // no valid meta -> default meta
              this._meta = _Meta(1);
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
          this._updateData(this._decode(u['q']), u['c'], u['r']);
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
        var keyPath = i.split('.');
        dynamic testVal = test;
        for (dynamic o in keyPath) {
          if (!(testVal is Map<dynamic, dynamic>) || !testVal.containsKey(o)) {
            if (op != Op.or)
              return false;
            else
              continue keyloop;
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

  void _insertData(Map data) {
    if (!data.containsKey('_id')) {
      data['_id'] = ObjectId().toString();
    }
    this._data.add(data);
  }

  int _removeData(Map<dynamic, dynamic> query) {
    int count = this._data.where(this._match(query)).length;
    this._data.removeWhere(this._match(query));
    return count;
  }

  int _updateData(
      Map<dynamic, dynamic> query, Map<String, dynamic> changes, bool replace) {
    int count = 0;
    var matcher = this._match(query);
    for (var i = 0; i < this._data.length; i++) {
      if (!matcher(this._data[i])) continue;
      count++;
      for (var o in changes.keys) {
        this._data[i][o] = changes[o];
      }
    }
    return count;
  }

  /// Find data in cached database object
  Future _find(query, [_Filter filter = _Filter.all]) async {
    return Future.sync((() {
      var match = this._match(query);
      if (filter == _Filter.all) {
        return this._data.where(match).toList();
      }
      if (filter == _Filter.first) {
        return this._data.firstWhere(match);
      } else {
        return this._data.lastWhere(match);
      }
    }));
  }

  /// Insert [data] update cache object and write change to file
  ObjectId _insert(data) {
    ObjectId _id = ObjectId();
    data['_id'] = _id.toString();
    this._writer.writeln('+' + json.encode(data));
    this._insertData(data);
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
      } else {
        prepared[key] = query[i];
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
    if (value is String || value is int || value is bool || value is List) {
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
        json.encode({'q': this._encode(query), 'c': changes, 'r': replace}));
    return this._updateData(query, changes, replace);
  }

  /// get all documents that match [query]
  Future find(Map<dynamic, dynamic> query) {
    try {
      return this._executionQueue.add(() => this._find(query));
    } catch (e) {
      throw (e);
    }
  }

  /// get first document that matches [query]
  Future first(Map<dynamic, dynamic> query) {
    try {
      return this._executionQueue.add(() => this._find(query, _Filter.first));
    } catch (e) {
      throw (e);
    }
  }

  /// get last document that matches [query]
  Future last(Map<dynamic, dynamic> query) {
    try {
      return this._executionQueue.add(() => this._find(query, _Filter.last));
    } catch (e) {
      throw (e);
    }
  }

  /// insert document
  Future insert(Map<String, dynamic> doc) {
    return this._executionQueue.add(() => this._insert(doc));
  }

  /// insert many documents
  Future insertMany(List<Map<String, dynamic>> docs) {
    return this._executionQueue.add(() {
      List<ObjectId> _ids = [];
      docs.forEach((doc) {
        _ids.add(this._insert(doc));
      });
      return _ids;
    });
  }

  /// remove documents that match [query]
  Future remove(query) {
    // todo: count
    return this._executionQueue.add(() => this._remove(query));
  }

  /// update database, takes [query], [changes] and an optional [replace] flag
  Future update(Map<dynamic, dynamic> query, Map<String, dynamic> changes,
      [bool replace = false]) {
    // todo: count
    return this
        ._executionQueue
        .add(() => this._update(query, changes, replace));
  }

  /// 'tidy up' .db file
  Future tidy() {
    return this._executionQueue.add(() => this._tidy());
  }

  /// close db
  Future close() {
    return this._executionQueue.add(() async {
      await this._writer.close();
    });
  }
}
