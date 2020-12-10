import 'dart:io';
import 'package:test/test.dart';
import 'package:objectdb/objectdb.dart';

class UserSchema extends Schema {
  String _username;
  String _email;
  DateTime _birthyear;

  set username(val) => _username = val;
  set email(val) => _email = val;
  set birthyear(val) => _birthyear = val;

  UserSchema(this._username, this._email, this._birthyear);

  UserSchema.fromMap(Map data) : super(id: data['_id']) {
    _username = data['username'];
    _email = data['email'];
    _birthyear = DateTime.fromMillisecondsSinceEpoch(data['birthyear']);
  }

  @override
  Map<dynamic, dynamic> toMap() {
    return {
      'username': _username,
      'email': _email,
      'birthyear': _birthyear.millisecondsSinceEpoch
    };
  }

  @override
  bool operator ==(o) =>
      o is UserSchema &&
      o._username == _username &&
      o._email == _email &&
      o._birthyear == _birthyear;

  @override
  int get hashCode =>
      _username.hashCode ^ _email.hashCode ^ _birthyear.hashCode;
}

void main() async {
  test('schema', () async {
    File file;
    final path = Directory.current.path + '/test/schema.db';
    file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }

    var userDb =
        await SchemaDB<UserSchema>(path, (data) => UserSchema.fromMap(data))
            .open();

    List<UserSchema> user = [
      UserSchema('marioreggiori', 'mario@fosscom.org', DateTime(1997)),
      UserSchema('flexwie', 'felix@fosscom.org', DateTime(1990)),
    ];

    userDb.insert(user[0]);
    userDb.insert(user[1]);

    userDb.update({'username': 'flexwie'},
        {'birthyear': DateTime(1997).millisecondsSinceEpoch});

    user[1].birthyear = DateTime(1997);

    expect(await userDb.first({}), user[0]);
    expect(await userDb.last({}), user[1]);
    expect(await userDb.find({}), user);
  });
}
