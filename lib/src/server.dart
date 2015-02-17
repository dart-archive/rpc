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
import 'discovery/api.dart';
import 'discovery/config.dart';

/// The main class for handling all API requests.
class ApiServer {
  String _baseUrl;
  String _apiPrefix;
  String _discoveryApiKey;

  Converter<Object, dynamic> _jsonToBytes;

  final Map<String, ApiConfig> _apis = {};

  ApiServer({bool prettyPrint: false}) {
    _jsonToBytes = prettyPrint ?
        new JsonEncoder.withIndent(' ').fuse(UTF8.encoder) :
        JSON.encoder.fuse(UTF8.encoder);
  }

  /// Add a new api to the API server.
  String addApi(api) {
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
    return apiConfig.apiKey;
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
      var parsedRequest = new ParsedHttpApiRequest(request, _jsonToBytes);

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

  void enableDiscoveryApi(String baseUrl, String apiPrefix) {
    _baseUrl = baseUrl;
    _apiPrefix = apiPrefix;
    _discoveryApiKey = addApi(new DiscoveryApi(this, baseUrl, apiPrefix));
  }

  void disableDiscoveryApi() {
    _apis.remove(_discoveryApiKey);
    _baseUrl = null;
    _apiPrefix = null;
    _discoveryApiKey = null;
  }

  /// Returns a list containing all Discovery directory items listing
  /// information about the APIs available at this API server.
  List<DirectoryListItems> getDiscoveryDirectory() {
    if (_baseUrl == null) {
      // The Discovery API has not been enabled for this ApiServer.
      throw new BadRequestError('Discovery API not enabled.');
    }
    var apiDirectory = [];
    _apis.values.forEach((api) => apiDirectory.add(api.asDirectoryListItem));
    return apiDirectory;
  }

  /// Returns the discovery document matching the given api key.
  RestDescription getDiscoveryDocument(String apiKey) {
    if (_baseUrl == null) {
      // The Discovery API has not been enabled for this ApiServer.
      throw new BadRequestError('Discovery API not enabled.');
    }
    var api = _apis[apiKey];
    if (api == null) {
      throw new NotFoundError('Discovery API \'$apiKey\' not found.');
    }
    return api.generateDiscoveryDocument(_baseUrl, _apiPrefix);
  }
}
