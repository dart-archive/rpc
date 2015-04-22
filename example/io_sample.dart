// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library io_rpc_sample;

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:logging_handlers/server_logging_handlers.dart';
import 'package:rpc/rpc.dart';

import 'toyapi.dart';

const String _API_PREFIX = '/api';
final ApiServer _apiServer =
    new ApiServer(apiPrefix: _API_PREFIX, prettyPrint: true);

main() async {
  // Add a simple log handler to log information to a server side file.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(new SyncFileLoggingHandler('myLogFile.txt'));
  if (stdout.hasTerminal) {
    Logger.root.onRecord.listen(new LogPrintHandler());
  }

  _apiServer.addApi(new ToyApi());
  HttpServer server = await HttpServer.bind(InternetAddress.ANY_IP_V4, 8080);
  server.listen(_apiServer.httpRequestHandler);
  _apiServer.enableDiscoveryApi();
}