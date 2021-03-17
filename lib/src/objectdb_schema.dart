/// Schema
/// This class must be extended when defining a schema for SchemaDB
abstract class Schema {
  String? id;
  Schema({this.id});

  /// used for retrieving the _id field (internally)
  dynamic operator [](String key) {
    if (key != '_id') throw UnimplementedError();
    return id;
  }

  /// used for setting the _id field (internally)
  void operator []=(String key, String val) {
    if (key != '_id') throw UnimplementedError();
    id = val;
  }

  /// convert Schema to serializable dynamic map (used internally)
  Map<dynamic, dynamic> toMap();

  /// convert Schema with id to serializable dynamic map (used internally)
  Map<dynamic, dynamic> toMapWithId() {
    var data = toMap();
    data.addAll({'_id': id});
    return data;
  }
}
