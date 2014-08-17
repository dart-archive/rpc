library endpoints.api;

import 'dart:convert' show JSON;
import 'package:shelf/shelf.dart' show Response;

/**
 * Use as annotation for your main API class.
 * [name] and [version] are required.
 */
class ApiClass {
  final String name;
  final String version;
  final String description;

  const ApiClass({this.name, this.version, this.description});
}

/**
 * Use as annotation for your API methods inside of the API class.
 * [name] and [path] are required.
 */
class ApiMethod {
  final String name;
  final String path;
  final String method;
  final String description;

  const ApiMethod({this.name, this.path, this.method: 'GET', this.description});
}

/**
 * Optional annotation for parameters inside of API request/response messages.
 */
class ApiProperty {
  final String description;

  final bool required;
  final defaultValue;
  final int maxValue;
  final int minValue;
  final String variant;

  const ApiProperty({this.required, this.description, this.defaultValue, this.maxValue, this.minValue, this.variant});
}

/// Base class for all API Classes
abstract class Api {}

/// Base class for API response/request messages
abstract class ApiMessage {}

/**
 * Special [ApiMessage] to show that a method
 * doesn't need a request or doesn't return a response
 */
class VoidMessage extends ApiMessage {
  VoidMessage();
}


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

class ApiUser {
  final String id;
  final String email;
  ApiUser(this.id, this.email);
}
