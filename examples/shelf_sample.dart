// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_rpc_sample;

import 'dart:async';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_route/shelf_route.dart' as shelf_route;
import 'package:endpoints/endpoints.dart';
import 'toyapi.dart';

final ApiServer _apiServer = new ApiServer();
const API = '/api';
const REST = '/rest';

void main() {
  _apiServer.addApi(new ToyApi());
  var apiRouter = shelf_route.router();
  apiRouter.add(API, ['GET', 'POST'], _apiHandler, exactMatch: false);
  apiRouter.add(REST, ['GET'], _allDiscoveryDocsHandler);

  shelf_io.serve(apiRouter.handler, '0.0.0.0', 9090);
}

/// A shelf handler for '/api' API requests .
Future<shelf.Response> _apiHandler(shelf.Request request) {
  var requestPath = request.url.path;
  if (requestPath.endsWith(REST)) {
    // Return the discovery doc for the given API.
    var apiKey = requestPath.substring(0, requestPath.length - REST.length);
    var doc = _apiServer.getDiscoveryDocument(apiKey, 'api', _rootUrl(request));
    if (doc == null) {
      return new Future.value(
          new shelf.Response.notFound('API \'${apiKey} not found.'));
    }
    return new Future.value(new shelf.Response.ok(doc));
  }
  var apiRequest =
      new HttpApiRequest(request.method, requestPath,
                         request.headers['content-type'], request.read());
  return _apiServer.handleHttpRequest(apiRequest)
      .then((apiResponse) {
         return new shelf.Response(apiResponse.status, body: apiResponse.body,
                                   headers: apiResponse.headers);
      }).catchError((e) {
        // Should never happen since the apiServer.handleHttpRequest method
        // always returns a response.
        return new shelf.Response.internalServerError(body: e.toString());
      });
}

/// Returns all discovery documents.
shelf.Response _allDiscoveryDocsHandler(shelf.Request request) {
  return new shelf.Response.ok(
      _apiServer.getAllDiscoveryDocuments('api', _rootUrl(request))
      .toString());
}

String _rootUrl(shelf.Request request) {
  Uri uri = request.requestedUri;
  return '${uri.scheme}://${uri.host}:${uri.port}/';
}
