# dart_endpoints

### Description

Implementation of Google Cloud Endpoints in Dart.

### Usage

##### app.yaml configuration

`app.yaml` needs to contain a handler for `/_ah/spi/.*` so that App Engine
will check for a Cloud Endpoints configuration when deploying.

```
version: 1
runtime: contrib-dart
vm: true
api_version: 1
threadsafe: true

manual_scaling:
  instances: 1

handlers:
- url: /_ah/spi/.*
  script: bin/server.dart

- url: /.*
  script: bin/server.dart
```

##### Main API Class

Each API is defined by a class with an `@ApiClass` annotation,
specifying at least a `name` and a `version`.

```
@ApiClass(
  name: 'myDartApi',
  version: 'v1',
  description: 'My Awesome Dart Cloud Endpoint'
)
class MyApi {
  (...)
}
```

##### Request/Response Messages

The data that is sent to/from the API is defined as classes extending `ApiMessage`.
This class needs to have an unnamed constructor that doesn't require any parameters.
The API Backend will call `new MyRequest()` and then set the properties one by one.

```
class MyRequest extends ApiMessage {
  String message;
  MyRequest([this.message]);
}
```

All public properties of this class will be used to construct an according
JSON object. Allowed types are `int`, `double`, `bool`, `string`, `DateTime`,
another `ApiMessage` class, or a `List<T>` using one of those types.

You can define extra options for the properties by using an @ApiProperty annotation.

The `variant` parameter influences how numbers are handled in the backend.

For `int` properties the parameter can take the values `int32`, `uint32`, `int64` or `uint64`.
The 64-bit variants will be represented as `String` in the JSON objects.

For `double` properties the `variant` parameter can take the value `double` or `float`

##### Methods

(TODO: info about @ApiMethod...)

##### Authentication

(TODO: info about ApiUser, API method format and allowedClientIds)

##### Errors

(TODO: info about Errors)


##### API Server

In `bin/server.dart` create a new instance of ApiServer and add your Api class instances.
ApiServer exposes a shelf handler which you can add to a shelf cascade,
best before all your other handlers.

Since APIs can return 404 as a valid response, the default configuration of
`shelf.Cascade` which cascades on 404 and 405 errors doesn't work.
Instead you will have to use 501 responses to trigger cascading.
You can also return `ApiServer.cascadeResponse` from your methods to do this.

```
void main() {
  var api_server = new ApiServer();
  api_server.addApi(new MyApi());
  var cascade = new Cascade(statusCodes: [501])
    .add(api_server.handler)
    .add(_myHandler)
    .add(shelf_ae.assetHandler);

  shelf_ae.serve(cascade.handler);
}
```

##### Testing

(TODO: info about Api Explorer)

##### Using your API

(TODO: info about client library generation)
