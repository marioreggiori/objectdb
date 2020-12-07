import 'objectdb_exceptions.dart';
import 'dart:convert';

class Schema {
  Map schema = {};

  Schema(Map<String, String> data) {
    schema = data;
  }

  factory Schema.fromMap(Map data) {
    Map schema = {};

    data.forEach((key, value) {
      schema[key] = value.runtimeType.toString();
    });

    return Schema(schema);
  }

  factory Schema.fromJSON(String raw) {
    Map schema = json.decode(raw);
    return Schema(schema);
  }

  bool validateSchema(Map data) {
    if (this.schema.length == 0) {
      new ObjectDBException("Schema is not initialized");
    }

    data.forEach((key, value) {
      // check if schema contains all keys
      if (!this.schema.containsKey(key)) {
        return false;
      }

      // check if types match
      if (this.schema[key] != data[key].runtimeType.toString()) {
        return false;
      }
    });

    return true;
  }

  String toString() {
    return json.encode(this.schema);
  }
}
