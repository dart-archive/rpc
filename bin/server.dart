import 'package:endpoints/endpoints.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_appengine/shelf_appengine.dart' as shelf_ae;
import 'dart:async';

_handler(Request request) {
  var headers = {'Content-Type' : 'text/plain'};

  if (request.url.toString() != '/') {
    return ApiServer.cascadeResponse;
  }

  return new Response.ok('Hello World!!', headers: headers);
}

class MyResponse {
  @ApiProperty(description: 'Counting something, or not...')
  int count;

  @ApiProperty(description: 'Some text')
  String message;

  MyResponse({this.count, this.message});
}

class MyRequest {
  @ApiProperty(description: 'Some more text')
  String message;

  MyRequest({this.message});
}

@ApiClass(
  name: 'myDartApi',
  version: 'v1',
  description: 'My Awesome Dart Cloud Endpoint',
  allowedClientIds: const [API_EXPLORER_CLIENT_ID]
)
class MyApi {

  @ApiMethod(
    name: 'test.get',
    path: 'get',
    description: 'Testing get method'
  )
  MyResponse get(VoidMessage _) {
    return new MyResponse(count: 1, message: "test");
  }

  @ApiMethod(
    name: 'test.authGet',
    path: 'authGet',
    description: 'Testing authorized get method'
  )
  MyResponse authGet(VoidMessage _, ApiUser user) {
    return new MyResponse(count: 1, message: user.email);
  }

  @ApiMethod(
    name: 'test.echo',
    method: 'POST',
    path: 'echo',
    description: 'Echos whatever you send to it as POST'
  )
  Future<MyResponse> echo(MyRequest request, [ApiUser user]) {
    if (user != null) {
      return new Future.value(new MyResponse(count: 1, message: '${user.email}: request.message'));
    } else {
      return new Future.value(new MyResponse(count: 1, message: request.message));
    }
  }

  @ApiMethod(
    name: 'test.echo2',
    method: 'GET',
    path: 'echo2/{message}',
    description: 'Echos whatever you send to it as GET'
  )
  Future<MyResponse> echo2(MyResponse request, [ApiUser user]) {
    if (user != null) {
      return new Future.value(new MyResponse(count: request.count, message: '${user.email}: request.message'));
    } else {
      return new Future.value(new MyResponse(count: request.count, message: request.message));
    }
  }

  @ApiMethod(
    name: 'test.echo3',
    method: 'POST',
    path: 'echo3/{count}',
    description: 'Echos whatever you send to it as POST with Path parameter'
  )
  Future<MyResponse> echo3(MyResponse request, [ApiUser user]) {
    if (user != null) {
      return new Future.value(new MyResponse(count: request.count, message: '${user.email}: request.message'));
    } else {
      return new Future.value(new MyResponse(count: request.count, message: request.message));
    }
  }

  @ApiMethod(
    name: 'test.silence',
    method: 'GET',
    path: 'silence',
    description: 'Returns nothing'
  )
  VoidMessage silence(VoidMessage _) {
    return null;
  }
}


void main() {
  var api_server = new ApiServer();
  api_server.addApi(new MyApi());
  var cascade = new Cascade(statusCodes: [501])
    .add(api_server.handler)
    .add(_handler)
    .add(shelf_ae.assetHandler);

  shelf_ae.serve(cascade.handler);
}
