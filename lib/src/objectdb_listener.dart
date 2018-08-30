enum Method { add, remove, update }

typedef listener(Method method, dynamic data);

class Listener {
  final Map<dynamic, dynamic> query;
  final listener callback;

  Listener(this.query, this.callback);
}