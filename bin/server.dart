import 'package:endpoints/endpoints.dart';
import 'package:appengine/appengine.dart';
import 'dart:io';
import 'db_api.dart';
import 'test_api.dart';

ApiServer api_server;

void _handler(HttpRequest request) {
  if (request.uri.path.startsWith('/_ah/spi/')) {
    api_server.handleRequest(request);
    return;
  }
  context.assets.serve(request.response, request.uri.path);
}

void main() {
  api_server = new ApiServer();
  api_server.addApi(new MyApi());
  api_server.addApi(new DartDBApi());

  /*
  var cascade = new Cascade(statusCodes: [501])
    .add(api_server.handler)
    .add(_handler)
    .add(shelf_ae.assetHandler);

  shelf_ae.serve(cascade.handler);*/

  runAppEngine(_handler).then((_) {
    // Server running.
  });
}
