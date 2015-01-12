// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library toyapi;

import 'package:rpc/rpc.dart';

class ToyResponse {
  String result;
  ToyResponse(this.result);
}

class ToyResourceResponse {
  String result;
  ToyResourceResponse(this.result);
}

class ToyRequest {
  @ApiProperty(required: true)
  String name;

  @ApiProperty(defaultValue: '1000')
  String age;
}

class ToyAgeRequest {
  @ApiProperty(defaultValue: '1000')
  String age;
}

@ApiClass(version: '0.1')
class ToyApi {

  ToyApi();

  @ApiResource()
  final ToyCompute compute = new ToyCompute();

  @ApiResource()
  final ToyStorage storage = new ToyStorage();

  @ApiMethod(path: 'noop')
  VoidMessage noop() { return null; }

  @ApiMethod(path: 'failing')
  VoidMessage failing() { throw new Exception('I like to fail!'); }

  @ApiMethod(path: 'hello')
  ToyResponse hello() { return new ToyResponse('Hello there!'); }

  @ApiMethod(path: 'hello/{name}/age/{age}')
  ToyResponse helloNameAge(String name, String age) {
    return new ToyResponse('Hello ${name} of age ${age}!');
  }

  @ApiMethod(path: 'helloPost', method: 'POST')
  ToyResponse helloPost(ToyRequest request) {
    return new ToyResponse('Hello ${request.name} of age ${request.age}!');
  }

  @ApiMethod(path: 'helloPost/{name}', method: 'POST')
  ToyResponse helloNamePostAge(String name, ToyAgeRequest request) {
    return new ToyResponse('Hello ${name} of age ${request.age}!');
  }
}

class ToyCompute {

  @ApiMethod(path: 'toyresource/{resource}/compute/{compute}')
  ToyResourceResponse get(String resource, String compute) {
    return new ToyResourceResponse('I am the compute: $compute of resource: '
                                   + resource);
  }
}

class ToyStorage {

  @ApiMethod(path: 'toyresource/{resource}/storage/{storage}')
  ToyResourceResponse get(String resource, String storage) {
    return new ToyResourceResponse('I am the storage: $storage of resource: '
                                   + resource);
  }
}

