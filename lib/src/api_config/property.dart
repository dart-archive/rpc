part of endpoints.api_config;

class ApiConfigSchemaProperty {
  VariableMirror _property;
  String _propertyName;
  TypeMirror _type;
  ApiConfigSchema _ref;
  bool _repeated = false;
  String _apiType;
  String _apiFormat;

  ApiConfigSchemaProperty(this._property, String schemaName) {
    _propertyName = MirrorSystem.getName(_property.simpleName);
    _type = _property.type;
    if(_type.simpleName == #dynamic) {
      throw new ApiConfigError('${schemaName}.${_propertyName}: Property needs to have a type defined.');
    }
    if (_type.isSubtypeOf(reflectType(List))) {
      _repeated = true;
      var types = _type.typeArguments;
      if (types.length != 1) {
        throw new ApiConfigError('${schemaName}.${_propertyName}: List property must specify exactly one type parameter');
      }
      _type = types[0];
      if(_type.simpleName == #dynamic) {
        throw new ApiConfigError('${schemaName}.${_propertyName}: List property must specify exactly one type parameter');
      }
    }

    // TODO: determine valid type or reference

    if (_ref == null && _apiType == null) {
      throw new ApiConfigError('${schemaName}.${_propertyName}: Invalid type.');
    }
  }

  String get propertyName => _propertyName;

  List<ApiConfigSchema> get subSchemas {
    List schemas = [];
    if (_ref != null) {
      schemas.add(_ref);
      schemas.addAll(_ref.subSchemas);
    }
    return schemas;
  }
}
