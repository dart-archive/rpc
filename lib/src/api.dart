library endpoints.api;

class ApiClass {
  final String name;
  final String version;
  final String description;

  const ApiClass({this.name, this.version, this.description});
}

class ApiMethod {
  final String path;
  final String method;
  final String description;

  const ApiMethod({this.path, this.method, this.description});
}

abstract class Api {}
