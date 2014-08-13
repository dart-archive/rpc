# dart_endpoints

### Description

Implementation of Google Cloud Endpoints in Dart.

### Usage

`app.yaml` needs to contain a handler for `/_ah/spi/.*` so that App Engine will check for a Cloud Endpoints configuration when deploying.

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

Each API is represented by a class extending `Api`.
Additionally the class needs an `@ApiClass` annotation, specifying at least a `name` and a `version`.

```
@ApiClass(
  name: 'myDartApi',
  version: 'v1',
  description: 'My Awesome Dart Cloud Endpoint'
)
class MyApi extends Api {
  (...)
}
```

The data that is sent to/from the API is defined as classes extending `ApiMessage`:

```
class MyRequest extends ApiMessage {
  String message;
  MyRequest(this.message);
}
```

All public properties of this class will be used to construct an according JSON object. Allowed types are `int`, `double`, `bool`, `string`, another `ApiMessage` class, or a `List<T>` using one of those types.


(TODO: info about @ApiMessage...)


In `bin/server.dart` create a new instance of ApiServer and add your Api class instances.
ApiServer exposes a shelf handler which you can add to a shelf cascade, best before all your other handlers.

```
void main() {
  var api_server = new ApiServer();
  api_server.addApi(new MyApi());
  var cascade = new Cascade()
    .add(api_server.handler)
    .add(_myHandler)
    .add(shelf_ae.assetHandler);

  shelf_ae.serve(cascade.handler);
}
```
