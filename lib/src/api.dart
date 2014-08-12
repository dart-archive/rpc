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

class ApiParameter {
  final String description;
  
  final bool required;
  final defaultValue;
  final int maxValue;
  final int minValue;

  const ApiParameter({this.required, this.description, this.defaultValue, this.maxValue, this.minValue});
}

abstract class Api {}
abstract class ApiMessage {}

class VoidMessage extends ApiMessage {
  VoidMessage();
}

