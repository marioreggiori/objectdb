import 'package:objectdb/objectdb.dart';

void main() async {
  // open db
  var db = ObjectDB('/some/path/to/file.db');
  db.open();

  // insert documents
  await db.insertMany([
    {
      "name": {"first": "Maria", "last": "Smith"},
      "age": 20,
      "active": false
    },
    {
      "name": {"first": "James", "last": "Jones"},
      "age": 32,
      "active": false
    },
  ]);

  // update documents
  db.update({"name.first": "Maria"}, {"active": true});

  // remove documents
  db.remove({
    Op.inList: {
      "name.last": ["Jones", "Miller", "Wilson"]
    },
    "active": false,
  });

  // find documents
  print(await db.find({
    Op.lte: {"age": 30}
  }));

  // close db
  await db.close();
}
