# dart_endpoints

### Description

Implementation of Google Cloud Endpoints in Dart.

### Usage

`app.yaml` needs to contain a handler for /_ah/spi/.* so App Engine will check for a cloud endpoints configuration

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
