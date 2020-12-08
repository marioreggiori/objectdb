import 'dart:convert';

/// Structure for database-meta-information stored in first line of db file
class Meta {
  final int version;
  int clientVersion;

  factory Meta(version, clientVersion) {
    return Meta.internal(version: version, clientVersion: clientVersion);
  }

  factory Meta.fromMap(Map<String, dynamic> data) {
    getKey(String key) {
      if (data.containsKey(key)) return data[key];
      return null;
    }

    return Meta.internal(
        version: getKey('version'), clientVersion: getKey('client_version'));
  }

  Meta.internal({this.version, this.clientVersion});

  String toString() {
    return json.encode(
        {"version": this.version, "client_version": this.clientVersion});
  }
}
