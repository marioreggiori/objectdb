// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:math';

/// A globally unique identifier for objects.
///
/// Consists of 12 bytes, divided as follows:
///
/// * time (4 bytes)
/// * machine (3 bytes)
/// * pid (2 bytes)
/// * inc (3 bytes)
class ObjectId implements Comparable<ObjectId> {
  final int _timestamp;

  final int _machineId;

  final int _processId;

  final int _counter;

  /// The timestamp as a [DateTime] instance.
  DateTime get date =>
      new DateTime.fromMillisecondsSinceEpoch(_timestamp * 1000);

  /// The timestamp. (number of seconds since the Unix epoch).
  int get timestamp => _timestamp;

  /// The machine identifier.
  int get machineId => _machineId;

  /// The process identifier.
  int get processId => _processId;

  /// The counter
  int get counter => _counter;

  /// Creates a new object id.
  factory ObjectId() {
    int timestamp = new DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int counter = _nextCounter();
    return new ObjectId._internal(
        timestamp, _generatedMachineId, _generatedProcessId, counter);
  }

  /// Creates a new instance from the given date, with the rest of the [ObjectId]
  /// zeroed out. Used for comparisons or sorting the ObjectId.
  factory ObjectId.fromDate(DateTime date) {
    int timestamp = date.millisecondsSinceEpoch ~/ 1000;
    return new ObjectId._internal(timestamp, 0, 0, 0);
  }

  /// Creates a new instance from a 24-byte hexadecimal string representation.
  ///
  /// Throws an [ArgumentError] if the given hex string is not valid.
  factory ObjectId.fromHexString(String hexString) {
    List<int> b = _parseHexString(hexString);
    return new ObjectId.fromBytes(b);
  }

  /// Creates a new instance from the given byte list.
  ///
  /// Throws an [ArgumentError] if [bytes] is null or its length is not 12.
  factory ObjectId.fromBytes(List<int> bytes) {
    if (bytes == null) {
      throw new ArgumentError.notNull('bytes');
    }
    if (bytes.length != 12) {
      throw new ArgumentError.value(bytes, 'need 12 bytes');
    }

    int timestamp = _makeInt(bytes[0], bytes[1], bytes[2], bytes[3]);
    int machineId = _makeInt(0, bytes[4], bytes[5], bytes[6]);
    int processId = _makeInt(0, 0, bytes[7], bytes[8]);
    int counter = _makeInt(0, bytes[9], bytes[10], bytes[11]);

    return new ObjectId._internal(timestamp, machineId, processId, counter);
  }

  ObjectId._internal(
      this._timestamp, this._machineId, this._processId, this._counter);

  /// Converts this instance into 24-byte hexadecimal string representation.
  String toHexString() {
    List<String> charCodes = new List<String>(24);
    int i = 0;
    for (final b in toBytes()) {
      charCodes[i++] = _hexChars[b >> 4 & 0xF];
      charCodes[i++] = _hexChars[b & 0xF];
    }
    return charCodes.join('');
  }

  /// Converts to a byte list. Note that the numbers are stored in big-endian
  /// order.
  List<int> toBytes() {
    List<int> bytes = new List<int>(12);
    bytes[0] = _int3(_timestamp);
    bytes[1] = _int2(_timestamp);
    bytes[2] = _int1(_timestamp);
    bytes[3] = _int0(_timestamp);
    bytes[4] = _int2(_machineId);
    bytes[5] = _int1(_machineId);
    bytes[6] = _int0(_machineId);
    bytes[7] = _int1(_processId);
    bytes[8] = _int0(_processId);
    bytes[9] = _int2(_counter);
    bytes[10] = _int1(_counter);
    bytes[11] = _int0(_counter);
    return bytes;
  }

  @override
  int get hashCode {
    int result = _timestamp;
    result = 31 * result + machineId;
    result = 31 * result + processId;
    result = 31 * result + counter;
    return result;
  }

  @override
  bool operator ==(other) =>
      other is ObjectId &&
      _counter == other._counter &&
      _machineId == other._machineId &&
      _processId == other._processId &&
      _timestamp == other._timestamp;

  @override
  int compareTo(ObjectId other) {
    List<int> byteList = toBytes();
    List<int> otherByteList = other.toBytes();
    for (var i = 0; i < 12; i++) {
      if (byteList[i] != otherByteList[i]) {
        return byteList[i] < otherByteList[i] ? -1 : 1;
      }
    }
    return 0;
  }

  @override
  String toString() => toHexString();

  /// Checks if a string could be an [ObjectId]. Throws an [ArgumentError] if
  /// [hexString] is null.
  static bool isValid(String hexString) {
    if (hexString == null) {
      throw new ArgumentError.notNull('hexString');
    }

    return hexString.length == 24 && _checkForHexRegExp.hasMatch(hexString);
  }
}

final _checkForHexRegExp = new RegExp(r'^[0-9a-fA-F]{24}$');

const _lowerOrderTwoBytes = 0x0000FFFF;
const _lowerOrderThreeBytes = 0x00FFFFFF;

int _globalCounter = new Random.secure().nextInt(_lowerOrderThreeBytes);

int _nextCounter() {
  _globalCounter = (_globalCounter + 1) & _lowerOrderThreeBytes;
  return _globalCounter;
}

int _createMachineId() {
  // FIXME: Build a 3-byte machine piece based on NICs info and
  // fallback to random number only if NICs info is not available.
  return new Random.secure().nextInt(_lowerOrderThreeBytes);
}

int _createProcessId() {
  // FIXME: Get the real process Id instead of creating a random number.
  return new Random.secure().nextInt(_lowerOrderTwoBytes);
}

int _generatedMachineId = _createMachineId();

int _generatedProcessId = _createProcessId();

int _makeInt(int b3, int b2, int b1, int b0) =>
    (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;

int _int3(int x) => (x & 0xFF000000) >> 24;

int _int2(int x) => (x & 0x00FF0000) >> 16;

int _int1(int x) => (x & 0x0000FF00) >> 8;

int _int0(int x) => (x & 0x000000FF);

List<String> _hexChars = [
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f'
];

List<int> _parseHexString(String s) {
  if (!ObjectId.isValid(s)) {
    throw new ArgumentError.value(
        s, 'invalid hexadecimal representation of an ObjectId: [$s]');
  }

  List<int> b = new List<int>(12);
  for (var i = 0; i < b.length; i++) {
    b[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return b;
}
