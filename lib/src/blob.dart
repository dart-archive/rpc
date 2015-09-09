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