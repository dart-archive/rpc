library endpoints.api;

const String API_EXPLORER_CLIENT_ID = '292824132082.apps.googleusercontent.com';

/**
 * Use as annotation for your main API class.
 * [name] and [version] are required.
 */
class ApiClass {
  final String name;
  final String version;
  final String description;
  final List<String> allowedClientIds;

  const ApiClass({this.name, this.version, this.description, this.allowedClientIds: const []});
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
  /// description of the property to be included in the discovery document
  final String description;

  /**
   * Specifies the representation of int and double properties in the backend
   *
   * Possible values for int: 'int32' (default), 'uint32', 'int64', 'uint64'
   *
   * The 64 bit values will be represented as String in the JSON requests/responses
   *
   * Possible values for double: 'double' (default), 'float'
   */
  final String variant;

  /// Whether the property needs to be supplied for requests
  final bool required;

  /// Default value for this property if it's not supplied in the request
  final defaultValue;

  /// For int properties: the minimal value allowed in requests
  final int minValue;

  /// For int properties: the maximal value allowed in requests
  final int maxValue;

  /**
   * Possible values for enum properties, as value - description pairs.
   * Properties using this will have to be String
   */
  final Map<String, String> values;

  const ApiProperty({
    this.description,
    this.variant,
    this.required: false,
    this.defaultValue,
    this.minValue,
    this.maxValue,
    this.values}
  );
}

/**
 * Special API Message to use when a method
 * doesn't need a request or doesn't return a response
 */
class VoidMessage {}

/**
 * Currently authenticated user.
 * `email` is only available if the email-scope was
 * included during authentication.
 */
class ApiUser {
  final String id;
  final String email;
  ApiUser(this.id, this.email);
}
