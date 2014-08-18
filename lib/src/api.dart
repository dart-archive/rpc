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

class ApiUser {
  final String id;
  final String email;
  ApiUser(this.id, this.email);
}
