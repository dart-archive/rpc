part of endpoints.api_config;

const Map _typeMap = const {
  const [int, null]: 'integer',
  const [int, 'int32']: 'integer',
  const [int, 'uint32']: 'integer',
  const [int, 'int64']: 'string',
  const [int, 'uint64']: 'string',
  const [String, null]: 'string',
  const [double, null]: 'number',
  const [double, 'double']: 'number',
  const [double, 'float']: 'number',
  const [bool, null]: 'boolean',
  const [DateTime, null]: 'string' 
};

const Map _formatMap = const {
  const [int, null]: 'int32',
  const [int, 'int32']: 'int32',
  const [int, 'uint32']: 'uint32',
  const [int, 'int64']: 'int64',
  const [int, 'uint64']: 'uint64',
  const [double, null]: 'double',
  const [double, 'double']: 'double',
  const [double, 'float']: 'float',
  const [DateTime, null]: 'date-time'
};

class ApiConfigSchemaProperty {
  VariableMirror _property;
  String _propertyName;
  TypeMirror _type;
  ApiConfigSchema _ref;
  bool _repeated = false;
  String _apiType;
  String _apiFormat;
  ApiProperty _meta;

  ApiConfigSchemaProperty(this._property, String schemaName, ApiConfig parent) {
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

    var metas = _property.metadata.where((m) => m.reflectee.runtimeType == ApiProperty);
    if (metas.length > 0) {
      _meta = metas.first.reflectee;
    }

    if (_type.isSubtypeOf(reflectType(ApiMessage))) {
      _ref = parent._getSchema(MirrorSystem.getName(_type.simpleName));
      if (_ref == null) {
        _ref = new ApiConfigSchema(_type, parent);
      }
    } else {
      var variant;
      if (_meta != null) {
        variant = _meta.variant;
      }
      _apiType = _typeMap[[_type.reflectedType, variant]];
      _apiFormat = _formatMap[[_type.reflectedType, variant]];
    }

    if (_ref == null && _apiType == null) {
      throw new ApiConfigError('${schemaName}.${_propertyName}: Invalid type.');
    }
  }

  String get propertyName => _propertyName;

}
