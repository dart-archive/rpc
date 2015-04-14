// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.errors;

import 'dart:io';

class RpcError implements Exception {

  final int statusCode;
  final String name;
  final String message;

  RpcError(this.statusCode, this.name, this.message);

  String toString() => 'RPC Error with status: $statusCode and message: $message';
}

class NotFoundError extends RpcError {
  NotFoundError([String message = "Not found."])
      : super(HttpStatus.NOT_FOUND, 'Not Found', message);
}

class BadRequestError extends RpcError {
  BadRequestError([String message = "Bad request."])
      : super(HttpStatus.BAD_REQUEST, 'Bad Request', message);
}

class InternalServerError extends RpcError {
  InternalServerError([String message = "Internal Server Error."])
      : super(HttpStatus.INTERNAL_SERVER_ERROR, 'Internal Server Error', message);
}

class ApplicationError extends RpcError {
  ApplicationError(Exception e)
      : super(HttpStatus.INTERNAL_SERVER_ERROR,
              'Application Invocation Error',
              e.toString());

}
