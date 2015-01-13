// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.server;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'errors.dart';
import 'message.dart';

final JsonEncoder _encoder = new JsonEncoder.withIndent(' ');

/// The main class for handling all API requests.
class ApiServer {

  Map<String, ApiConfig> _apis = {};

  /// Add a new api to the API server.
  void addApi(api) {
    var apiConfig = new ApiConfig(api);
    if (_apis.containsKey(apiConfig.apiPath)) {
      apiConfig.addError(new ApiConfigError('${apiConfig.id} API path: '
          '${apiConfig.apiPath} already in use.'));
    }
    if (!apiConfig.isValid) {
      throw new ApiConfigError('RPC: Failed to parse API annotations.\n\n'
                               '${apiConfig.errors}\n');
    }
    _apis[apiConfig.apiPath] = apiConfig;
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
    ApiConfig api = _apis[request.apiKey];
    if (api == null || !api.isValid) {
      var error =
          new BadRequestError('Could not find API with key ${request.apiKey}.');
      return _wrapErrorAsResponse(request, error);
    }
    var response;
    try {
      response = await api.handleHttpRequest(request);
    } catch (e) {
      response = _wrapErrorAsResponse(request, e);
    }
    return response;
  }

  Future<HttpApiResponse>_wrapErrorAsResponse(HttpApiRequest request,
                                              Exception error) async {
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
    if (!request.bodyProcessed) {
      // Drain the request before responding.
      try {
        await request.body.drain();
      } catch(e) {
        // Ignore any errors and return the original response generated above.
      }
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
