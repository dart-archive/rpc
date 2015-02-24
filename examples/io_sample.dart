// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library io_rpc_sample;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:logging_handlers/server_logging_handlers.dart';
import 'package:rpc/rpc.dart';

import 'toyapi.dart';

const String _API_PREFIX = '/api';
final ApiServer _apiServer = new ApiServer(prettyPrint: true);

main() async {
  // Add a simple log handler to log information to a server side file.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(new SyncFileLoggingHandler('myLogFile.txt'));
  if (stdout.hasTerminal) {
    Logger.root.onRecord.listen(new LogPrintHandler());
  }

  _apiServer.addApi(new ToyApi());
  HttpServer server = await HttpServer.bind(InternetAddress.ANY_IP_V4, 9090);
  server.listen(handleRequest);
  // TODO: Figure out a better way to determine the server ip.
  // E.g. set it on the first request. '${server.address.host}:${server.port}'
  // return 0.0.0.0:9090 which is not useful.
  var url = 'http://localhost:9090/';
  _apiServer.enableDiscoveryApi(url, _API_PREFIX);
}

/// Handle incoming HttpRequests.
Future handleRequest(HttpRequest request) async {
  if (!request.uri.path.startsWith(_API_PREFIX)) {
    await request.drain();
    return _stringResponse(request.response, ContentType.TEXT,
                           HttpStatus.NOT_IMPLEMENTED, 'Not Implemented');
  }

  // Skip the first path segment since that is the application specific
  // '/api' prefix.
  var apiRequest =
      new HttpApiRequest(request.method,
                         request.uri.path.substring(_API_PREFIX.length),
                         request.uri.queryParameters,
                         request.headers.contentType.toString(),
                         request);
  try {
    var apiResponse = await _apiServer.handleHttpRequest(apiRequest);
    return _apiResponse(request.response, apiResponse);
  } catch (e) {
    // Should never happen since the apiServer.handleHttpRequest method
    // always returns a response.
    return _stringResponse(request.response, ContentType.TEXT,
                           HttpStatus.INTERNAL_SERVER_ERROR, e.toString());
  }
}

Future _apiResponse(HttpResponse response, HttpApiResponse apiResponse) {
  apiResponse.headers.forEach(
      (name, value) => response.headers.add(name, value));
  response.statusCode = apiResponse.status;
  return apiResponse.body.pipe(response);
}

Future _stringResponse(HttpResponse response,
                      ContentType contentType,
                      int code,
                      String message) {
  var data = UTF8.encode(message);
  return new Future.value(response
      ..headers.contentType = contentType
      ..statusCode = code
      ..contentLength = data.length
      ..add(data)
      ..close());
}