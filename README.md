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

The data that is sent to/from the API is defined in (non-abstract) classes.
These classes need to have an unnamed constructor that doesn't require any parameters.
The API Backend will call `new MyRequest()` and then set the properties one by one.

```
class MyRequest {
  String message;
  MyRequest([this.message]);
}
```

All public properties of this class will be used to construct an according
JSON object. Allowed types are `int`, `double`, `bool`, `string`, `DateTime`,
another message class, or a `List<T>` using one of those types.

You can define extra options for the properties by using an @ApiProperty annotation.

The `variant` parameter influences how numbers are handled in the backend.

For `int` properties the parameter can take the values `int32`, `uint32`, `int64` or `uint64`.
The 64-bit variants will be represented as `String` in the JSON objects.

For `double` properties the `variant` parameter can take the value `double` or `float`

##### Methods

Inside of your API class you can define public methods that will
correspond to methods that can be called on your API.

API Methods take one non-optional request message class as parameter and return
a response message class or a Future of a response message class.

```
MyResponse myMethod(MyRequest request) {
  
  return new MyResponse();
}
```

```
Future<MyResponse> myFutureMethod(MyRequest request) {
  ...
    completer.complete(new MyResponse();
  ...
  return completer.future;
}
```

If your method doesn't need a request or doesn't return a response you can
use the `VoidMessage` class instead.

```
VoidMessage hearNoEvilSpeakNoEvil(VoidMessage _) {
  return null;
}
```

To turn your methods into actual API methods you will need to add an
`@ApiMethod` annotation, specifying at least a `name` and a `path`.
You can also define the HTTP-`method` if it is different from the default `GET`
and a `description` to be displayed in the discovery document, API Explorer and
generated client libraries.

Some examples:
```
@ApiMethod(
  name: 'resource.list',
  path: 'resource',
  description: 'list models' 
)
MyModelList list(VoidMessage _) {...}
```

```
@ApiMethod(
  name: 'resource.insert',
  path: 'resource',
  method: 'POST',
  description: 'insert model' 
)
MyModel insert(MyModel request) {...}
```

```
@ApiMethod(
  name: 'resource.get',
  path: 'resource/{id}',
  description: 'get model' 
)
MyModel get(MyModelRequest request) {...}
```

```
@ApiMethod(
  name: 'resource.update',
  path: 'resource/{id}',
  method: 'PUT',
  description: 'update model' 
)
MyModel update(MyModel request) {...}
```

##### Authentication

If you want to use OAuth authentication in your API, you will first have to
get a Client ID from the [Google Developers Console](https://console.developers.google.com/).
You then add this Client ID to the `allowedClientIds` property of the
`@ApiClass` annotation.

```
@ApiClass(
  name: 'myDartApi',
  version: 'v1',
  description: 'My Awesome Dart Cloud Endpoint'
  allowedClientIds: const ['MY_CLIENT_ID']
)
```

If you want to test your API using the [Google APIs Explorer](https://developers.google.com/apis-explorer/)
(see below) you can also add the `API_EXPLORER_CLIENT_ID`.

```
@ApiClass(
  name: 'myDartApi',
  version: 'v1',
  description: 'My Awesome Dart Cloud Endpoint'
  allowedClientIds: const ['MY_CLIENT_ID', API_EXPLORER_CLIENT_ID]
)
```

For the methods where you need authentication you add an extra `ApiUser` parameter.

```
@ApiMethod(
  name: 'resource.auth_get',
  path: 'resource/{id}',
  description: 'get model' 
)
MyModel authGet(MyModelRequest request, ApiUser user) {...}
```

If no valid user can be retrieved from the HTTP request, a 401 Unauthorized error will be
automatically returned before actually calling your method. Otherwise you can access the
user's Google ID and email adress (if authentication included the `email` scope).

If you want to check successful authentication yourself, or authentication is optional
for your method you can include the `ApiUser` parameter as optional parameter.

```
@ApiMethod(
  name: 'resource.auth_get',
  path: 'resource/{id}',
  description: 'get model' 
)
MyModel authGet(MyModelRequest request, [ApiUser user]) {...}
```

In this case `user` will be `null` if no authentication happened,
or the authentication wasn't for one of your specified Client IDs.
If the authentication failed because of invalid or expired tokens,
this will still trigger a 401 error.

##### Errors

If you want to return errors to users of your API, e.g. if a requested entity wasn't found,
you can throw and `EndpointsError` in your method.

It's recommended to use one of the predefined error classes:

-  400 `throw new BadRequestError('You sent some data we don't understand.');`
-  401 `throw new UnauthorizedError('You need to be authenticated.')`
-  403 `throw new ForbiddenError('You are not allowed to do this!')` 
-  404 `throw new NotFoundError('We didn't find what you are looking for.');`
-  500 `throw new InternalServerError('We did something wrong...');`

Any uncaught errors happening in your API method will be returned as `InternalServerError`.


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
