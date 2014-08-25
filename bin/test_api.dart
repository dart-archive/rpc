library test_api;

import 'dart:async';
import 'package:endpoints/endpoints.dart';

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

class DefaultMessage {
  String message;

  @ApiProperty(defaultValue: 42)
  int value;
}

class RequiredMessage {
  @ApiProperty(required: true)
  String requiredText;

  String optionalText;

  @ApiProperty(required: true, defaultValue: 'test')
  String requiredTextwithDefault;

  @ApiProperty(minValue: 1, maxValue: 100)
  int limit;
}

@ApiClass(
  name: 'test',
  version: 'v1',
  description: 'My Awesome Dart Cloud Endpoint',
  allowedClientIds: const [API_EXPLORER_CLIENT_ID]
)
class MyApi {

  @ApiMethod(
      name: 'echoDefault',
      path: 'echoDefault'
  )
  DefaultMessage echoDefault(DefaultMessage message) {
    return message;
  }

  @ApiMethod(
    name: 'echoRequiredGet',
    path: 'echoRequiredGet'
  )
  RequiredMessage requiredGet(RequiredMessage message) {
    return message;
  }

  @ApiMethod(
    name: 'echoRequiredPost',
    path: 'echoRequiredPost',
    method: 'POST'
  )
  RequiredMessage echoRequiredPost(RequiredMessage message) {
    return message;
  }

  @ApiMethod(
    name: 'get',
    path: 'get',
    description: 'Testing get method'
  )
  MyResponse get(VoidMessage _) {
    return new MyResponse(count: 1, message: "test");
  }

  @ApiMethod(
    name: 'authGet',
    path: 'authGet',
    description: 'Testing authorized get method'
  )
  MyResponse authGet(VoidMessage _, ApiUser user) {
    return new MyResponse(count: 1, message: user.email);
  }

  @ApiMethod(
    name: 'echo',
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
    name: 'echo2',
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
    name: 'echo3',
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
    name: 'echo4',
    method: 'POST',
    path: 'echo4',
    description: 'Limited echo that doesn\'t return everything',
    responseFields: const ['message']
  )
  MyResponse echo4(MyResponse request) {
    return request;
  }

  @ApiMethod(
    name: 'silence',
    method: 'GET',
    path: 'silence',
    description: 'Returns nothing'
  )
  VoidMessage silence(VoidMessage _) {
    return null;
  }
}