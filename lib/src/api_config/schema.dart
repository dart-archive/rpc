part of endpoints.api_config;

String _capitalize(String string) => "${string.substring(0,1).toUpperCase()}${string.substring(1)}";

class ApiConfigSchema {
  ClassMirror _schemaClass;
  String _schemaName;
  String _autoName;
  Map<Symbol, ApiConfigSchemaProperty> _properties = {};

  factory ApiConfigSchema(ClassMirror schemaClass, ApiConfig parent, {List<String> fields: const [], String name}) {
    var autoName = MirrorSystem.getName(schemaClass.simpleName);

    if (schemaClass.isSubtypeOf(reflectType(ListResponse)) || schemaClass.isSubtypeOf(reflectType(ListRequest))) {
      var types = schemaClass.typeArguments;
      if (types.length != 1 || types[0].simpleName == #dynamic) {
        throw new ApiConfigError('${autoName}: ListResponse/ListRequest must specify exactly one type parameter');
      }
      var type = types[0];
      autoName = MirrorSystem.getName(type.simpleName);
    }

    // TODO: better way to create a SchemaName?
    if (fields != null && fields.length > 0) {
      fields = fields.toList();
      fields.sort();
      autoName = autoName + fields.map((field) => _capitalize(field)).join('');
    } else {
      fields = [];
    }

    var schemaName = autoName;
    if (name != null && name != '') {
      schemaName = name;
    }

    if (schemaClass.isSubtypeOf(reflectType(ListResponse))) {
      autoName += "List";
      schemaName += "List";
    }
    if (schemaClass.isSubtypeOf(reflectType(ListRequest))) {
      autoName += "ListRequest";
      schemaName += "ListRequest";
    }

    var schema = parent._getSchema(schemaName);
    if (schema == null) {
      if (schemaClass.isSubtypeOf(reflectType(ListResponse))) {
        schema = new ListResponseSchema._internal(schemaClass, schemaName, autoName, fields, name, parent);
      } else {
        schema = new ApiConfigSchema._internal(schemaClass, schemaName, autoName, fields, name, parent);
      }
    } else {
      if (schema._autoName != autoName) {
        throw new ApiConfigError('${schemaName} can\'t have two different sets of properties');
      }
    }

    return schema;
  }

  ApiConfigSchema._internal(this._schemaClass, this._schemaName, this._autoName, List<String> fields, String name, ApiConfig parent) {
    var methods = _schemaClass.declarations.values.where(
      (mm) => mm is MethodMirror && mm.isConstructor
    );
    if (!methods.isEmpty && methods.where((mm) => mm.simpleName == _schemaClass.simpleName).isEmpty) {
      throw new ApiConfigError('${schemaName} needs to have an unnamed constructor');
    }

    parent._addSchema(_schemaName, this);

    _createProperties(fields, name, parent);
  }

  void _createProperties(List<String> fields, String name, ApiConfig parent) {
    var properties = _schemaClass.declarations.values.where(
      (dm) => dm is VariableMirror &&
              !dm.isConst && !dm.isFinal && !dm.isPrivate && !dm.isStatic
    );

    if (fields != null && fields.length > 0) {
      var symbolFields = fields.map((field) => new Symbol(field)).toList();
      properties = properties.where(
        (VariableMirror vm) => symbolFields.contains(vm.simpleName)
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

class ListResponseSchema extends ApiConfigSchema {

  ListResponseSchema._internal(schemaClass, schemaName, autoName, fields, name, parent) :
    super._internal(schemaClass, schemaName, autoName, fields, name, parent);

  void _createProperties(List<String> fields, String name, ApiConfig parent) {
    // TODO: call super for other properties if ListResponse is extended

    VariableMirror items = _schemaClass.declarations.values.firstWhere(
      (dm) => dm is VariableMirror && dm.simpleName == #items
    );

    var prop = new ApiConfigSchemaProperty(items, parent, fields: fields, name: name);
    if (prop != null) {
      _properties[#items] = prop;
    }
  }
}