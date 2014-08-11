library endpoints.api;

class ApiClass {
  final String name;
  final String version;
  final String description;

  const ApiClass({this.name, this.version, this.description});
}

class ApiMethod {
  final String name;
  final String path;
  final String method;
  final String description;

  const ApiMethod({this.name, this.path, this.method: 'GET', this.description});
}

abstract class Api {}
abstract class ApiMessage {}

class VoidMessage extends ApiMessage {
  VoidMessage();
}

