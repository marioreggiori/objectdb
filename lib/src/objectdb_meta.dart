import 'dart:convert';

import 'package:objectdb/src/objectdb_schema.dart';

class Meta {
  final int version;
  int clientVersion;
  Schema schema;

  factory Meta(version, clientVersion, schema) {
    return Meta.internal(
        version: version, clientVersion: clientVersion, schema: schema);
  }

  factory Meta.fromMap(Map<String, dynamic> data) {
    getKey(String key) {
      if (data.containsKey(key)) return data[key];
      return null;
    }

    Schema schema = Schema.fromMap(getKey('schema'));

    return Meta.internal(
        version: getKey('version'),
        clientVersion: getKey('client_version'),
        schema: schema);
  }

  Meta.internal({this.version, this.clientVersion, this.schema});

  String toString() {
    return json.encode({
      "version": this.version,
      "client_version": this.clientVersion,
      "schema": this.schema
    });
  }
}
