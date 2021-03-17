import 'dart:convert';
import 'dart:io';

import 'package:objectdb/src/objectdb_matcher.dart';
import 'package:objectdb/src/objectdb_filter.dart';
import 'package:objectdb/src/objectdb_storage_interface.dart';
import 'package:objectid/objectid.dart';
import 'package:objectdb/src/objectdb_meta.dart';
import 'package:objectdb/src/objectdb_operators.dart';

import 'objectdb_meta.dart';

var lineRegex = RegExp(r'^([^{]*)({.*)');

/// Stores data on file-system (dart:io-envs only)
class FileSystemStorage extends StorageInterface {
  late final File _fd;
  late final RandomAccessFile _raf;
  final String _path;
  final Map<String, Op> _operatorMap = {};

  int _version = 1;

  FileSystemStorage(this._path) {
    _fd = File(_path);
    Op.values.forEach((Op op) {
      _operatorMap[op.toString()] = op;
    });
  }

  @override
  Future<Meta> open([int version = 1]) async {
    _version = version;
    _raf = _fd.openSync(mode: FileMode.append);
    if (_raf.lengthSync() > 0) {
      var firstLine = await _readLine().first;
      if (firstLine.startsWith('\$objectdb')) return Meta.fromString(firstLine);
    }
    return Meta(1);
  }

  @override
  Future cleanup() async {
    var nextFile = File(_path + '.objectdb-next');
    if (nextFile.existsSync()) nextFile.deleteSync();
    var writer = nextFile.openWrite();
    writer.writeln(Meta(_version).toString());
    await for (var entry in await find({})) {
      writer.writeln(jsonEncode(entry));
    }
    await writer.close();
    File(_path).deleteSync();
    nextFile.renameSync(_path);
  }

  @override
  Future close() async {
    await _raf.close();
  }

  @override
  Future<Stream<Map<dynamic, dynamic>>> find(Map query,
      [Filter filter = Filter.all]) async {
    switch (filter) {
      case Filter.all:
      case Filter.first:
        return await _query(_raf, query);
      case Filter.last:
        return await _query(_raf, query, reversed: true);
    }
  }

  @override
  Future<ObjectId> insert(Map data) async {
    await _raf.setPosition(await _raf.length());
    var _id = ObjectId();
    data['_id'] = _id.hexString;
    _raf.writeStringSync(jsonEncode(data) + '\n');
    return _id;
  }

  @override
  Future remove(Map query) async {
    var matches = (await _query(_raf, query, reversed: true))
        .map<ObjectId>(_getId)
        .toList();

    _raf.writeStringSync(_toChange('-', _encode(query)));
    return (await matches).length;
  }

  @override
  Future update(Map query, Map changes, [bool replace = false]) async {
    var matches = (await _query(_raf, query, reversed: true))
        .map<ObjectId>(_getId)
        .toList();
    _raf.writeStringSync(_toChange(
        '~', {'q': _encode(query), 'c': _encode(changes), 'r': replace}));
    return (await matches).length;
  }

  String _toChange(String type, Map content) {
    return type + jsonEncode(content) + '\n';
  }

  Future<Stream<Map<dynamic, dynamic>>> _query(RandomAccessFile raf, Map query,
      {reversed = false}) async {
    var match = createMatcher(query);
    var changes = _withLineNumber(_readLine())
        .where((line) => line.modifier == '~' || line.modifier == '-');

    var entries =
        _withLineNumber(_readLine()).where((entry) => entry.modifier.isEmpty);

    return _applyChanges(changes, entries)
        .map<Map<dynamic, dynamic>>((line) => line.content)
        .where(match);
  }

  Stream<_Line> _applyChanges(
      Stream<_Line> changes, Stream<_Line> entries) async* {
    var changeList = await changes.toList();
    entryLoop:
    await for (var entry in entries) {
      for (var change in changeList) {
        if (change.i > entry.i) {
          if (change.modifier == '-') {
            var match = createMatcher(_decode(change.content));
            if (match(entry.content)) continue entryLoop;
          } else if (change.modifier == '~') {
            var match = createMatcher(_decode(change.content['q']));
            if (!match(entry.content)) continue;
            entry.content = StorageInterface.applyUpdate(entry.content,
                _decode(change.content['c']), change.content['r']);
          }
        }
      }
      yield entry;
    }
  }

  Stream<_Line> _withLineNumber(Stream<String> lineStream) async* {
    var nextLine = 0;
    await for (var line in lineStream) {
      var match = lineRegex.firstMatch(line);
      if (match != null) {
        yield _Line(nextLine++, match.group(1)!, jsonDecode(match.group(2)!));
      }
    }
  }

  Stream<String> _readLine() =>
      _readFile().transform(utf8.decoder).transform(LineSplitter());

  Stream<List<int>> _readFile() async* {
    var fileSize = _raf.lengthSync();
    _raf.setPositionSync(0);
    while (_raf.positionSync() < fileSize) {
      yield _raf.readSync(32);
    }
  }

  ObjectId _getId(Map<dynamic, dynamic> data) =>
      ObjectId.fromHexString(data['_id']);

  /// Replace operator enum to corresponding string
  Map _encode(Map query) {
    var prepared = {};
    for (var i in query.keys) {
      dynamic key = i;
      if (key is Op) {
        key = key.toString();
      }

      prepared[key] = _encodeValue(query[i]);
    }
    return prepared;
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Map) {
      return _encode(value);
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

    throw ArgumentError();
  }

  Map _decode(Map query) {
    var prepared = {};
    for (var i in query.keys) {
      dynamic key = i;
      if (_operatorMap.containsKey(key)) {
        key = _operatorMap[key];
      }
      if (query[i] is Map && query[i].containsKey('\$type')) {
        if (query[i]['\$type'] == 'regex') {
          prepared[key] = RegExp(query[i]['pattern']);
        }
        continue;
      }

      if (query[i] is Map) {
        prepared[key] = _decode(query[i]);
      } else if (query[i] is int ||
          query[i] is double ||
          query[i] is bool ||
          query[i] is String ||
          query[i] is List ||
          query[i] == null) {
        prepared[key] = query[i];
      } else {
        throw ArgumentError(
            "Query contains invalid data type '${query[i]?.runtimeType}'");
      }
    }
    return prepared;
  }
}

class _Line {
  final int i;
  final String modifier;
  Map content;

  _Line(this.i, this.modifier, this.content);
}
