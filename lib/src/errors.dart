library endpoints.errors;

import 'dart:convert' show JSON;
import 'package:shelf/shelf.dart' show Response;

class ApiException implements Exception {

  final String state = 'APPLICATION_ERROR';
  final String name;
  final String msg;
  final int code;

  ApiException(this.code, this.name, this.msg);

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

class ApiNotFoundException extends ApiException {
  ApiNotFoundException([String msg = "Not found."]) : super(404, 'Not Found', msg);
}

class ApiBadRequestException extends ApiException {
  ApiBadRequestException([String msg = "Bad request."]) : super(400, 'Bad Request', msg);
}

class ApiUnauthorizedException extends ApiException {
  ApiUnauthorizedException([String msg = "Unauthorized."]) : super(401, 'Unauthorized', msg);
}

class ApiForbiddenException extends ApiException {
  ApiForbiddenException([String msg = "Forbidden."]) : super(403, 'Forbidden', msg);
}

class ApiInternalServerException extends ApiException {
  ApiInternalServerException([String msg = "Internal Server Error."]) : super(500, 'Internal Server Error', msg);
}
