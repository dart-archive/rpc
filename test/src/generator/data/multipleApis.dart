// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library multipleapis;

import 'package:rpc/src/annotations.dart';
import 'multipleApisMessages.dart';
import 'multipleApisResources.dart';

@ApiClass(version: '0.1')
class ApiOneApi {
  ApiOneApi();

  @ApiMethod(path: 'apione')
  ApiOneResponse hello() {
    return ApiOneResponse()..result = 'Hello there!';
  }

  @ApiMethod(path: 'apione/{name}/age/{age}')
  ApiOneResponse apiOneGetWithParams(String name, int age) {
    return ApiOneResponse()..result = 'Hello ${name} of age ${age}!';
  }

  @ApiMethod(path: 'apione/post', method: 'POST')
  ApiOneResponse apiOnePost(ApiOneRequest request) {
    return ApiOneResponse()
      ..result = 'Hello ${request.name} of age ${request.age}!';
  }
}

@ApiClass(version: '0.1')
class ApiTwoApi {
  ApiTwoApi();

  @ApiResource()
  ApiTwoResource aResource = ApiTwoResource();

  @ApiMethod(path: 'apitwo')
  ApiTwoResponse hello() {
    return ApiTwoResponse()..result = 'Hello there!';
  }

  @ApiMethod(path: 'apitwo/{name}/age/{age}')
  ApiTwoResponse apiTwoGetWithParams(String name, int age) {
    return ApiTwoResponse()..result = 'Hello ${name} of age ${age}!';
  }

  @ApiMethod(path: 'apitwo/put', method: 'PUT')
  ApiTwoResponse apiTwoPut(ApiTwoRequest request) {
    return ApiTwoResponse()
      ..result = 'Hello ${request.name} of age ${request.age}!';
  }

  @ApiMethod(path: 'apitwo/delete', method: 'DELETE')
  VoidMessage apiTwoDelete() {
    return null;
  }
}
