// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.blob;

import 'dart:typed_data';

/// Special API Message to use when a method returns a Blob.
class Blob {
  /// Blob data as bytes.
  Uint8List bytes;

  /// Last modified date of data Blob.
  DateTime modified;

  /// Content type of the Blob.
  String contentType;
}