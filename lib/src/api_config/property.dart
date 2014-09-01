part of endpoints.api_config;

class ApiConfigSchemaProperty {
  String _propertyName;
  String get propertyName => _propertyName;

  bool _repeated = false;
  bool get repeated => _repeated;

  bool _required = false;
  bool get required => _required;

  var _defaultValue;
  get defaultValue => _defaultValue;
  bool get hasDefault => (_defaultValue != null);

  String _apiType;
  String _apiFormat;
  String _apiParameterType;
  ApiProperty _meta;

  factory ApiConfigSchemaProperty(VariableMirror property, ApiConfig parent, {List<String> fields, String name}) {
    var type = property.type;
    var repeated = false;
    ApiProperty meta = null;
    var metas = property.metadata.where((m) => m.reflectee.runtimeType == ApiProperty);
    if (metas.length > 0) {
      meta = metas.first.reflectee;
    }
    if (meta != null && meta.ignore) {
      return null;
    }
    if(type.simpleName == #dynamic) {
      throw new ApiConfigError('${property.simpleName}: Property needs to have a type defined.');
    }
    if (type.isSubtypeOf(reflectType(List))) {
      repeated = true;
      var types = type.typeArguments;
      if (types.length != 1 || types[0].simpleName == #dynamic) {
        throw new ApiConfigError('${property.simpleName}: List property must specify exactly one type parameter');
      }
      type = types[0];
    }
    switch (type.reflectedType) {
      case int: return new IntegerProperty._internal(property, repeated, meta, parent);
      case double: return new DoubleProperty._internal(property, repeated, meta, parent);
      case bool: return new BooleanProperty._internal(property, repeated, meta, parent);
      case String:
        if (meta != null && meta.values != null && meta.values.isNotEmpty) {
          return new EnumProperty._internal(property, repeated, meta, parent);
        }
        return new StringProperty._internal(property, repeated, meta, parent);
      case DateTime: return new DateTimeProperty._internal(property, repeated, meta, parent);
    }
    if (type is ClassMirror && !(type as ClassMirror).isAbstract) {
      return new SchemaProperty._internal(property, type, repeated, meta, parent, fields: fields, name: name);
    }
    throw new ApiConfigError('${property.simpleName}: Invalid type.');
  }

  ApiConfigSchemaProperty._internal(VariableMirror property, bool this._repeated, this._meta, ApiConfig parent) {
    _propertyName = MirrorSystem.getName(property.simpleName);

    if (_meta != null) {
      _required = _meta.required;
      _defaultValue = _meta.defaultValue;
    }
  }

  Map get typeDescriptor {
    var property = {};
    if (_apiType != null) {
      property['type'] = _apiType;
    }
    if (_apiFormat != null) {
      property['format'] = _apiFormat;
    }
    return property;
  }

  Map get descriptor {
    var property = typeDescriptor;

    if (_meta != null && _meta.description != null) {
      property['description'] = _meta.description;
    }

    if (_repeated) {
      property = {
        'type': 'array',
        'items': property
      };
    }

    if (_required) {
      property['required'] = true;
    }
    if (_defaultValue != null) {
      property['default'] = toResponse(_defaultValue);
    }
    return property;
  }

  bool get isSimple => true;

  Map get parameter {
    var parameter = {};
    if (!isSimple) { return null; }
    parameter['type'] = _apiParameterType;
    if (_meta != null && _meta.description != null) {
      parameter['description'] = _meta.description;
    }
    if (_defaultValue != null) {
      parameter['default'] = toResponse(_defaultValue);
    }
    return parameter;
  }

  _singleRequestValue(value) {
    return value;
  }

  fromRequest(value) {
    var response = null;
    if (value == null) {
      return null;
    }
    if (_repeated) {
      if (value is! List) {
        throw new BadRequestError('Expected repeated value to be List');
      }
      response = [];
      value.forEach((v) => response.add(_singleRequestValue(v)));
    } else {
      response = _singleRequestValue(value);
    }
    return response;
  }

  _singleResponseValue(value) {
    return value;
  }

  toResponse(value) {
    if (value == null) {
      return null;
    }
    if (_repeated) {
      if (value is! List) {
        throw new EndpointsError(500, 'Bad response', 'Invalid response');
      }
      var response = [];
      value.forEach((v) => response.add(_singleResponseValue(v)));
      return response;
    }

    return _singleResponseValue(value);
  }
}

class IntegerProperty extends ApiConfigSchemaProperty {

  int _minValue;
  int _maxValue;

  IntegerProperty._internal(property, repeated, meta, parent): super._internal(property, repeated, meta, parent) {
    if (_meta != null) {
      _apiFormat = _meta.variant;
      _minValue = _meta.minValue;
      _maxValue = _meta.maxValue;
    }
    if (_apiFormat == null || _apiFormat == '') { _apiFormat = 'int32'; }
    if (_apiFormat == 'int32' || _apiFormat == 'uint32') {
      _apiType = 'integer';
    } else if (_apiFormat == 'int64' || _apiFormat == 'uint64'){
      _apiType = 'string';
    } else {
      throw new ApiConfigError('${_propertyName}: Invalid integer variant.');
    }
    _apiParameterType = _apiFormat;
  }

