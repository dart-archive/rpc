// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.messages;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'utils.dart';

/// Class used when invoking Http API requests.
///
/// It holds the information necessary to route the request and all
/// the parameters needed to invoke the method.
class HttpApiRequest {

  /// HTTP method for this request (e.g. GET, POST,...).
  final String httpMethod;

  /// Request path.
  final String path;

  /// Query string parsed as a key/value map.
  final Map<String, String> queryParameters;

  /// Content type for the request's body.
  final String contentType;

  /// Request body containing parameters for a POST request.
  final Stream<List<int>> body;

  HttpApiRequest(this.httpMethod, this.path, this.queryParameters,
                 this.contentType, this.body);
}

/// Class for holding an HTTP API response.
///
/// This is the result of calling the API server's handleHttpRequest method.
class HttpApiResponse {
  // We have an encoder for all the supported encodings.
  // Currently only json is supported.
  static final _jsonToBytes = JSON.encoder.fuse(UTF8.encoder);

  /// Status of the response, e.g. 200 if success, 400 if bad request, etc.
  final int status;

  /// HTTP response headers
  final Map<String, dynamic> headers;

  /// Response body containing the result of a request.
  final Stream<List<int>> body;

  /// Holds any exception resulting from a failed request.
  /// The exception is stored to allow the application server to log the error
  /// and/or return back more information about the failure to the client.
  final Exception exception;

  /// Holds a stacktrace if passed via constructor.
  final StackTrace stack;

  HttpApiResponse(this.status, this.body,
                  {Map<String, dynamic> headers, this.exception, this.stack})
      : this.headers = headers == null ? {} : headers;

  factory HttpApiResponse.error(int status,
                                String message,
                                Map<String, dynamic> headers,
                                Exception exception,
                                StackTrace stack) {
    // Currently we don't support other encodings than json so just set it.
    // We cannot fail at this point anyway.
    headers[HttpHeaders.CONTENT_TYPE] = ContentType.JSON.toString();
    Map json = { 'error': { 'code': status, 'message': message } };
    Stream<List<int>> s =
        new Stream.fromIterable([_jsonToBytes.convert(json)]);
    return new HttpApiResponse(status, s, headers: headers,
                               exception: exception, stack: stack);
  }
}
