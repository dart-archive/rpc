library endpoints.errors;

import 'dart:convert' show JSON;
import 'package:shelf/shelf.dart' show Response;

class EndpointsError implements Exception {

  final String state = 'APPLICATION_ERROR';
  final String name;
  final String msg;
  final int code;

  EndpointsError(this.code, this.name, this.msg);

  Map toJson() {
    var json = {};
    json['state'] = state;
    json['error_name'] = name;
    json['code'] = code;
    json['error_message'] = msg;
    return json;
  }

  String toString() {
    return JSON.encode(toJson());
  }

  Response toResponse() {
    return new Response(
      code,
      body: toString(),
      headers: {'Content-Type' : 'application/json'}
    );
  }
}

class NotFoundError extends EndpointsError {
  NotFoundError([String msg = "Not found."]) : super(404, 'Not Found', msg);
}

class BadRequestError extends EndpointsError {
  BadRequestError([String msg = "Bad request."]) : super(400, 'Bad Request', msg);
}

class UnauthorizedError extends EndpointsError {
  UnauthorizedError([String msg = "Unauthorized."]) : super(401, 'Unauthorized', msg);
}

class ForbiddenError extends EndpointsError {
  ForbiddenError([String msg = "Forbidden."]) : super(403, 'Forbidden', msg);
}

class InternalServerError extends EndpointsError {
  InternalServerError([String msg = "Internal Server Error."]) : super(500, 'Internal Server Error', msg);
}
