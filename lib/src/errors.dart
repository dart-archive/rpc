// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library endpoints.errors;

import 'dart:convert' show JSON;

class EndpointsError implements Exception {

  final String state = 'APPLICATION_ERROR';
  final String name;
  final String msg;
  final int code;

  EndpointsError(this.code, this.name, this.msg);

  Map toJson() {
    var json = {
      'state'        : state,
      'error_name'   : name,
      'code'         : code,
      'error_message': msg
    };
    return json;
  }

  String toString() {
    return JSON.encode(toJson());
  }
}

class NotFoundError extends EndpointsError {
  NotFoundError([String msg = "Not found."]) : super(404, 'Not Found', msg);
}

class BadRequestError extends EndpointsError {
  BadRequestError([String msg = "Bad request."]) : super(400, 'Bad Request', msg);
}

class InternalServerError extends EndpointsError {
  InternalServerError([String msg = "Internal Server Error."]) : super(500, 'Internal Server Error', msg);
}
