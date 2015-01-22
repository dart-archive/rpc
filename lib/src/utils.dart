// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.utils;

import 'dart:async';
import 'dart:io';

import 'errors.dart';
import 'message.dart';

// Global constants
const List<String> bodyLessMethods = const ['GET', 'DELETE'];

// Utility method for creating an HTTP error response given an expcetion.
// Optionally drains the request body.
Future<HttpApiResponse> httpErrorResponse(HttpApiRequest request,
                                          Exception error,
                                          {bool drainRequest: true}) async {
  // TODO support more encodings.
  var headers = {
    HttpHeaders.CONTENT_TYPE: ContentType.JSON.toString(),
    HttpHeaders.CACHE_CONTROL: 'no-cache, no-store, must-revalidate',
    HttpHeaders.PRAGMA: 'no-cache',
    HttpHeaders.EXPIRES: '0'
  };
  var response;
  if (error is RpcError) {
    response =
        new HttpApiResponse.error(error.code, error.msg, headers, error);
  } else {
    response =
        new HttpApiResponse.error(HttpStatus.INTERNAL_SERVER_ERROR,
                                  'Unknown API Error.', headers, error);
  }
  if (drainRequest) {
    // Drain the request before responding.
    try {
      await request.body.drain();
    } catch(e) {
      // Ignore any errors and return the original response generated above.
    }
  }
  return response;
}

