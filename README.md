# RPC

### Description

Light-weight RPC package for creating RESTful server-side Dart APIs. The package
supports the Google
 [Discovery Document](https://developers.google.com/discovery/v1/reference/apis)
format for message encoding and HTTP REST for routing of requests.

The discovery documents for the API are automatically generated and are
compatible with existing Discovery Document client stub generators (see the
"Calling the API" section below for more details).
This makes it easy to create a server side API that can be called by any client
language for which there is a Discovery Document client stub generator.

### Simple Example

Getting started is simple! The example below gives a quick overview of how to
create an API and in the following sections a more elaborate description follows
of how to build the API and setup an API server.

```dart
@ApiClass(version: 'v1', description: 'My Dart server side API' /* optional */)
class Cloud {
  @ApiMethod(method: 'GET', path: 'resource/{name}')
  ResourceMessage getResource(String name) {
    ... find resource of name {resourceName} ...
    return new ResourceMessage
        ..id = resource.id
        ..name = resource.name
        ..capacity = resource.capacity;
  }

  @ApiMethod(method: 'POST', path: 'resource/{name}/update')
  VoidMessage updateResource(String name, UpdateMessage request) {
    ... process request, throw on error ...
  }
}

class ResourceMessage {
  int id;
  String name;
  int capacity;
}

class UpdateMessage {
  int newCapacity;
}
```

Two complete examples using respectively `dart:io` and `shelf` can be found at
[Example](https://github.com/dart-lang/rpc/tree/master/example).

### Usage

##### Terminology

We use the following concepts below when describing how to build your API.

- Top-level class - This is the API entry-point. It describes the API name and
version. The top-level class is defined via the `ApiClass` annotation.
- Resource - Resources are used to group methods together for a cleaner API
structure. Class fields annotated with `@ApiResource` are exposed as resources. 
- Method - Methods are what's invoked!! They specify how to route requests and
the valid parameters and the response. Only methods annotated with the
`ApiMethod` annotation are exposed. 
- Schema - Schemas are used to describe response and the request messages
passed in the body of the HTTP request.
- Properties - A schema contains properties. Each property can optionally be
further restricted by the `ApiProperty` annotation.

##### Main API Class

Defining an API starts with annotating a class with the `@ApiClass` annotation.
It must specify at least the `version` field. The API name can optionally be
specified via the `name` field and will default to the class name in camel-case
if omitted.

```dart
@ApiClass(
  name: 'cloud',  // Optional (default is 'cloud' since class name is Cloud).
  version: 'v1',
  description: 'My Dart server side API' // optional
)
class Cloud  {
  (...)
}
```

The above API would be available at the path `/cloud/v1`. E.g. if the server
was serving on `http://localhost:8080` the API base url would be
`http://localhost:8080/cloud/v1`.
 
##### Methods

Inside of your API class you can define public methods that will
correspond to methods that can be called on your API.

For a method to be exposed as a remote API method it must be annotated with
the `@ApiMethod` annotation specifying a unique path used for routing requests
to the method.

The `@ApiMethod` annotation also supports specifying the HTTP method used to
invoke the method. The `method` field is used for this. If omitted the HTTP
method defaults to `GET`.

A description of the method can also be specified using the `description`
field. If omitted it defaults to the empty string.

###### Response message (return value)

A method must always return a response. The response can be either an instance 
of a class or a future of the instance.
In the case where a method has no response the predefined VoidMessage class
should be returned.

Example method returning nothing:

```dart
@ApiMethod(path: 'voidMethod')
VoidMessage myVoidMethod() {
  ...
  return null;
}
```

Example method returning class:

```dart
class MyResponse {
  String result;
}

@ApiMethod(path: 'someMethod')
MyResponse myMethod() {
  ...
  return new MyResponse();
}
```

Example method returning a future:

```dart
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

Method parameters can be passed in three different ways.

- As a path parameter in the method path (supported on all HTTP methods)
- As a query string parameter (supported for GET)
- As the request body (supported for POST or PUT)  

Path parameters and the request body parameter are required. The query
string parameters are optional named parameters.

Example of a method using POST with both path parameters and a request body:

```dart
@ApiMethod(
  method: 'POST',
  path: 'resource/{name}/type/{type}')
MyResponse myMethod(String name, String type, MyRequest request) {
  ...
  return new MyResponse();
}
```

The curly brackets specify path parameters and must appear as positional
parameters in the same order as on the method signature. The request body
parameter is always specified as the last parameter.

Assuming the above method was part of the Cloud class defined above the url to
the method would be:

`http://localhost:8080/cloud/v1/resource/foo/type/storage`

where the first parameter `name` would get the value `foo` and the `type`
parameter would get the value `storage`.

The `MyRequest` class must be a non-abstract class with an unnamed constructor
taking no arguments. The RPC backend will automatically create an instance of 
the `MyRequest` class, decode the JSON request body, and set the class
instance's fields to the values found in the decoded request body.

If the request body is not needed it is possible to use the VoidMessage class or
change it to use the GET HTTP method. If using GET the method signature would
instead become.

```dart
@ApiMethod(path: '/resource/{name}/type/{type}')
MyResponse myMethod(String name, String type) {
   ...
   return new MyResponse(); 
}
```

When using GET it is possible to use optional named parameters as below.

```dart
@ApiMethod(path: '/resource/{name}/type/{type}')
MyResponse myMethod(String name, String type, {String filter}) {
   ...
   return new MyResponse(); 
}
```

in which case the caller can pass the filter as part of the query string. E.g.

`http://localhost:8080/cloud/v1/resource/foo/type/storage?filter=fast`

##### More about Request/Response Messages

The data sent either as a request (using HTTP POST and PUT) or as a response
body corresponds to a non-abstract class as described above.

The RPC backend will automatically decode HTTP request bodies into class
instances and encode method results into an HTTP response's body. This is done
according to the generated Discovery Document schemas.

Only the public fields of the classes are encoded/decoded. Currently supported
types for the public fields are `int`, `double`, `bool`, `String`,
`DateTime`, List<SomeType>, Map<String, SomeType>, and another message class.

A field can be further annotated using the `@ApiProperty` annotation to
specify default values, format of an `int` or `double` specifying how to
handle it in the backend, min/max value of an `int` property, and whether a
property is required.

For `int` properties the `format` field is used to specify the size of the
integer. It can take the values `int32`, `uint32`, `int64` or `uint64`.
The 64-bit variants will be represented as `String` in the JSON objects.

For `int` properties the `minValue` and `maxValue` fields can be used to
specify the min and max value of the integer.

For `double` properties the `format` parameter can take the value
`double` or `float`.

The `defaultValue` field is used to specify a default value. The `required`
fields is used to specify whether a field is required.

Example schema:

```dart
class MyRequest {
   @ApiProperty(
     format: 'uint32',
     defaultValue=40,
     minValue=0,
     maxValue=150)
   int age;

   @ApiProperty(format: 'float')
   double averageAge;
}
```

##### Resources

Resources can be used to provide structure to your API by grouping certain API
methods together under a resource. To create an API resource you will add a
field to the class annotated with the `@ApiClass` annotation. The field must
point to another class (the resource) containing the methods that should be 
exposed together for this resource. The field must be annotated with the
`@ApiResource` annotation. By default the name of the resource will be the
field name in camel-case. If another name is desired the `name` field can be
used in the `@ApiResource` annotation.

Example resource API:

```dart

@ApiClass(version: 'v1')
class Cloud {

  @ApiResource(name: 'myResource')
  MyResource aResource = new MyResource();
  
  ...
}

class MyResource {
  
  @ApiMethod(path: 'someMethod')
  MyResponse myResourceMethod() { return new MyResponse(); }
}
```

Notice the @ApiResource annotation is on the field rather than the resource 
class. This allows for a resource class to be used in multiple places (e.g.
different versions) of the API.

Also notice the path of the `MyResource.myResourceMethod` method is
independent from the resource. E.g. if MyResource was used in the previous
mentioned Cloud API the method would be exposed at the url 
`http://<server ip>:<port>/cloud/v1/someMethod`.

##### API Server

When having annotated your classes, resources, and methods you must create an 
`ApiServer` to route the HTTP requests to your methods.
Creating a RPC API server is done by first creating an instance of the
`ApiServer` class and calling the addApi method with an instance of the class
annotated with the `@ApiClass` annotation.

You can choose to use any web server framework you prefer for serving HTTP
requests. The RPC package includes examples for both the standard `dart:io`
`HttpServer` as well as an example using the shelf middleware.

E.g. to use `dart:io` you would do something like:

```dart

final ApiServer _apiServer = new ApiServer('' /* empty api prefix */);

main() async {
  _apiServer.addApi(new Cloud());
  HttpServer server = await HttpServer.bind(InternetAddress.ANY_IP_V4, 9090);
  server.listen(_apiServer.httpRequestHandler);
}

```

The above example uses the default provided `ApiServer` HTTP request handler
which converts the `HttpRequest` to a `HttpApiRequest` and forwards it
along. A custom HTTP request handler doing the conversion to the
`HttpApiRequest` class and calling the `ApiServer.handleHttpApiRequest`
method itself can also be used if more flexibility is needed.

Notice that the `ApiServer` is agnostic of the HTTP server framework being 
used by the application. The RPC package does provide a request handler for the
standard `dart:io` `HttpRequest` class. There is also a `shelf_rpc` package
which provides the equivalent for shelf (see the example for how this is done).
However as the RPC `ApiServer` is using its own `HttpApiRequest` class any
framework can be used as long as it converts the HTTP request to a corresponding
`HttpApiRequest` and calls the `ApiServer.handleHttpApiRequest` method.

The result of calling the `handleHttpApiRequest` method is returned as an
`HttpApiResponse` which contains a stream with the encoded response or in the
case of an error it contains the encoded JSON error as well as the exception
thrown internally.

##### Errors

There are a couple of predefined error classes that can be used to return an
error from the server to the client. They are:

- any `RpcError(HTTP status code, `Error name`, `Any message`)`
- 400 `BadRequestError('You sent some data we don't understand.')`
- 404 `NotFoundError('We didn't find the api or method you are looking for.')`
- 500 `ApplicationError('The invoked method failed with an exception.')`
- 500 `Some internal exception occurred and it was not due to a method invocation.`

If one of the above exceptions are thrown by the server API implementation it
will be sent back as a serialized json response as described below. Any other
exception thrown will be wrapped in the `ApplicationError` exception
containing the `toString()` version of the internal exception as the method.

The JSON format for errors is:

```
{
  error: {
    code: <http status code>
    message: <error message>
  }
}      
```

##### Calling the API

Once your API is deployed you can use the
[Discovery API Client Generator](https://github.com/dart-lang/discoveryapis_generator)
for Dart to generate client side libraries to access your API. Discovery
Document generators for other languages can also be used to call
your API from e.g Python or Java.

There are currently two ways to generate a client library. First you get the
Discovery Document from the server.

```bash
URL='https://your_app_server/discovery/v1/apis/cloud/v1/rest'
mkdir input
curl -o input/cloud.json $URL
```

Then you can either checkout the generator locally or add it as a dependency in
your `pubspec.yaml`.

###### Checking out the GitHub generator repository

```
$ git clone https://github.com/dart-lang/discoveryapis_generator.git
$ cd discoveryapis_generator
$ pub get
$ dart bin/generate.dart generate --input-dir=input --output-dir=output --package-name=cloud
```

You can then include the generated library in your own client project, or
simply copy the generated dart file into your package and add the dependencies
from the generated `pubspec.yaml` file to your client package's
`pubspec.yaml`.

###### Using a `pubspec.yaml` dependency to your project

Edit your project's `pubspec.yaml` file to contain a dependency to the client
generator. It should be sufficient to make it a `dev_dependency`.

```
dev_dependencies:
  discovery_api_client_generator:
    git:
      url: https://github.com/dart-lang/discoveryapis_generator.git
```
Run the below commands within your project.

```
$ pub get
$ pub run discovery_api_client_generator:generate generate --input-dir=input --output-dir=output --package-name=myapi
```

The libraries can be used like any of the other Google Client API libraries,
[some samples here](https://github.com/dart-lang/googleapis_examples).
