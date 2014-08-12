part of endpoints.api_config;

class ApiConfigSchema {
  ClassMirror _schemaClass;
  String _schemaName;

  ApiConfigSchema(this._schemaClass) {
    _schemaName = MirrorSystem.getName(_schemaClass.simpleName);
    //TODO: get properties and do type checks
  }

  String get schemaName => _schemaName;

  Map get descriptor {
    var descriptor = {};
    descriptor['id'] = schemaName;
    descriptor['type'] = 'object';
    descriptor['properties'] = {};

    //TODO add actual properties
    descriptor['properties']['debug'] = {
      'type': 'string'
    };

    return descriptor;
  }
}