  _singleResponseValue(value) {
    if (value != null && _apiType == 'string') {
      return value.toString();
    }
    return value;
  }

  _singleRequestValue(value) {
    if (value == null) { return value; }
    if (value is! int) {
      try {
        value = int.parse(value);
      } on FormatException catch (e) {
        throw new BadRequestError('Invalid integer format: $e');
      }
    }
    if (_minValue != null && value < _minValue) {
      throw new BadRequestError('$_propertyName needs to be >= $_minValue');
    }
    if (_maxValue != null && value > _maxValue) {
      throw new BadRequestError('$_propertyName needs to be <= $_maxValue');
    }
    return value;
  }

  Map get parameter {
    var parameter = super.parameter;

    if (_minValue != null) {
      parameter['minValue'] = _singleResponseValue(_minValue);
    }
    if (_maxValue != null) {
      parameter['maxValue'] = _singleResponseValue(_maxValue);
    }

    return parameter;
  }
}

class DoubleProperty extends ApiConfigSchemaProperty {

  DoubleProperty._internal(property, repeated, meta, parent): super._internal(property, repeated, meta, parent) {
    _apiType = 'number';
    if (_meta != null) {
      _apiFormat = _meta.variant;
    }
    if (_apiFormat == null || _apiFormat == '') {
      _apiFormat = 'double';
    }
    if (_apiFormat != 'double' && _apiFormat != 'float') {
      throw new ApiConfigError('${_propertyName}: Invalid double variant.');
    }
    _apiParameterType = _apiFormat;
  }

  _singleRequestValue(value) {
    if (value == null || value is num) { return value; }
    try {
      return double.parse(value);
    } on FormatException catch (e) {
      throw new BadRequestError('Invalid integer format: $e');
    }
  }
}

class StringProperty extends ApiConfigSchemaProperty {

  StringProperty._internal(property, repeated, meta, parent): super._internal(property, repeated, meta, parent) {
    _apiType = 'string';
    _apiFormat = null;
    _apiParameterType = _apiType;
  }
}

class EnumProperty extends ApiConfigSchemaProperty {

  EnumProperty._internal(property, repeated, meta, parent): super._internal(property, repeated, meta, parent) {
    _apiType = 'string';
    _apiFormat = null;
    _apiParameterType = _apiType;
  }

  Map get parameter {
    var parameter = super.parameter;

    parameter['enum'] = {};
    _meta.values.forEach((value, description) {
      parameter['enum'][value] = {
        'backendValue': value,
        'description': description
      };
    });

    return parameter;
  }

  _singleRequestValue(value) {
    if (value == null || _meta.values.containsKey(value)) { return value; }
    throw new BadRequestError('Value is not a valid enum value');
  }
}

class BooleanProperty extends ApiConfigSchemaProperty {

  BooleanProperty._internal(property, repeated, meta, parent): super._internal(property, repeated, meta, parent) {
    _apiType = 'boolean';
    _apiFormat = null;
    _apiParameterType = _apiType;
  }

  _singleRequestValue(value) {
    if (value == null || value is bool) { return value; }
    throw new BadRequestError('Invalid boolean value');
  }
}

class DateTimeProperty extends ApiConfigSchemaProperty {

  DateTimeProperty._internal(property, repeated, meta, parent): super._internal(property, repeated, meta, parent) {
    _apiType = 'string';
    _apiFormat = 'date-time';
    _apiParameterType = _apiType;
  }

  _singleResponseValue(value) {
    if (value == null) { return null; }
    return (value as DateTime).toUtc().toIso8601String();
  }

  _singleRequestValue(value) {
    if (value == null) { return null; }
    try {
      return DateTime.parse(value);
    } on FormatException catch (e) {
      throw new BadRequestError('Invalid date format: $e');
    }
  }
}

class SchemaProperty extends ApiConfigSchemaProperty {

  ApiConfigSchema _ref;

  SchemaProperty._internal(property, ClassMirror type, repeated, meta, parent, {List<String> fields, String name}): super._internal(property, repeated, meta, parent) {
    _ref = new ApiConfigSchema(type, parent, fields: fields, name: name);

    _apiType = null;
    _apiFormat = null;
    _apiParameterType = null;
  }

  _singleResponseValue(value) {
    if (value == null) { return null; }
    return _ref.toResponse(value);
  }

  _singleRequestValue(value) {
    if (value == null) { return null; }
    if (value is! Map) {
      throw new BadRequestError('Invalid request message');
    }
    return _ref.fromRequest(value);
  }

  Map get typeDescriptor => {'\$ref': _ref.schemaName};

  bool get isSimple => false;
}