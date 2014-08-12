part of endpoints.api_config;

class ApiConfigSchemaProperty {
  VariableMirror _property;
  String _propertyName;
  TypeMirror _type;
  ApiConfigSchema _ref;

  ApiConfigSchemaProperty(this._property) {
    _propertyName = MirrorSystem.getName(_property.simpleName);
    _type = _property.type;
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