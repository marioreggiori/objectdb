enum Method { add, remove, update }

typedef ListenerCallback(Method method, dynamic data);

/// ObjectDB query listener
/// Calls [callback] when entry matched by [query] is changed/added/removed
class Listener {
  final Map<dynamic, dynamic> query;
  final ListenerCallback callback;

  Listener(this.query, this.callback);
}
