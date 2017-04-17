// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfigSchemaProperty {
  final String name;
  final String description;
  final bool required;

  final String defaultValue;
  bool get hasDefault => (defaultValue != null);

  final String _apiType;
  final String _apiFormat;

  ApiConfigSchemaProperty(this.name, this.description, this.required,
      this.defaultValue, this._apiType, this._apiFormat);

  discovery.JsonSchema get typeAsDiscovery {
    return new discovery.JsonSchema()
      ..type = _apiType
      ..format = _apiFormat;
  }

  discovery.JsonSchema get asDiscovery {
    var property = typeAsDiscovery;
    if (required) {
      property.required = true;
    }
    if (description != null) {
      property.description = description;
    }
    if (defaultValue != null) {
      property.default_ = defaultValue;
    }
    return property;
  }

  bool get isSimple => true;

  _singleRequestValue(value) {
    return value;
  }

  fromRequest(value) {
    if (value == null) return null;
    return _singleRequestValue(value);
  }

  _singleResponseValue(value) {
    return value;
  }

  toResponse(value) {
    if (value == null) return null;
    return _singleResponseValue(value);
  }
}

class IntegerProperty extends ApiConfigSchemaProperty {
  final int minValue;
  final int maxValue;

  IntegerProperty(
      String name,
      String description,
      bool required,
      int defaultValue,
      String apiType,
      String apiFormat,
      this.minValue,
      this.maxValue)
      : super(
            name,
            description,
            required,
            defaultValue != null ? defaultValue.toString() : null,
            apiType,
            apiFormat);

  _singleResponseValue(value) {
    assert(value != null);
    if (value is! int) {
      throw new InternalServerError(
          'Trying to return non-integer: \'$value\' in integer property');
    }
    if (minValue != null && value < minValue) {
      throw new InternalServerError(
          'Return value \'$value\' smaller than minimum value \'$minValue\'');
    }
    if (maxValue != null && value > maxValue) {
      throw new InternalServerError(
          'Return value \'$value\' larger than maximum value \'$maxValue\'');
    }
    if (_apiFormat == 'int32' && value == value.toSigned(32) ||
        _apiFormat == 'uint32' && value == value.toUnsigned(32)) {
      return value;
    }
    if (_apiFormat == 'int64' && value == value.toSigned(64) ||
        _apiFormat == 'uint64' && value == value.toUnsigned(64)) {
      assert(_apiType == 'string');
      return value.toString();
    }
    throw new InternalServerError(
        'Integer return value: \'$value\' not within the \'$_apiFormat\' '
        'property range.');
  }

  _singleRequestValue(value) {
    assert(value != null);
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

  discovery.JsonSchema get asDiscovery {
    var property = super.asDiscovery;
    if (minValue != null) {
      property.minimum = minValue.toString();
    }
    if (maxValue != null) {
      property.maximum = maxValue.toString();
    }
    return property;
  }
}

class DoubleProperty extends ApiConfigSchemaProperty {
  DoubleProperty(String name, String description, bool required,
      double defaultValue, String apiFormat)
      : super(
            name,
            description,
            required,
            defaultValue != null ? defaultValue.toString() : null,
            'number',
            apiFormat);

  _singleRequestValue(value) {
    assert(value != null);
    if (value is num) {
      return value;
    }
    try {
      return double.parse(value);
    } on FormatException catch (e) {
      throw new BadRequestError('Invalid double format: $e');
    }
  }

  _singleResponseValue(value) {
    if (_apiFormat == 'float' &&
        (value < SMALLEST_FLOAT || value > LARGEST_FLOAT)) {
      throw new InternalServerError(
          'Result \'$value\' not in single precision \'float\' range: '
          '[$SMALLEST_FLOAT, $LARGEST_FLOAT].');
    }
    return value;
  }
}

class StringProperty extends ApiConfigSchemaProperty {
  StringProperty(
      String name, String description, bool required, String defaultValue)
      : super(name, description, required, defaultValue, 'string', null);
}

class EnumProperty extends ApiConfigSchemaProperty {
  final Map<String, String> _values;

  EnumProperty(String name, String description, bool required,
      String defaultValue, this._values)
      : super(name, description, required, defaultValue, 'string', null);

