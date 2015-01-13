# RPC

### Description

Light-weight RPC package for implementing server-side Dart APIs. The package 
supports the Google Discovery Document format for message encoding and HTTP 
rest for routing of requests.

The discovery documents for the API will be automatically generated and are 
compatible with existing Discovery Document client stub generators. 
This way it is easy to create a server side API that can called by any client
language which has a Discovery Document client stub generator.

### Usage

For a more elaborate example see [Examples](https://github.com/dart-lang/rpc).

##### Main API Class

Each API is defined by a class with an `@ApiClass` annotation,
specifying at least a `version`. The API name can be specified by the `name`
field and will default to the class name in camel-case if omitted.

```
@ApiClass(
  name: 'myApi', // optional (default is the same since class name is MyApi).
  version: 'v1',
  description: 'My Awesome Dart server side API' // optional
)
class MyApi {
  (...)
}
```

The above API would be available at the path `/myApi/v1`. E.g. if the server
was serving on `http://localhost:8080` the API base url would be
`http://localhost:8080/myApi/v1`.
 
##### Methods

Inside of your API class you can define public methods that will
correspond to methods that can be called on your API.

For a method to be exposed as a remote API endpoint it must be annotated with
the `@ApiMethod` annotation specifying a unique path used for routing requests
to the method.

The `@ApiMethod` annotation also supports specifying the HTTP method used to
invoke the method. The `method` field is used for this. If omitted the HTTP
method defaults to `GET`.

A description of the method can also be specified using the `description` 
field. If omitted it defaults to the empty string.

###### Response

A method must always return a response. The response can be either a class or
a future of the class.
In the case where a method has no response to return the VoidMessage class 
should be used.

Example returning nothing:

```
@ApiMethod(path: 'voidMethod')
VoidMessage myVoidMethod() {
  ...
  return null;
}
```

Example returning class:

```
@ApiMethod(path: 'someMethod')
MyResponse myMethod() {
  ...
  return new MyResponse();
}
```

Example returning a future:

```
@ApiMethod(path: 'futureMethod')
Future<MyResponse> myFutureMethod() {
  ...
    completer.complete(new MyResponse();
  ...
  return completer.future;
}
```

The `MyResponse` class must be a non-abstract class with an unnamed 
constructor taking no required parameters. The RPC backend will automatically
serialize all public fields of the the `MyResponse` instance into JSON
corresponding to the generated Discovery Document schema.

###### Parameters

Method parameters can be specified in three ways.

- As a path parameter in the method path (supported on all HTTP methods)
- As a query string parameter (supported for GET)
- As the request body (supported for POST or PUT)  

Path parameters and the request body parameter are required. The query 
string parameters are optional named parameters.

An example of a method using POST with both path parameters and a request body.

```
@ApiMethod(
  method: 'POST',
  path: 'resource/{name}/type/{type}') 
MyResponse myMethod(String name, String type, MyRequest request) {
  ...
  return new MyResponse();
}
```

The curly bracket specify the path parameters and must appear as positional 
parameters in the same order of the method signature. The request body parameter 
is always specified as the last parameter.

Assuming the above method was part of the MyApi class defined above the url to 
the method would be:

`http://localhost:8080/myApi/v1/resource/foo/type/storage`

where the first parameter `name` would get the value `foo` and the `type`
parameter would get the value `storage`.

The `MyRequest` class must be a non-abstract class with an unnamed constructor
taking no arguments. The RPC backend will automatically create an instance of 
the `MyRequest` class, decode the JSON request body, and set the class 
instance's fields to the values found in the decoded request body.

If the request body is not needed it is possible to use the VoidMessage class or 
change it to use the GET HTTP method. If using GET the method signature would 
instead become.

```
@ApiMethod(path: '/resource/{name}/type/{type}')
MyResponse myMethod(String name, String type) {
   ...
   return new MyResponse(); 
}
```

When using GET it is possible to use optional named parameters as below.

```
@ApiMethod(path: '/resource/{name}/type/{type}')
MyResponse myMethod(String name, String type, {String filter}) {
   ...
   return new MyResponse(); 
}
```

in which case the caller can pass the filter as part of the query string. E.g.

`http://localhost:8080/myApi/v1/resource/foo/type/storage?filter=fast` 

##### More about Request/Response Messages

The data sent either as a request (using HTTP POST and PUT) or as a response
body corresponds to a non-abstract class as described above.

The RPC backend will automatically decode HTTP request bodies into class
instances and encode method results into an HTTP response's body. This is done
according to the generated Discovery Document schemas.

Only the public fields of the classes are encoded/decoded. Currently supported
types for the public fields are `int`, `double`, `bool`, `String`,
`DateTime`, and another message class.

A field can be further annotated using the `@ApiProperty` annotation to 
specify default values, format of an `int` or `double` specifying how to 
handle it in the backend, min/max value of an `int` property, and whether a
property is required.

For `int` properties the `format` field is used to specific the size of the
integer. It can take the values `int32`, `uint32`, `int64` or `uint64`.
The 64-bit variants will be represented as `String` in the JSON objects.

For `int` properties the `minValue` and `maxValue` fields can be used to
specify the min and max value of the integer.

For `double` properties the `format` parameter can take the value
`double` or `float`.

The `defaultValue` field is used to a default value. The `required` fields
is used to specify whether a field is required.

##### API Server

To create a RPC API server you would first create an instance of the
`ApiServer` class and add an instance of the class annotated with the
`@ApiClass` annotation.

You can choose to use any web server framework you prefer for serving HTTP 
request. The RPC package includes examples for both the standard dart:io
HttpServer as well as an example using the shelf middleware.

E.g. to use shelf you would do something like:

```javascript

final ApiServer _apiServer = new ApiServer();

void main() {
  _apiServer.addApi(new ToyApi());
  var apiRouter = shelf_route.router();
  apiRouter.add('/api', ['GET', 'POST'], _apiHandler, exactMatch: false);
  shelf_io.serve(apiRouter.handler, '0.0.0.0', 9090);
}

/// A shelf handler for '/api' API requests .
Future<shelf.Response> _apiHandler(shelf.Request request) async {
  if (request.url.path.endsWith('/rest')) {
    // Return the discovery doc for the given API.
    return _discoveryDocumentHandler(request);
  }
  try {
    var apiRequest =
        new HttpApiRequest(request.method, request.url.path,
                           request.headers['content-type'], request.read());
    HttpApiResponse apiResponse =
        await _apiServer.handleHttpRequest(apiRequest);
    return new shelf.Response(apiResponse.status, body: apiResponse.body,
                              headers: apiResponse.headers);
  } catch (e) {
    // Just a precaution. It should never happen since the 
    // _apiServer.handleHttpRequest method always returns an HttpApiResponse.
    return new shelf.Response.internalServerError(body: e.toString());
  }
}

Future<shelf.Response> _discoveryDocumentHandler(shelf.Request request) {
  var requestPath = request.url.path;
  var apiKey = requestPath.substring(0, requestPath.length - '/rest'.length);
  var uri = request.requestedUri;
  var baseUrl = '${uri.scheme}://${uri.host}:${uri.port}/';
  var doc = _apiServer.getDiscoveryDocument(apiKey, 'api', baseUrl);
  if (doc == null) {
    return new Future.value(
        new shelf.Response.notFound('API \'${apiKey} not found.'));
  }
  return new Future.value(new shelf.Response.ok(doc));
}
```

Notice that the `ApiServer` supports its own `HttpApiRequest` and 
`HttpApiResponse` format that is agnostic to whether the enclosing web server
is using `shelf` of `dart:io`. In the above case the `shelf.Request` is used
to create an `HttpApiRequest` containing the information needed to invoke the
correct API method using the `ApiServer`'s handleHttpRequest method.
The result of the invocation is returned as an `HttpApiResponse` which
contains a stream with the encoded response or in the case of an error it 
contains the encoded JSON error as well as the exception thrown internally. 

##### Errors

The following predefined errors are supported: 


As mentioned above invoking a method is done using the
`ApiServer::handleHttpRequest` method which in turn returns an
`HttpApiResponse` containing either the result of an successful invocation or
an error. In the case of success the `HttpApiResponse`'s status code will be 
`200`. If it is not `200` the response contains an error. The following 
predefined errors are currently supported.

- 400 `BadRequestError('You sent some data we don't understand.');`
- 404 `NotFoundError('We didn't find the api or method you are looking for.');`
- 500 `ApplicationError('The invoked method failed with an exception.');`
- 500 `Some internal exception occurred and it was not due to a method invocation.`

The `HttpApiResponse` also contains the internal exception thrown at failure
time. This can be retrieved via the `HttpApiResponse::exception` getter and
e.g. be used to return a more elaborate error to the client or to distinguish
between an `ApplicationError` and another internal error happening.

Any errors thrown by your API method will be returned as an 
`ApplicationError`.

The JSON format for errors are: 

```
{
  error: {
    code: <http status code>
    message: <error message>
  }
}      
```

##### Using your API

Once your API is deployed you can use the [Discovery API Client Generator](https://github.com/dart-lang/discovery_api_dart_client_generator)
for Dart to generate client side libraries to access your API. Discovery
Document generators for other languages can of course also be used to e.g call
your API from Python or Java. 

For this you have to download the discovery document and use it with the generator:

```
URL='https://your_app_server/api/myApi/v1/rest'
mkdir input
curl -o input/myapi.json $URL
bin/generate.dart generate --input-dir=input --output-dir=output --package-name=myapi
```

You can then include the library in your project. The libraries can be used 
like any of the other Google Client API libraries, 
[some samples here](https://github.com/dart-lang/googleapis_examples).

