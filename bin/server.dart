import 'package:dart_endpoints/endpoints.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_appengine/shelf_appengine.dart' as shelf_ae;

_handler(Request request) {
  var headers = {'Content-Type' : 'text/plain'};
  
  return new Response.ok('Hello World!!', headers: headers);
}

class MyResponse extends ApiMessage {
  int count;
  String message;
  
  MyResponse(this.count, this.message);
}

class MyRequest extends ApiMessage {
  String message;
  MyRequest(this.message);
}

@ApiClass(
  name: 'myApi',
  version: 'v1',
  description: 'My Awesome Dart Cloud Endpoint'
)
class MyApi extends Api {

  MyApi();
  
  @ApiMethod(
    name: 'myApi.get',
    path: 'get',
    description: 'Testing get method'
  )
  MyResponse get() {
    return new MyResponse(1, "test");
  }
  
  @ApiMethod(
    name: 'myApi.echo',
    method: 'POST',
    path: 'echo',
    description: 'Echos whatever you send to it'
  )
  MyResponse echo(MyRequest request) {
    return new MyResponse(1, request.message);
  }
  
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
