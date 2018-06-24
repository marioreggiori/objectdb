library objectdb;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:execution_queue/execution_queue.dart';

enum Operator {
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

class ObjectDB {
  final String path;
  File _file;
  IOSink _writer;
  List<Map<String, dynamic>> _data;
  ExecutionQueue _executionQueue = new ExecutionQueue();
  ObjectDB({this.path}) {
    this._file = new File(this.path);
  }

  Future<ObjectDB> open([bool clean = true]) async {
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
          this._removeData(json.decode(line.substring(1)));
          break;
        }
      case '~':
        {
          var u = json.decode(line.substring(1));
          this._updateData(u['q'], u['c'], u['r']);
          break;
        }
      case '{':
        {
          this._insertData(json.decode(line));
          break;
        }
    }
  }

  Function _match(query, [Operator op = Operator.and]) {
    bool match(Map<dynamic, dynamic> test) {
      for (dynamic i in query.keys) {
        if (i is Operator) {
          bool match = this._match(query[i], i)(test);

          if (op == Operator.and && match) continue;
          if (op == Operator.and && !match) return false;

          return Operator.not == op ? !match : match;
        }
        var keyPath = i.split('.');
        dynamic testVal = test;
        for (dynamic o in keyPath) {
          if (!(testVal is Map<dynamic, dynamic>) || !testVal.containsKey(o)) {
            if (op == Operator.and)
              return false;
            else
              continue;
          }
          testVal = testVal[o];
        }

        switch (op) {
          case Operator.and:
          case Operator.not:
            {
              if (testVal != query[i]) return false;
              break;
            }
          case Operator.or:
            {
              if (testVal == query[i]) return true;
              break;
            }
          case Operator.gt:
            {
              return testVal > query[i];
            }
          case Operator.gte:
            {
              return testVal >= query[i];
            }
          case Operator.lt:
            {
              return testVal > query[i];
            }
          case Operator.lte:
            {
              return testVal >= query[i];
            }
          case Operator.ne:
            {
              return testVal != query[i];
            }
          case Operator.inArray:
            {
              return (query[i] is List) && query[i].contains(testVal);
            }
          case Operator.notInArray:
            {
              return (query[i] is List) && !query[i].contains(testVal);
            }
          default:
            {}
        }
      }

      return op == Operator.or ? false : true;
    }

    return match;
  }

  void _insertData(data) {
    this._data.add(data);
  }

  void _removeData(Map<String, dynamic> query) {
    this._data.removeWhere(this._match(query));
  }

  void _updateData(
      Map<String, dynamic> query, Map<String, dynamic> changes, bool replace) {
    outer:
    for (var i = 0; i < this._data.length; i++) {
      for (var o in query.keys) {
        if (query[o] != this._data[i][o]) {
          continue outer;
        }
      }
      for (var o in changes.keys) {
        this._data[i][o] = changes[o];
      }
    }
  }

  Future _find(query) async {
    return new Future.sync(
        (() => this._data.where(this._match(query)).toList()));
  }

  void _insert(data) {
    this._insertData(data);
    this._writer.writeln('+' + json.encode(data));
  }

  void _remove(query) {
    this._removeData(query);
    this._writer.writeln('-' + json.encode(query));
  }

  void _update(query, changes, replace) {
    this._updateData(query, changes, replace);
    this
        ._writer
        .writeln('~' + json.encode({"q": query, "c": changes, "r": replace}));
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
