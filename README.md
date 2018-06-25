# ObjectDB

Embeded persistent Flutter NoSQL database. 100% Dart.

**CAUTION** This plugin is still in development. **Use at your own risk**. If you notice any bugs you can [create](https://github.com/netz-chat/objectdb/issues/new 'Create issue') an issue on GitHub. You're also welcome to contribute using [pull requests](https://github.com/netz-chat/objectdb/compare 'Pull request'). Please open an issue before spending time on any pull request.


## How to use
```dart
final path = Directory.current.path + '/my.db';

// create database instance and open
final db = ObjectDB(path: path);
await db.open();

// insert document into database
db.insert({'name': {'first': 'Some', 'last': 'Body'}, 'age': 18, 'active': false);
db.insert({'name': {'first': 'Someone', 'last': 'Else'}, 'age': 25, 'active': false);

// update documents
db.update({Op.gte: {'age': 80}}, {'active': false});

// delete documents
db.delete({'active': false});

// search documents in database
var result = await db.find({'active': true});

// reformat db file
await db.clean();
```

## Operators
### Logical
- `and` (default operator on first level)
- `or`
- `not`

### Comparison
- `lt`, `lte`: less than, less than or equal
- `gt`, `gte`: greater than, greater than or equal
- `inList`, `notInList`: value in list, value not in list

### Examples
```dart
// query
var result = db.find({
    'active': true,
    Op.or: {
        Op.inList: {'state': ['Florida', 'Virginia', 'New Jersey']},
        Op.gte: {'age': 30},
    }
});

// same as
var match = (result['active'] == true && (['Florida', 'Virginia', 'New Jersey'].contains(result['state']) || result['age'] >= 30));
```

## License
See [License](https://github.com/netz-chat/objectdb/blob/master/LICENSE)