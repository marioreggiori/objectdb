# ObjectDB

Flutter NoSQL Database.

```dart
final path = Directory.current.path + '/my.db';

// create database instance and open
final db = await ObjectDB(path: path).open();

// insert document into database
await db.insert({"name": {"first": "Some", "last": "Body"}, "age": 18, "active": false);
await db.insert({"name": {"first": "Someone", "last": "Else"}, "age": 25, "active": false);

// update documents
await db.update({"age": 18}, {"active": true});

// delete documents
await db.delete({"active": false});

// search documents in database
var result = await db.find({"active": true});

// reformat db file
await db.clean();
```