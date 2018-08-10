import 'dart:convert';

class Meta {
  final int version;

  factory Meta(version) {
    return new Meta.internal(version: version);
  }

  factory Meta.fromMap(Map<String, dynamic> data) {
    getKey(String key) {
      if (data.containsKey(key)) return data[key];
      return null;
    }

    return new Meta.internal(version: getKey('version'));
  }

  Meta.internal({this.version});

  String toString() {
    return json.encode({"version": this.version});
  }
}
