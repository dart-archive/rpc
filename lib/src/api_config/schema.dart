part of endpoints.api_config;

class ApiConfigSchema {
  ClassMirror _schemaClass;
  String _schemaName;
  Map<Symbol, ApiConfigSchemaProperty> _properties = {};

  ApiConfigSchema(this._schemaClass) {
    _schemaName = MirrorSystem.getName(_schemaClass.simpleName);

    var declarations = _schemaClass.declarations;

    var properties = _schemaClass.declarations.values.where(
      (dm) => dm is VariableMirror &&
              !dm.isConst && !dm.isFinal && !dm.isPrivate && !dm.isStatic
    );

    properties.forEach((VariableMirror vm) {
      _properties[vm.simpleName] = new ApiConfigSchemaProperty(vm, _schemaName);
    });
  }

  String get schemaName => _schemaName;

  List<ApiConfigSchema> get subSchemas {
    List schemas = [];
    _properties.values.forEach((prop) => schemas.addAll(prop.subSchemas));
    return schemas;
  }

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
