part of endpoints.api_config;

class ApiConfigSchema {
  ClassMirror _schemaClass;
  String _schemaName;
  Map<Symbol, ApiConfigSchemaProperty> _properties = {};

  ApiConfigSchema(this._schemaClass, ApiConfig parent) {
    _schemaName = MirrorSystem.getName(_schemaClass.simpleName);
    parent._addSchema(_schemaName, this);
    
    var declarations = _schemaClass.declarations;

    var properties = _schemaClass.declarations.values.where(
      (dm) => dm is VariableMirror &&
              !dm.isConst && !dm.isFinal && !dm.isPrivate && !dm.isStatic
    );

    properties.forEach((VariableMirror vm) {
      _properties[vm.simpleName] = new ApiConfigSchemaProperty(vm, _schemaName, parent);
    });
  }

  String get schemaName => _schemaName;

  Map get descriptor {
    var descriptor = {};
    descriptor['id'] = schemaName;
    descriptor['type'] = 'object';
    descriptor['properties'] = {};

    _properties.values.forEach((prop) {
      descriptor['properties'][prop.propertyName] = prop.descriptor;
    });

    return descriptor;
  }
}
