// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfigSchemaProperty {
  final String name;
  final String description;
  final bool repeated;
  final bool required;

  final dynamic defaultValue;
  bool get hasDefault => (defaultValue != null);

  final String _apiType;
  final String _apiFormat;
  final String _apiParameterType;

  ApiConfigSchemaProperty(this.name, this.description, this.required,
                          this.defaultValue, this.repeated, this._apiType,
                          this._apiFormat, this._apiParameterType);

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
    if (description != null) {
      property['description'] = description;
    }
    if (repeated) {
      property = {
        'type': 'array',
        'items': property
      };
    }
    if (required) {
      property['required'] = true;
    }
    if (defaultValue != null) {
      property['default'] = toResponse(defaultValue);
    }
    return property;
  }

  bool get isSimple => true;

  _singleRequestValue(value) {
    return value;
  }

  fromRequest(value) {
    var response = null;
    if (value == null) {
      return null;
    }
    if (repeated) {
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
    if (repeated) {
      if (value is! List) {
        throw new RpcError(500, 'Bad response', 'Invalid response');
      }
      var response = [];
      value.forEach((v) => response.add(_singleResponseValue(v)));
      return response;
    }
    return _singleResponseValue(value);
  }
}

class IntegerProperty extends ApiConfigSchemaProperty {

  final int minValue;
  final int maxValue;

  IntegerProperty(String name, String description, bool required,
                  int defaultValue, bool repeated, String apiType,
                  String apiFormat, this.minValue, this.maxValue)
      : super(name, description, required, defaultValue, repeated,
              apiType, apiFormat, apiFormat);

  _singleResponseValue(value) {
    if (value != null && _apiType == 'string') {
      return value.toString();
    }
    return value;
  }

  _singleRequestValue(value) {
    if (value == null) return value;
    if (value is! int) {
      try {
        value = int.parse(value);
      } on FormatException catch (e) {
        throw new BadRequestError('Invalid integer format: $e');
      }
    }
    if (minValue != null && value < minValue) {
      throw new BadRequestError('$name needs to be >= $minValue');
    }
    if (maxValue != null && value > maxValue) {
      throw new BadRequestError('$name needs to be <= $maxValue');
    }
    return value;
  }

  Map get descriptor {
    var descriptor = super.descriptor;

    if (minValue != null) {
      descriptor['minimum'] = _singleResponseValue(minValue);
    }
    if (maxValue != null) {
      descriptor['maximum'] = _singleResponseValue(maxValue);
    }

    return descriptor;
  }
}

class DoubleProperty extends ApiConfigSchemaProperty {

  DoubleProperty(String name, String description, bool required,
                 double defaultValue, bool repeated, String apiFormat)
      : super(name, description, required, defaultValue, repeated, 'number',
              apiFormat, apiFormat);

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

  StringProperty(String name, String description, bool required,
                 String defaultValue, bool repeated)
      : super(name, description, required, defaultValue, repeated, 'string',
          null, 'string');
}

class EnumProperty extends ApiConfigSchemaProperty {

  final Map<String, String> _values;

  EnumProperty(String name, String description, bool required,
               String defaultValue, this._values)
      : super(name, description, required, defaultValue, false, 'string', null,
              'string');

  Map get descriptor {
    var descriptor = super.descriptor;
    descriptor['enum'] = [];
    descriptor['enumDescriptions'] = [];
    _values.forEach((value, description) {
      descriptor['enum'].add(value);
      descriptor['enumDescriptions'].add(description);
    });

    return descriptor;
  }

  _singleRequestValue(value) {
    if (value == null || _values.containsKey(value)) { return value; }
    throw new BadRequestError('Value is not a valid enum value');
  }
}

class BooleanProperty extends ApiConfigSchemaProperty {

  BooleanProperty(String name, String description, bool required,
                  bool defaultValue, bool repeated)
      : super(name, description, required, defaultValue, repeated, 'boolean',
              null, 'boolean');

  _singleRequestValue(value) {
    if (value == null || value is bool) { return value; }
    throw new BadRequestError('Invalid boolean value');
  }
}

class DateTimeProperty extends ApiConfigSchemaProperty {

  DateTimeProperty(String name, String description, bool required,
                   DateTime defaultValue, bool repeated)
      : super(name, description, required, defaultValue, repeated, 'string',
              'date-time', 'string');

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

  final ApiConfigSchema _ref;

  SchemaProperty(String name, String description, bool required,
                 dynamic defaultValue, bool repeated, this._ref)
      : super(name, description, required, null, repeated, null, null, null);

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