  discovery.JsonSchema get asDiscovery {
    return super.asDiscovery
      ..enum_ = _values.keys.toList()
      ..enumDescriptions = _values.values.toList();
  }

  _singleRequestValue(value) {
    assert(value != null);
    if (_values.containsKey(value)) {
      return value;
    }
    throw new BadRequestError('Value is not a valid enum value');
  }
}

class BooleanProperty extends ApiConfigSchemaProperty {
  BooleanProperty(
      String name, String description, bool required, bool defaultValue)
      : super(
            name,
            description,
            required,
            defaultValue != null ? defaultValue.toString() : null,
            'boolean',
            null);

  _singleRequestValue(value) {
    assert(value != null);
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      } else if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    throw new BadRequestError('Invalid boolean value: $value');
  }
}

class DateTimeProperty extends ApiConfigSchemaProperty {
  DateTimeProperty(
      String name, String description, bool required, DateTime defaultValue)
      : super(
            name,
            description,
            required,
            defaultValue != null
                ? defaultValue.toUtc().toIso8601String()
                : null,
            'string',
            'date-time');

  _singleResponseValue(value) {
    assert(value != null);
    return (value as DateTime).toUtc().toIso8601String();
  }

  _singleRequestValue(value) {
    assert(value != null);
    try {
      return DateTime.parse(value);
    } on FormatException catch (e) {
      throw new BadRequestError('Invalid date format: $e');
    }
  }
}

class SchemaProperty extends ApiConfigSchemaProperty {
  final ApiConfigSchema _ref;

  SchemaProperty(String name, String description, bool required, this._ref)
      : super(name, description, required, null, null, null);

  _singleResponseValue(value) {
    assert(value != null);
    return _ref.toResponse(value);
  }

  _singleRequestValue(value) {
    assert(value != null);
    if (value is! Map && value is! MediaMessage) {
      throw new BadRequestError('Invalid request message');
    }
    return _ref.fromRequest(value);
  }

  discovery.JsonSchema get typeAsDiscovery =>
      new discovery.JsonSchema()..P_ref = _ref.schemaName;

  bool get isSimple => false;
}

class ListProperty extends ApiConfigSchemaProperty {
  final ApiConfigSchemaProperty _itemsProperty;

  ListProperty(
      String name, String description, bool required, this._itemsProperty)
      : super(name, description, required, null, null, null);

  discovery.JsonSchema get typeAsDiscovery =>
      new discovery.JsonSchema()..type = 'array';

  discovery.JsonSchema get asDiscovery =>
      super.asDiscovery..items = _itemsProperty.asDiscovery;

  _singleResponseValue(listObject) {
    if (listObject is! List) {
      throw new BadRequestError('Invalid property, should be of type \'List\'');
    }
    return (listObject as List).map(_itemsProperty.toResponse).toList();
  }

  _singleRequestValue(encodedList) {
    if (encodedList is! List) {
      throw new BadRequestError('Invalid list request value');
    }
    return (encodedList as List).map(_itemsProperty.fromRequest).toList();
  }
}

class MapProperty extends ApiConfigSchemaProperty {
  final ApiConfigSchemaProperty _additionalProperty;
  final dynamic serializer;

  MapProperty(String name, String description, bool required,
      this._additionalProperty, this.serializer)
      : super(name, description, required, null, null, null);

  discovery.JsonSchema get typeAsDiscovery =>
      new discovery.JsonSchema()..type = 'object';

  discovery.JsonSchema get asDiscovery =>
      super.asDiscovery..additionalProperties = _additionalProperty.asDiscovery;

  _singleResponseValue(mapObject) {
    if (mapObject is! Map) {
      throw new BadRequestError('Invalid property, should be of type \'Map\'');
    }

    if (serializer != null) {
      return serializer(mapObject);
    }

    var result = {};
    (mapObject as Map).forEach((String key, object) {
      result[key] = _additionalProperty.toResponse(object);
    });
    return result;
  }

  _singleRequestValue(encodedMap) {
    if (encodedMap is! Map) {
      throw new BadRequestError('Invalid map request value');
    }
    // Map from String to the type of the additional property.
    var result = {};
    (encodedMap as Map).forEach((String key, encodedObject) {
      result[key] = _additionalProperty.fromRequest(encodedObject);
    });
    return result;
  }
}
