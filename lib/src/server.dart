// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library endpoints.server;

import 'errors.dart';
import 'config.dart';

import 'dart:async';
import 'dart:convert';

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
      throw new ApiConfigError('Endpoints: Failed to parse API RPC '
                               'annotations.\n\n${apiConfig.errors}\n');
    }
    _apis[apiConfig.apiPath] = apiConfig;
  }

  /// Handles the api call.
  ///
  /// It looks up the corresponding api and call the api instance to
  /// further dispatch to the correct method call.
  Future<Map> handleCall(String httpMethod,
                         String apiCallPath,
                         Map queryParams,
                         Map requestBody) {
    // The api key is the first two path segments of the apiCallPath.
    // apiCallPath must be of the form:
    //   <apiName>/<apiVersion>/<method|resourceName>[/...].
    List<String> pathSegments = apiCallPath.split('/');
    if (pathSegments.length < 3) {
      return new Future.error(new NotFoundError('Invalid request, missing API '
          'name and version: $apiCallPath.'));
    }
    var apiKey = '${pathSegments[0]}/${pathSegments[1]}';
    ApiConfig api = _apis[apiKey];
    if (api == null || !api.isValid) {
      return new Future.error(
          new NotFoundError('No valid API endpoint for this request'));
    }
    Completer completer = new Completer();
    var methodPath = apiCallPath.substring(apiKey.length + 1);
    api.handleCall(httpMethod, methodPath, queryParams, requestBody)
        .then((response) => completer.complete(response))
        .catchError((e) {
          if (e is EndpointsError) {
            completer.completeError(e);
          } else {
            completer.completeError(
                new InternalServerError('Unknown API Error: $e'));
          }
          return true;
        });
    return completer.future;
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
