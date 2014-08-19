part of endpoints.api_config;

class ApiConfigSchemaProperty {
  String _propertyName;
  TypeMirror _type;
  bool _repeated = false;
  String _apiType;
  String _apiFormat;
  ApiProperty _meta;

  factory ApiConfigSchemaProperty(VariableMirror property, ApiConfig parent) {
    var type = property.type;
    if(type.simpleName == #dynamic) {
      throw new ApiConfigError('${property.simpleName}: Property needs to have a type defined.');
    }
    if (type.isSubtypeOf(reflectType(List))) {
      var types = type.typeArguments;
      if (types.length != 1 || types[0].simpleName == #dynamic) {
        throw new ApiConfigError('${property.simpleName}: List property must specify exactly one type parameter');
      }
      type = types[0];
    }
    switch (type.reflectedType) {
      case int: return new IntegerProperty._internal(property, parent);
      case double: return new DoubleProperty._internal(property, parent);
      case bool: return new BooleanProperty._internal(property, parent);
      case String: return new StringProperty._internal(property, parent);
      case DateTime: return new DateTimeProperty._internal(property, parent);
    }
    if (type is ClassMirror && !(type as ClassMirror).isAbstract) {
      return new SchemaProperty._internal(property, parent);
    }
    throw new ApiConfigError('${property.simpleName}: Invalid type.');
  }

  ApiConfigSchemaProperty._internal(VariableMirror property, ApiConfig parent) {
    _propertyName = MirrorSystem.getName(property.simpleName);
    _type = property.type;

    if (_type.isSubtypeOf(reflectType(List))) {
      _repeated = true;
      var types = _type.typeArguments;
      if (types.length != 1 || types[0].simpleName == #dynamic) {
        throw new ApiConfigError('${_propertyName}: List property must specify exactly one type parameter');
      }
      _type = types[0];
    }

    var metas = property.metadata.where((m) => m.reflectee.runtimeType == ApiProperty);
    if (metas.length > 0) {
      _meta = metas.first.reflectee;
    }

    // TODO: extra information from _meta
    // TODO: add default, required, min/max values, enum
  }

  String get propertyName => _propertyName;

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

    if (_repeated) {
      return {
        'type': 'array',
        'items': property
      };
    }
    return property;
  }

  bool get isSimple => true;

  Map get parameter {
    var parameter = {};
    if (!isSimple) { return null; }
    if (_type.reflectedType == int || _type.reflectedType == double) {
      parameter['type'] = _apiFormat;
    } else {
      parameter['type'] = _apiType;
    }

    // TODO: extra information from _meta
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

  IntegerProperty._internal(property, parent): super._internal(property, parent) {
    if (_meta != null) {
      _apiFormat = _meta.variant;
    }
    if (_apiFormat == null || _apiFormat == '') { _apiFormat = 'int32'; }
    if (_apiFormat == 'int32' || _apiFormat == 'uint32') {
      _apiType = 'integer';
    } else if (_apiFormat == 'int64' || _apiFormat == 'uint64'){
      _apiType = 'string';
    } else {
      throw new ApiConfigError('${_propertyName}: Invalid integer variant.');
    }
  }

  _singleResponseValue(value) {
    if (value != null && _apiType == 'string') {
      return value.toString();
    }
    return value;
  }

  _singleRequestValue(value) {
    if (value == null || value is int) { return value; }
    try {
      return int.parse(value);
    } on FormatException catch (e) {
      throw new BadRequestError('Invalid integer format: $e');
    }
  }
}

class DoubleProperty extends ApiConfigSchemaProperty {

  DoubleProperty._internal(property, parent): super._internal(property, parent) {
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

  StringProperty._internal(property, parent): super._internal(property, parent) {
    _apiType = 'string';
    _apiFormat = null;
  }
}

class BooleanProperty extends ApiConfigSchemaProperty {

  BooleanProperty._internal(property, parent): super._internal(property, parent) {
    _apiType = 'boolean';
    _apiFormat = null;
  }

  _singleRequestValue(value) {
    if (value == null || value is bool) { return value; }
    throw new BadRequestError('Invalid boolean value');
  }
}

class DateTimeProperty extends ApiConfigSchemaProperty {

  DateTimeProperty._internal(property, parent): super._internal(property, parent) {
    _apiType = 'string';
    _apiFormat = 'date-time';
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

  SchemaProperty._internal(property, parent): super._internal(property, parent) {
    _ref = parent._getSchema(MirrorSystem.getName(_type.simpleName));
    if (_ref == null) {
      _ref = new ApiConfigSchema(_type, parent);
    }
    _apiType = null;
    _apiFormat = null;
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