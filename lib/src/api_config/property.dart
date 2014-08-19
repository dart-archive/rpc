part of endpoints.api_config;

const Map _typeMap = const {
  int: const {
   '': 'integer',
   'int32': 'integer',
   'uint32': 'integer',
   'int64': 'string',
   'uint64': 'string'
  },
  String: const {
    '': 'string'
  },
  double: const {
    '': 'number',
    'double': 'number',
    'float': 'number'
  },
  bool: const {
    '': 'boolean'
  },
  DateTime: const {
    '': 'string'
  }
};

const Map _formatMap = const {
  int: const {
   '': 'int32',
   'int32': 'int32',
   'uint32': 'uint32',
   'int64': 'int64',
   'uint64': 'uint64'
  },
  double: const {
    '': 'double',
    'double': 'double',
    'float': 'float'
  },
  DateTime: const {
    '': 'date-time'
  }
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
      if (types.length != 1 || types[0].simpleName == #dynamic) {
        throw new ApiConfigError('${schemaName}.${_propertyName}: List property must specify exactly one type parameter');
      }
      _type = types[0];
    }

    var metas = _property.metadata.where((m) => m.reflectee.runtimeType == ApiProperty);
    if (metas.length > 0) {
      _meta = metas.first.reflectee;
    }

    var variant = '';
    var tmp = null;
    if (_meta != null && _meta.variant != null) {
      variant = _meta.variant;
    }
    tmp = _typeMap[_type.reflectedType];
    if (tmp != null) {
      _apiType = tmp[variant];
      tmp = _formatMap[_type.reflectedType];
      if (tmp != null) {
        _apiFormat = tmp[variant];
      }
    }

    if (_apiType == null) {
      if (_type is ClassMirror && !(_type as ClassMirror).isAbstract) {
        _ref = parent._getSchema(MirrorSystem.getName(_type.simpleName));
        if (_ref == null) {
          _ref = new ApiConfigSchema(_type, parent);
        }
      }
    }

    // TODO: extra information from _meta
    // TODO: add default, required, min/max values, enum

    if (_ref == null && _apiType == null) {
      throw new ApiConfigError('${schemaName}.${_propertyName}: Invalid type.');
    }
  }

  String get propertyName => _propertyName;

  Map get descriptor {
    var property = {};
    if (_apiType != null) {
      property['type'] = _apiType;
    }
    if (_apiFormat != null) {
      property['format'] = _apiFormat;
    }
    if (_ref != null) {
      property['\$ref'] = _ref.schemaName;
    }

    if (_repeated) {
      return {
        'type': 'array',
        'items': property
      };
    }
    return property;
  }

  Map get parameter {
    var parameter = {};
    if (_ref != null) {
      return null;
    }
    if (_type.reflectedType == int || _type.reflectedType == double) {
      parameter['type'] = _apiFormat;
    } else {
      parameter['type'] = _apiType;
    }

    // TODO: extra information from _meta
    return parameter;
  }

  _singleRequestValue(value) {
    if (value == null) {
      return null;
    }
    if (_ref != null) {
      if (value is! Map) {
        throw new BadRequestError('Invalid request message');
      }
      return _ref.fromRequest(value);
    }
    if (_type.reflectedType == String) {
      return value;
    }
    if (_type.reflectedType == int) {
      if (value is int) {
        return value;
      }
      var v;
      try {
        v = int.parse(value);
      } on FormatException catch (e) {
        throw new BadRequestError('Invalid integer format: $e');
      }
      return v;
    }
    if (_type.reflectedType == double) {
      if (value is num) {
        return value;
      }
      var v;
      try {
        v = double.parse(value);
      } on FormatException catch (e) {
        throw new BadRequestError('Invalid number format: $e');
      }
      return v;
    }
    if (_type.reflectedType == bool) {
      if (value is bool) {
        return value;
      }
      throw new BadRequestError('Invalid boolean value');
    }
    if (_type.reflectedType == DateTime) {
      var v;
      try {
        v = DateTime.parse(value);
      } on FormatException catch (e) {
        throw new BadRequestError('Invalid date format: $e');
      }
      return v;
    }
    return null;
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
    if (_ref != null) {
      return _ref.toResponse(value);
    }
    if ([String, double, bool].contains(_type.reflectedType)) {
      return value;
    }
    if (_type.reflectedType == int) {
      if (_apiType == 'string') {
        return value.toString();
      }
      return value;
    }
    if (_type.reflectedType == DateTime) {
      return (value as DateTime).toUtc().toIso8601String();
    }
    return null;
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
