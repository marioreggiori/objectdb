class Schema {
  String id;
  Schema({this.id});

  dynamic operator [](String key) {
    if (key != '_id') throw UnimplementedError();
    return id;
  }

  void operator []=(String key, String val) {
    if (key != '_id') throw UnimplementedError();
    id = val;
  }

  Map<dynamic, dynamic> toMap() {
    throw UnimplementedError();
  }

  Map<dynamic, dynamic> toMapWithId() {
    var data = toMap();
    data.addAll({'_id': id});
    return data;
  }
}
