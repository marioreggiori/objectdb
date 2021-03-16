import 'dart:convert';

/// Structure for database-meta-information stored in first line of db file
class Meta {
  final int version;
  final int clientVersion;

  Meta.internal({required this.version, required this.clientVersion});

  factory Meta(clientVersion) {
    return Meta.internal(version: 1, clientVersion: clientVersion);
  }

  factory Meta.fromMap(Map<String, dynamic> data) {
    getKey<T>(String key, T unsetValue) {
      if (data.containsKey(key)) return data[key];
      return unsetValue;
    }

    return Meta.internal(
        version: getKey('version', 1),
        clientVersion: getKey('client_version', 1));
  }

  factory Meta.fromString(String meta) {
    if (!meta.startsWith('\$objectdb'))
      throw ArgumentError('not a valid meta string');
    return Meta.fromMap(jsonDecode(meta.substring(9)));
  }

  Map<String, dynamic> toMap() {
    return {"version": version, "client_version": clientVersion};
  }

  @override
  String toString() {
    return '\$objectdb' + jsonEncode(toMap());
  }
}
