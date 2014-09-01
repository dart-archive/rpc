library endpoints.api;

const String API_EXPLORER_CLIENT_ID = '292824132082.apps.googleusercontent.com';

/**
 * Use as annotation for your main API class.
 *
 * [name] and [version] are required.
 */
class ApiClass {
  /// Name of the API
  final String name;

  /// Version of the API
  final String version;

  /// Description of the API
  final String description;

  /**
   * Client IDs that are allowed for authenticated calls to this API
   *
   * You can create/manage Client IDs at the
   * [Google Developers Console](https://console.developers.google.com)
   */
  final List<String> allowedClientIds;

  const ApiClass({
    this.name,
    this.version,
    this.description,
    this.allowedClientIds: const []
  });
}

/**
 * Use as annotation for your API methods inside of the API class.
 *
 * [name] and [path] are required.
 */
class ApiMethod {

  /**
   * Name of the method
   *
   * Can have `resource.method` format to structure
   * your API calls in groups
   */
  final String name;

  /**
   * Path where to call the method
   *
   * Root path for all calls will be
   * `https://your-app.appspot.com/_ah/api/your-api-name/your-api-version/`
   *
   * Can contain path parameters like `{id}` which have to be part
   * of the request message class specified in the method parameters
   */
  final String path;

  /**
   * Allowed HTTP method for calling this API method.
   *
   * Can be `GET`, `POST`, `PUT`, `PATCH`, `DELETE`
   *
   * Defaults to `GET`
   */
  final String method;

  /// Description of the method
  final String description;

  /**
   * Limit the properties used for requests
   * to a subset of the available properties
   * of the request message class.
   */
  final List<String> requestFields;

  /**
   * Overwrite the request message name to be used in the API.
   *
   * Especially useful to prevent long/ugly auto-generated
   * names when using [requestFields]
   */
  final String requestName;

  /**
   * Limit the properties returned by the API Method
   * to a subset of the available properties
   * of the response message class.
   */
  final List<String> responseFields;

  /**
   * Overwrite the response message name to be used in the API.
   *
   * Especially useful to prevent long/ugly auto-generated
   * names when using [responseFields]
   */
  final String responseName;

  const ApiMethod({
    this.name,
    this.path,
    this.method: 'GET',
    this.description,
    this.requestFields: const [],
    this.requestName,
    this.responseFields: const [],
    this.responseName
  });
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

  /// Don't include this property in request/response messages
  final bool ignore;

  const ApiProperty({
    this.description,
    this.variant,
    this.required: false,
    this.defaultValue,
    this.minValue,
    this.maxValue,
    this.values,
    this.ignore: false}
  );
}

/**
 * Special API Message to use when a method
 * doesn't need a request or doesn't return a response
 */
class VoidMessage {}

/**
 * Special API Message to use when returning
 * a list of other API messages
 *
 * Schema will be called {T-Name}List unless given another name
 * in the @ApiMethod annotation
 */
class ListResponse<T> {

  /// List of items to be returned in the API
  List<T> items;

  ListResponse([this.items]) {
    if (items == null) {
      items = new List<T>();
    }
  }

  /// Add a new item to the response
  void add(T item) {
    if (items == null) {
      items = new List<T>();
    }
    items.add(item);
  }
}

/**
 * Currently authenticated user.
 *
 * `email` is only available if the email-scope was
 * included during authentication.
 */
class ApiUser {
  /// Google ID of the user.
  final String id;

  /// Primary email address of the user
  final String email;

  ApiUser(this.id, this.email);
}
