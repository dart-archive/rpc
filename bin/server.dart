import 'package:dart_endpoints/endpoints.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_appengine/shelf_appengine.dart' as shelf_ae;

_handler(Request request) {
  var headers = {'Content-Type' : 'text/plain'};
  
  return new Response.ok('Hello World!!', headers: headers);
}

@ApiClass(
  name: 'myApi',
  version: 'v1',
  description: 'My Awesome Dart Cloud Endpoint'
)
class MyApi extends Api {

  MyApi();
}


void main() {
  var api_server = new ApiServer();
  api_server.addApi(new MyApi());
  var cascade = new Cascade()
    .add(api_server.handler)
    .add(_handler)
    .add(shelf_ae.assetHandler);

  shelf_ae.serve(cascade.handler);
}
