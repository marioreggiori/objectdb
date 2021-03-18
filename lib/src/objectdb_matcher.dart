import 'package:objectdb/src/objectdb_exceptions.dart';
import 'package:objectdb/src/objectdb_operators.dart';
import 'package:objectid/objectid.dart';

var keyPathRegExp = RegExp(r'(\w+|\[\w*\])');

typedef Matcher = bool Function(Map<dynamic, dynamic> testVal);

/// returns matcher for given [query] and optional [op] (recursively)
Matcher createMatcher(query, [Op op = Op.and]) {
  bool match(Map<dynamic, dynamic> testVal) {
    // iterate all query elements
    keyloop:
    for (dynamic i in query.keys) {
      // if element is operator -> create fork-matcher
      if (i is Op) {
        var match = createMatcher(query[i], i != Op.not ? i : op)(testVal);
        if (i == Op.not) {
          match = !match;
        }

        // if operator is conjunction and match found -> test next
        if (op == Op.and && match) continue;
        // if operator is conjunction and no match found -> data does not match
        if (op == Op.and && !match) return false;

        // if operator is disjunction and no match found -> test next
        if (op == Op.or && !match) continue;
        // if operator is disjunction and matche found -> data does match
        if (op == Op.or && match) return true;
      }

      // convert objectdb to string
      if (query[i] is ObjectId) {
        query[i] = (query[i] as ObjectId).hexString;
      }

      if (!(i is String)) {
        throw ObjectDBException('Query key must be string or operator!');
      }

      // split keyPath to array
      var keyPath = keyPathRegExp.allMatches(i);
      dynamic testValCopy = testVal;
      for (var keyPathSegment in keyPath) {
        var keyPathSegmentAsString = keyPathSegment.group(1);

        // handle list query
        if (keyPathSegmentAsString == '[]' && testValCopy is List) {
          var foundMatch = false;
          var subQuery = {i.substring(keyPathSegment.end): query[i]};
          // test all list elements for matches
          for (var testValElement in testValCopy) {
            if (createMatcher(subQuery, op)(testValElement)) {
              foundMatch = true;
            }
          }
          if (!foundMatch && op == Op.and) {
            return false;
          } else if (foundMatch && op == Op.or) {
            return true;
          } else {
            continue keyloop;
          }
        }

        // check if value is map and contains keyPathSegment as key
        if (!(testValCopy is Map<dynamic, dynamic>) ||
            !testValCopy.containsKey(keyPathSegmentAsString)) {
          if (op != Op.or) {
            return false;
          } else {
            continue keyloop;
          }
        }
        testValCopy = testValCopy[keyPathSegmentAsString];
      }

      // skip if type mismatch
      if (op != Op.inList &&
          op != Op.notInList &&
          (!(query[i] is RegExp) && (op != Op.and && op != Op.or)) &&
          testValCopy.runtimeType != query[i].runtimeType) continue;

      switch (op) {
        case Op.and:
        case Op.not:
          {
            if (query[i] is RegExp) {
              if (!query[i].hasMatch(testValCopy.toString())) return false;
              break;
            }
            if (testValCopy != query[i]) return false;
            break;
          }
        case Op.or:
          {
            if (query[i] is RegExp) {
              if (query[i].hasMatch(testValCopy.toString())) return true;
              break;
            }
            if (testValCopy == query[i]) return true;
            break;
          }
        case Op.gt:
          {
            if (testValCopy is String) {
              return testValCopy.compareTo(query[i]) > 0;
            }
            return testValCopy > query[i];
          }
        case Op.gte:
          {
            if (testValCopy is String) {
              return testValCopy.compareTo(query[i]) >= 0;
            }
            return testValCopy >= query[i];
          }
        case Op.lt:
          {
            if (testValCopy is String) {
              return testValCopy.compareTo(query[i]) < 0;
            }
            return testValCopy < query[i];
          }
        case Op.lte:
          {
            if (testValCopy is String) {
              return testValCopy.compareTo(query[i]) <= 0;
            }
            return testValCopy <= query[i];
          }
        case Op.ne:
          {
            return testValCopy != query[i];
          }
        case Op.inList:
          {
            return (query[i] is List) && query[i].contains(testValCopy);
          }
        case Op.notInList:
          {
            return (query[i] is List) && !query[i].contains(testValCopy);
          }
        default:
          {}
      }
    }

    return op != Op.and ? false : true;
  }

  return match;
}
