import 'dart:io';
import 'package:test/test.dart';
import 'package:objectdb/objectdb.dart';

void main() async {
  // init test.db
  File file;
  final path = Directory.current.path + '/test/';
  file = File(path + 'shopping_carts.db');
  if (file.existsSync()) {
    file.deleteSync();
  }

  ObjectDB db;

  test('array queries', () async {
    db = await ObjectDB(path + 'shopping_carts.db').open();
    db.insert({
      "customer": "a",
      "cart": [
        {
          "prod_no": "qYxtY",
          "prod_name": "Item 1",
          "qty": 5,
          "unit_price": 6.99
        },
        {
          "prod_no": "Ykcz6",
          "prod_name": "Item 2",
          "qty": 20,
          "unit_price": 9.99
        },
        {
          "prod_no": "mUJvP",
          "prod_name": "Item 3",
          "qty": 1,
          "unit_price": 2.99
        },
      ],
    });

    db.insert({
      "customer": "b",
      "cart": [
        {
          "prod_no": "Ykcz6",
          "prod_name": "Item 2",
          "qty": 20,
          "unit_price": 9.99
        },
        {
          "prod_no": "xn6YH",
          "prod_name": "Item 4",
          "qty": 7,
          "unit_price": 29.99
        },
      ],
    });

    await db.close();
    await db.open();

    var res0 = await db.find({"cart[]prod_name": "Item 5"});
    expect(res0.length, 0);

    var res1 = await db.find({"cart[]prod_name": "Item 4"});
    expect(res1.length, 1);
    expect(res1[0]["customer"], "b");

    var res2 = await db.find({"cart[]prod_name": "Item 2"});
    expect(res2.length, 2);
    expect(res2[0]["customer"], "a");
    expect(res2[1]["customer"], "b");

    var res3 = await db.find({
      Op.lte: {'cart[]unit_price': 5.0}
    });
    expect(res3.length, 1);
    expect(res3[0]["customer"], "a");
  });
}
