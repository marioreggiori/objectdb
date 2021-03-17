import 'package:deeply/deeply.dart';
import 'package:objectdb/src/objectdb_filter.dart';
import 'package:objectid/objectid.dart';
import 'package:objectdb/src/objectdb_operators.dart';

import 'package:objectdb/src/objectdb_meta.dart';

abstract class StorageInterface {
  /// open/initialize storage
  Future<Meta> open([int version = 1]) async => Meta(version);

  /// close storage
  Future close() async {
    return;
  }

  /// condense storage
  Future cleanup() async {}

  /// insert entry
  Future<ObjectId> insert(Map<dynamic, dynamic> data);

  /// retrieve entries
  Future<Stream<Map<dynamic, dynamic>>> find(Map<dynamic, dynamic> query,
      [Filter filter = Filter.all]);

  /// remove entries
  Future remove(Map<dynamic, dynamic> query);

  /// update entries
  Future update(Map<dynamic, dynamic> query, Map<dynamic, dynamic> changes,
      [bool replace = false]);

  /// apply update to single entry (internal)
  static Map<dynamic, dynamic> applyUpdate(
      Map<dynamic, dynamic> entry, Map<dynamic, dynamic> changes,
      [bool replace = false]) {
    // clear entry if replace is true
    if (replace) entry = <dynamic, dynamic>{};

    // apply changes one after another
    for (var keyOfChanges in changes.keys) {
      if (keyOfChanges is Op) {
        for (String p in changes[keyOfChanges].keys) {
          var keyPath = p.split('.');
          switch (keyOfChanges) {
            // set value in entry
            case Op.set:
              {
                entry = updateDeeply(
                    keyPath, entry, (value) => changes[keyOfChanges][p]);
                break;
              }
            // remove path from entry
            case Op.unset:
              {
                if (changes[keyOfChanges][p] == true) {
                  entry = removeDeeply(keyPath, entry);
                }
                break;
              }
            // set max int value
            case Op.max:
              {
                entry = updateDeeply(
                    keyPath,
                    entry,
                    (value) => value > changes[keyOfChanges][p]
                        ? changes[keyOfChanges][p]
                        : value,
                    0);
                break;
              }
            // set min int value
            case Op.min:
              {
                entry = updateDeeply(
                    keyPath,
                    entry,
                    (value) => value < changes[keyOfChanges][p]
                        ? changes[keyOfChanges][p]
                        : value,
                    0);
                break;
              }
            // increment value at path by x
            case Op.increment:
              {
                entry = updateDeeply(keyPath, entry,
                    (value) => value += changes[keyOfChanges][p], 0);
                break;
              }
            // multiply value at path by x
            case Op.multiply:
              {
                entry = updateDeeply(keyPath, entry,
                    (value) => value *= changes[keyOfChanges][p], 0);
                break;
              }
            // rename path to new path
            case Op.rename:
              {
                entry = renameDeeply(keyPath, changes[keyOfChanges][p], entry);
                break;
              }
            default:
              {
                throw 'invalid';
              }
          }
        }
      } else {
        // set new value
        entry[keyOfChanges] = changes[keyOfChanges];
      }
    }
    return entry;
  }
}
