// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.server;

import 'dart:async';
import 'dart:convert';

import 'config.dart';
import 'errors.dart';
import 'message.dart';
import 'parser.dart';
import 'utils.dart';

final JsonEncoder _encoder = new JsonEncoder.withIndent(' ');

/// The main class for handling all API requests.
class ApiServer {

  Map<String, ApiConfig> _apis = {};

  /// Add a new api to the API server.
  void addApi(api) {
    ApiParser parser = new ApiParser();
    ApiConfig apiConfig = parser.parse(api);
    if (_apis.containsKey(apiConfig.apiKey)) {
      parser.addError('API already exists with path: ${apiConfig.apiKey}.');
    }
    if (!parser.isValid) {
      throw new ApiConfigError('RPC: Failed to parse API.\n\n'
                               '${apiConfig.apiKey}:\n' +
                                parser.errors.join('\n') + '\n');
    }
    _apis[apiConfig.apiKey] = apiConfig;
  }

  /// Handles the api call.
  ///
  /// It looks up the corresponding api and call the api instance to
  /// further dispatch to the correct method call.
  ///
  /// Returns a HttpApiResponse either with the result of calling the method
  /// or an error if the method wasn't found, the parameters were not matching,
  /// or if the method itself failed.
  /// Errors have the format:
  ///
  ///     {
  ///       error: {
  ///         code: <http status code>,
  ///         message: <message describing the failure>
  ///       }
  ///     }
  Future<HttpApiResponse> handleHttpRequest(HttpApiRequest request) async {
    var drain = true;
    var response;
    try {
      // Parse the request to compute some of the values needed to determine
      // which method to invoke.
      var parsedRequest = new ParsedHttpApiRequest(request);

      // The api key is the first two path segments.
      ApiConfig api = _apis[parsedRequest.apiKey];
      if (api == null) {
        return httpErrorResponse(request,
            new NotFoundError('No API with key: ${parsedRequest.apiKey}.'));
      }
      drain = false;
      response = await api.handleHttpRequest(parsedRequest);
    } catch (e) {
      // This can happen if the request is invalid and cannot be parsed into a
      // ParsedHttpApiRequest or in the case of a bug in the handleHttpRequest
      // code, e.g. a null pointer exception or similar. We don't drain the
      // request body in that case since we cannot know whether the bug was
      // before or after invoking the method and we cannot drain the body twice.
      var exception = e;
      if (exception is Error) {
        exception = new Exception(e.toString());
      }
      response = httpErrorResponse(request, exception, drainRequest: drain);
    }
    return response;
  }

  /// Returns a map of all discovery documents available at this api server.
  Map<String, String> getAllDiscoveryDocuments(
      [String apiPathPrefix = '',
       String root = 'http://localhost:8080/']) {
    Map docs = {};
    _apis.forEach(
        (apiPath, api) =>
            docs[apiPath] = _encoder.convert(api.toJson(root, apiPathPrefix)));
    return docs;
  }

  /// Returns the discovery document matching the given key.
  String getDiscoveryDocument(String apiKey,
                              [String apiPathPrefix = '',
                               String root = 'http://localhost:8080/']) {
    var api = _apis[apiKey];
    if (api != null) return _encoder.convert(api.toJson(root, apiPathPrefix));
    return null;
  }
}
