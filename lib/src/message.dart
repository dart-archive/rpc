// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.messages;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'errors.dart';

/// Class used when invoking Http API requests.
///
/// It holds the information necessary to route the request and all
/// the parameters needed to invoke the method.
class HttpApiRequest {

  /// Key identifying the api for this request.
  final String apiKey;

  /// HTTP method for this request (e.g. GET, POST,...).
  final String httpMethod;

  /// Key identifying the method group within the api this request is for.
  final String methodKey;

  /// URI determining which method to invoke within the above method group.
  /// The URI also contains path parameter values.
  final Uri uri;

  /// Content type for the request's body.
  final String contentType;

  /// Request body containing parameters for a POST request.
  final Stream<List<int>> body;

  /// Used to determine if the body has been processed. This is needed to
  /// avoid processing the single-subscriber stream twice.
  bool bodyProcessed = false;

  // Map from path parameter name to path parameter value. This is set once
  // a method is matching the request and has succesfully parsed the above
  // uri.
  Map<String, String> _pathParameters;

  factory HttpApiRequest(String httpMethod,
                         String requestPath,
                         String contentType,
                         Stream<List<int>> body) {
    // All HTTP api request paths must be of the form:
    //   /<apiName>/<apiVersion>/<method|resourceName>[/...].
    // Hence the number of path segments must be at least three for a valid
    // request.
    Uri uri = Uri.parse(requestPath);
    if (uri.pathSegments.length < 3) {
      throw new BadRequestError('Invalid request, missing API '
                                'name and version: $requestPath.');
    }
    var apiKey = '/${uri.pathSegments[0]}/${uri.pathSegments[1]}';
    var methodKey = '$httpMethod${uri.pathSegments.skip(2).length}';
    return new HttpApiRequest._(apiKey, httpMethod, methodKey, uri,
                                contentType, body, null);
  }

  HttpApiRequest._(this.apiKey, this.httpMethod, this.methodKey, this.uri,
                   this.contentType, this.body, this._pathParameters);

  void set pathParameters(Map<String, String> pp) { _pathParameters = pp; }
  Map<String, String> get pathParameters => _pathParameters;

  Map<String, dynamic> get queryParameters {
    // TODO: Parse query string and return a valid map.
    return null;
  }
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

  HttpApiResponse(this.status, this.body,
                  {Map<String, dynamic> headers, this.exception})
      : this.headers = headers == null ? {} : headers;

  factory HttpApiResponse.error(int status,
                                String message,
                                Map<String, dynamic> headers,
                                Exception exception) {
    // Currently we don't support other encodings than json so just set it.
    // We cannot fail at this point anyway.
    headers[HttpHeaders.CONTENT_TYPE] = ContentType.JSON.toString();
    Map json = { 'error': { 'code': status, 'message': message } };
    Stream<List<int>> s =
        new Stream.fromIterable([_jsonToBytes.convert(json)]);
    return new HttpApiResponse(status, s, headers: headers,
                               exception: exception);
  }
}
