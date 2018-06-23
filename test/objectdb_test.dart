import 'package:test/test.dart';
import 'dart:io';
import 'package:objectdb/objectdb.dart';

void main() {
  test('store objects in flatfile db', () async {
    final path = Directory.current.path + '/test/test.db';
    final file = File(path);
    file.writeAsStringSync("");

    final db = await ObjectDB(path: path).open(false);

    await db.insert({"a": 1, "b": 2, "c": 3});
    await db.insert({"a": 4, "b": 5, "c": 6});
    await db.insert({"a": 7, "b": 8, "c": 9});
    await db.insert({"a": 1, "b": 2, "c": 3});
    await db.insert({"a": 4, "b": 5, "c": 6});
    await db.insert({"a": 7, "b": 8, "c": 9});

    await db.update({"a": 4}, {"c": "tada"});
    await db.remove({"b": 2});

    await db.clean();

    var result = await db.find({});

    expect(result[0]['c'], 'tada');
    expect(result[1]['b'], 8);
  });
}
