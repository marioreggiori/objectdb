library objectdb;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:execution_queue/execution_queue.dart';

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

  _clean() async {
    await this._writer.close();
    await this._file.rename(this.path + '.bak');
    this._file = new File(this.path);
    var writer = this._file.openWrite();
    writer.writeAll(this._data.map((data) => json.encode(data)), '\n');
    writer.write('\n');
    await writer.flush();
    await writer.close();
    return await this.open(false);
  }

  _fromFile(String line) {
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

  _query(query) {
    return (Map<String, dynamic> test) {
      for (var i in query.keys) {
        if (test[i] != query[i]) {
          return false;
        }
      }
      return true;
    };
  }

  _insertData(data) {
    this._data.add(data);
  }

  _removeData(Map<String, dynamic> query) {
    this._data.removeWhere(this._query(query));
  }

  _updateData(
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

  _find(query) async {
    return new Future.sync(
        (() => this._data.where(this._query(query)).toList()));
  }

  _insert(data) {
    this._insertData(data);
    this._writer.writeln('+' + json.encode(data));
  }

  _remove(query) {
    this._removeData(query);
    this._writer.writeln('-' + json.encode(query));
  }

  _update(query, changes, replace) {
    this._updateData(query, changes, replace);
    this
        ._writer
        .writeln('~' + json.encode({"q": query, "c": changes, "r": replace}));
  }

  /**
   * get all documents that match [query]
   */
  find(Map<String, dynamic> query) {
    return this._executionQueue.add(() => this._find(query));
  }

  /**
   * insert document
   */
  insert(Map<String, dynamic> doc) async {
    return this._executionQueue.add(() => this._insert(doc));
  }

  /**
   * remove documents that match [query]
   */
  remove(query) async {
    return this._executionQueue.add(() => this._remove(query));
  }

  /**
   * update database, takes [query], [changes] and an optional [replace] flag
   */
  update(Map<String, dynamic> query, Map<String, dynamic> changes,
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
}
