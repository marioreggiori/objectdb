/// ObjectDB exception wrapper
class ObjectDBException implements Exception {
  final message;

  ObjectDBException(this.message);
}

const Message_Invalid_Param = '';
