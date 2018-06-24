library objectdb;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:execution_queue/execution_queue.dart';

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

  inArray,
  notInArray
}

/// Database class
class ObjectDB {
  final String path;
  File _file;
  IOSink _writer;
  List<Map<String, dynamic>> _data;
  ExecutionQueue _executionQueue = new ExecutionQueue();

  Map<String, Op> _operatorMap = Map();

  ObjectDB({this.path}) {
    this._file = new File(this.path);

    Op.values.forEach((Op op) {
      _operatorMap[op.toString()] = op;
    });
  }

  /// Opens flat file database
  Future open([bool clean = true]) async {
    var reader = this._file.openRead();
    this._data = [];
    await reader
        .transform(utf8.decoder)
        .transform(new LineSplitter())
        .forEach((line) => this._fromFile(line));
    this._writer = this._file.openWrite(mode: FileMode.writeOnlyAppend);
    if (clean) {
      return this.clean();
    }
    return this;
  }

  Future<ObjectDB> _clean() async {
    await this._writer.close();
    await this._file.rename(this.path + '.bak');
    this._file = new File(this.path);
    IOSink writer = this._file.openWrite();
    writer.writeAll(this._data.map((data) => json.encode(data)), '\n');
    writer.write('\n');
    await writer.flush();
    await writer.close();
    return await this.open(false);
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
            if (op == Op.and)
              return false;
            else
              continue keyloop;
          }
          testVal = testVal[o];
        }

        switch (op) {
          case Op.and:
          case Op.not:
            {
              if (testVal != query[i]) return false;
              break;
            }
          case Op.or:
            {
              if (testVal == query[i]) return true;
              break;
            }
          case Op.gt:
            {
              return testVal > query[i];
            }
          case Op.gte:
            {
              return testVal >= query[i];
            }
          case Op.lt:
            {
              return testVal < query[i];
            }
          case Op.lte:
            {
              return testVal <= query[i];
            }
          case Op.ne:
            {
              return testVal != query[i];
            }
          case Op.inArray:
            {
              return (query[i] is List) && query[i].contains(testVal);
            }
          case Op.notInArray:
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

  void _insertData(data) {
    this._data.add(data);
  }

  void _removeData(Map<dynamic, dynamic> query) {
    this._data.removeWhere(this._match(query));
  }

  void _updateData(
      Map<dynamic, dynamic> query, Map<String, dynamic> changes, bool replace) {
    var matcher = this._match(query);
    for (var i = 0; i < this._data.length; i++) {
      if (!matcher(this._data[i])) continue;
      for (var o in changes.keys) {
        this._data[i][o] = changes[o];
      }
    }
  }

  /// Find data in cached database object
  Future _find(query) async {
    return new Future.sync(
        (() => this._data.where(this._match(query)).toList()));
  }

  /// Insert [data] update cache object and write change to file
  void _insert(data) {
    this._insertData(data);
    this._writer.writeln('+' + json.encode(data));
  }

  /// Replace operator string to corresponding enum
  Map _decode(Map query) {
    Map prepared = Map();
    for (var i in query.keys) {
      dynamic key = i;
      if (this._operatorMap.containsKey(key)) {
        key = this._operatorMap[key];
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
      if (query[i] is Map) {
        prepared[key] = this._encode(query[i]);
      } else {
        prepared[key] = query[i];
      }
    }
    return prepared;
  }

  void _remove(Map query) {
    this._removeData(query);
    this._writer.writeln('-' + json.encode(this._encode(query)));
  }

  void _update(query, changes, replace) {
    this._updateData(query, changes, replace);
    this._writer.writeln('~' +
        json.encode({"q": this._encode(query), "c": changes, "r": replace}));
  }

  /**
   * get all documents that match [query]
   */
  Future find(Map<dynamic, dynamic> query) {
    return this._executionQueue.add(() => this._find(query));
  }

  /**
   * insert document
   */
  Future insert(Map<String, dynamic> doc) async {
    return this._executionQueue.add(() => this._insert(doc));
  }

  /**
   * remove documents that match [query]
   */
  Future remove(query) async {
    return this._executionQueue.add(() => this._remove(query));
  }

  /**
   * update database, takes [query], [changes] and an optional [replace] flag
   */
  Future update(Map<String, dynamic> query, Map<String, dynamic> changes,
      [bool replace = false]) async {
    return this
        ._executionQueue
        .add(() => this._update(query, changes, replace));
  }

  /**
   * reformat db file
   */
  Future clean() async {
    return this._executionQueue.add(() => this._clean());
  }

  Future close() async {
    return this._executionQueue.add(() async {
      await this._writer.close();
    });
  }
}
