// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library endpoints.errors;

import 'dart:io';

class EndpointsError implements Exception {

  final String state = 'APPLICATION_ERROR';
  final String name;
  final String msg;
  final int code;

  EndpointsError(this.code, this.name, this.msg);
}

class NotFoundError extends EndpointsError {
  NotFoundError([String msg = "Not found."])
      : super(HttpStatus.NOT_FOUND, 'Not Found', msg);
}

class BadRequestError extends EndpointsError {
  BadRequestError([String msg = "Bad request."])
      : super(HttpStatus.BAD_REQUEST, 'Bad Request', msg);
}

class InternalServerError extends EndpointsError {
  InternalServerError([String msg = "Internal Server Error."])
      : super(HttpStatus.INTERNAL_SERVER_ERROR, 'Internal Server Error', msg);
}

class ApplicationError extends EndpointsError {
  ApplicationError(Exception e)
      : super(HttpStatus.INTERNAL_SERVER_ERROR,
              'Application Invocation Error',
              e.toString());

}