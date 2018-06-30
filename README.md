# ObjectDB

[![Pub](https://img.shields.io/pub/v/objectdb.svg)](https://pub.dartlang.org/packages/objectdb)
[![license](https://img.shields.io/github/license/netz-chat/objectdb.svg)](https://github.com/netz-chat/objectdb/blob/master/LICENSE)

Persistent embedded document-oriented NoSQL database for [Dart](https://www.dartlang.org/) and [Flutter](https://flutter.io/). 100% Dart.

**CAUTION** This plugin is still in development. **Use at your own risk**. If you notice any bugs you can [create](https://github.com/netz-chat/objectdb/issues/new 'Create issue') an issue on GitHub. You're also welcome to contribute using [pull requests](https://github.com/netz-chat/objectdb/compare 'Pull request'). Please open an issue before spending time on any pull request.


- [How to use](#how-to-use)
- [Methods](#methods)
    - [find](#find)
    - [insert](#insert)
    - [update](#update)
    - [delete](#delete)
- [Query](#query)
- [Operators](#operators)
    - [Logical](#logical)
    - [Comparison](#comparison)
    - [Examples](#examples)
- [Todo's](#todos)



## How to use
```dart
final path = Directory.current.path + '/my.db';

// create database instance and open
final db = ObjectDB(path);
db.open();

// insert document into database
db.insert({'name': {'first': 'Some', 'last': 'Body'}, 'age': 18, 'active': true);
db.insert({'name': {'first': 'Someone', 'last': 'Else'}, 'age': 25, 'active': false);

// update documents
db.update({Op.gte: {'age': 80}}, {'active': false});

// delete documents
db.delete({'active': false});

// search documents in database
var result = await db.find({'active': true, 'name.first': 'Some'});

// 'tidy up' the db file
db.tidy();

// close db
await db.close();
```

## Methods
- `Future<ObjectDB> db.open([bool tidy = true])` opens database
- `Future<void> db.tidy()` 'tidy up' the .db file
- `Future<void> db.close()` closes database (should be awaited to ensure all queries have been executed)

### find
- `Future<List<Map>> db.find(Map query)` List with all matched documents
- `Future<Map> db.first(Map query)` first matched document
- `Future<Map> db.last(Map query)` last matched document

### insert
- `Future<ObjectId> db.insert(Map document)` insert single document
- `Future<List<ObjectId>> db.insertMany(List<Map> documents)` insert many documents

### update
- `Future<int> db.update(Map query, Map changes, [bool replace = false])` update documents that mach `query` with `changes` (optionally replace whole document)

### delete
- `Future<int> db.delete(Map query)` delete documents that match `query`

## Query
```dart
// Match fields in subdocuments
{Op.gte: {
    'birthday.year': 18
}}

// or-operator
{Op.or:{
    'active': true,
    Op.inArray: {'group': ['admin', 'moderator']}
}}

// not equal to
{Op.not: {'active': false}}
```
**NOTE** Querying arrays is not supportet yet.

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

## Todo's
- [x] regex match
- [ ] encryption
- [ ] benchmarks
- [ ] indexing

## License
See [License](https://github.com/netz-chat/objectdb/blob/master/LICENSE)