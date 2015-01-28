// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_rpc_sample;

import 'dart:async';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_route/shelf_route.dart' as shelf_route;
import 'package:rpc/rpc.dart';
import 'toyapi.dart';

const _API_PREFIX = '/api';

final ApiServer _apiServer = new ApiServer(prettyPrint: true);

Future main() async {
  _apiServer.addApi(new ToyApi());
  var apiRouter = shelf_route.router();
  apiRouter.add(_API_PREFIX, ['GET', 'POST'], _apiHandler, exactMatch: false);
  var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(apiRouter.handler);

  var server = await shelf_io.serve(handler, '0.0.0.0', 9090);
  // TODO: Figure out a better way to determine the server ip.
  // E.g. set it on the first request. '${server.address.host}:${server.port}'
  // return 0.0.0.0:9090 which is not useful.
  var url = 'http://localhost:9090/';
  _apiServer.enableDiscoveryApi(url, _API_PREFIX);
  print('Listening at port ${server.port}.');
}

/// A shelf handler for '/api' API requests .
Future<shelf.Response> _apiHandler(shelf.Request request) async {
  try {
    var apiRequest =
        new HttpApiRequest(request.method, request.url.path,
                           request.url.queryParameters,
                           request.headers['content-type'], request.read());
    var apiResponse = await _apiServer.handleHttpRequest(apiRequest);
    return new shelf.Response(apiResponse.status, body: apiResponse.body,
                              headers: apiResponse.headers);
  } catch (e) {
    // Should never happen since the apiServer.handleHttpRequest method
    // always returns a response.
    return new shelf.Response.internalServerError(body: e.toString());
  }
}