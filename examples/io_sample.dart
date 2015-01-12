// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library io_rpc_sample;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:endpoints/endpoints.dart';
import 'toyapi.dart';

final ApiServer _apiServer = new ApiServer();

main() async {
  _apiServer.addApi(new ToyApi());
  HttpServer server = await HttpServer.bind(InternetAddress.ANY_IP_V4, 9090);
  server.listen(handleRequest);
}

/// Handle incoming HttpRequests.
void handleRequest(HttpRequest request) {
  const API = '/api';
  const REST = '/rest';
  var requestPath = request.uri.path;
  if (requestPath.startsWith(API)) {
    requestPath = requestPath.substring(API.length);
    if (requestPath.endsWith(REST)) {
      requestPath =
          requestPath.substring(0, requestPath.length - REST.length);
      _discoveryDocHandler(requestPath, request);
    } else {
      _apiHandler(requestPath, request);
    }
  } else if (requestPath.startsWith(REST)) {
    _allDiscoveryDocsHandler(request);
  } else  {
    request.drain().then((_) => _stringResponse(request.response,
                                                ContentType.TEXT,
                                                HttpStatus.NOT_IMPLEMENTED,
                                                'Not Implemented'));
  }
}

Future _apiHandler(String requestPath, HttpRequest request) {
  var apiRequest = new HttpApiRequest(request.method, requestPath,
                                      request.headers.contentType.toString(),
                                      request);
  return _apiServer.handleHttpRequest(apiRequest)
      .then((apiResponse) => _apiResponse(request.response, apiResponse))
      .catchError((e) {
        // Should never happen since the apiServer.handleHttpRequest method
        // always returns a response.
        _stringResponse(request.response, ContentType.TEXT,
                        HttpStatus.INTERNAL_SERVER_ERROR, e.toString());
      });
}

void _discoveryDocHandler(String apiKey, HttpRequest request) {
  var doc = _apiServer.getDiscoveryDocument(apiKey, 'api', _rootUrl(request));
  if (doc == null) {
    _stringResponse(request.response, ContentType.TEXT, HttpStatus.NOT_FOUND,
        'Could not find api with key: \'$apiKey\'.');
  }
  _stringResponse(request.response, ContentType.JSON, HttpStatus.OK, doc);
}

void _allDiscoveryDocsHandler(HttpRequest request) {
  var docs = _apiServer.getAllDiscoveryDocuments('api', _rootUrl(request));
  _stringResponse(request.response, ContentType.JSON, HttpStatus.OK,
      docs.toString());
}

Future _apiResponse(HttpResponse response, HttpApiResponse apiResponse) {
  apiResponse.headers.forEach(
      (name, value) => response.headers.add(name, value));
  response.statusCode = apiResponse.status;
  return apiResponse.body.pipe(response);
}

void _stringResponse(HttpResponse response,
                     ContentType contentType,
                     int code,
                     String message) {
  var data = UTF8.encode(message);
  response..headers.contentType = contentType
          ..statusCode = code
          ..contentLength = data.length
          ..add(data)
          ..close();
}

String _rootUrl(HttpRequest request) {
  Uri uri = request.requestedUri;
  return '${uri.scheme}://${uri.host}:${uri.port}/';
}
