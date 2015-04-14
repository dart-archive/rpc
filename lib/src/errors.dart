// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.errors;

import 'dart:io';

class RpcError implements Exception {

  final int code;
  final String name;
  final String message;

  RpcError(this.code, this.name, this.message);

  String toString() => 'RPC Error with status: $code and message: $message';
}

class NotFoundError extends RpcError {
  NotFoundError([String msg = "Not found."])
      : super(HttpStatus.NOT_FOUND, 'Not Found', msg);
}

class BadRequestError extends RpcError {
  BadRequestError([String msg = "Bad request."])
      : super(HttpStatus.BAD_REQUEST, 'Bad Request', msg);
}

class InternalServerError extends RpcError {
  InternalServerError([String msg = "Internal Server Error."])
      : super(HttpStatus.INTERNAL_SERVER_ERROR, 'Internal Server Error', msg);
}

class ApplicationError extends RpcError {
  ApplicationError(Exception e)
      : super(HttpStatus.INTERNAL_SERVER_ERROR,
              'Application Invocation Error',
              e.toString());

}
