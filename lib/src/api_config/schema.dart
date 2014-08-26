part of endpoints.api_config;

class ApiConfigSchema {
  ClassMirror _schemaClass;
  String _schemaName;
  List<Symbol> _fields;
  Map<Symbol, ApiConfigSchemaProperty> _properties = {};

  factory ApiConfigSchema(ClassMirror schemaClass, ApiConfig parent, {List<String> fields: const []}) {
    var schemaName = MirrorSystem.getName(schemaClass.simpleName);
    List<Symbol> symbolFields;

    // TODO: better way to create a SchemaName?
    if (fields != null && fields.length > 0) {
      fields = fields.toList();
      fields.sort();
      schemaName = schemaName + '_' + fields.join('_');
      symbolFields = fields.map((field) => new Symbol(field));
    } else {
      symbolFields = [];
    }

    var schema = parent._getSchema(schemaName);
    if (schema == null) {
      schema = new ApiConfigSchema._internal(schemaClass, schemaName, symbolFields, parent);
    }

    return schema;
  }

  ApiConfigSchema._internal(this._schemaClass, this._schemaName, this._fields, ApiConfig parent) {
    var methods = _schemaClass.declarations.values.where(
      (mm) => mm is MethodMirror && mm.isConstructor
    );
    if (!methods.isEmpty && methods.where((mm) => mm.simpleName == _schemaClass.simpleName).isEmpty) {
      throw new ApiConfigError('${schemaName} needs to have an unnamed constructor');
    }

    parent._addSchema(_schemaName, this);

    var declarations = _schemaClass.declarations;

    var properties = _schemaClass.declarations.values.where(
      (dm) => dm is VariableMirror &&
              !dm.isConst && !dm.isFinal && !dm.isPrivate && !dm.isStatic
    );

    if (_fields.length > 0) {
      properties = properties.where(
        (VariableMirror vm) => _fields.contains(vm.simpleName)
      );
    }
    properties.forEach((VariableMirror vm) {
      var prop = new ApiConfigSchemaProperty(vm, parent);
      if (prop != null) {
        _properties[vm.simpleName] = prop;
      }
    });
  }

  bool get hasProperties => !_properties.isEmpty;

  bool hasSimpleProperty(List<String> path) {
    var property = _properties[new Symbol(path[0])];
    if (property == null) {
      return false;
    }
    if (path.length == 1) {
      return (property.isSimple);
    }
    if (property is! SchemaProperty) {
      return false;
    }
    path.removeAt(0);
    return property._ref.hasSimpleProperty(path);
  }

  Map getParameter(List<String> path, {bool repeated: false, bool required: true}) {
    var property = _properties[new Symbol(path[0])];
    if (path.length == 1) {
      var param = property.parameter;
      if (param != null) {
        param['repeated'] = repeated || property.repeated;
        param['required'] = required && property.required;
      }
      return param;
    }
    if (property is! SchemaProperty) {
      return null;
    }
    path.removeAt(0);
    return property._ref.getParameter(
      path,
      repeated: repeated || property.repeated,
      required: required && property.required
    );
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

  Map<String, Map> getParameters({String prefix: '', bool repeated: false, bool required: true}) {
    var parameters = {};
    _properties.values.forEach((property) {
      if (property is! SchemaProperty) {
        parameters['$prefix${property.propertyName}'] = property.parameter;
        if (repeated || property.repeated) {
          parameters['$prefix${property.propertyName}']['repeated'] = true;
        }
        if (required && property.required) {
          parameters['$prefix${property.propertyName}']['required'] = true;
        }
      } else {
        parameters.addAll(property._ref.getParameters(
          prefix: '$prefix${property.propertyName}.',
          repeated: repeated || property.repeated,
          required: required && property.required
        ));
      }
    });
    return parameters;
  }

  fromRequest(Map request) {
    InstanceMirror api = _schemaClass.newInstance(new Symbol(''), []);
    request.forEach((name, value) {
      if (value != null) {
        var sym = new Symbol(name);
        var prop = _properties[sym];
        if (prop != null) {
          api.setField(sym, prop.fromRequest(value));
        }
      }
    });
    // Check required/default
    _properties.forEach((sym, prop) {
      if (prop.required || prop.hasDefault) {
        var value = api.getField(sym);
        if (value.hasReflectee) {
          value = value.reflectee;
        }
        if (value == null) {
          if (prop.hasDefault) {
            api.setField(sym, prop.defaultValue);
            return;
          }
          if (prop.required) {
            throw new BadRequestError('Required field ${prop.propertyName} is missing');
          }
        }
      }
    });
    return api.reflectee;
  }

  Map toResponse(message) {
    var response = {};
    InstanceMirror mirror = reflect(message);
    _properties.forEach((sym, prop) {
      var value = prop.toResponse(mirror.getField(sym).reflectee);
      if (value != null) {
        response[prop.propertyName] = value;
      }
    });
    return response;
  }
}
