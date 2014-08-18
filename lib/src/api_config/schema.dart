part of endpoints.api_config;

class ApiConfigSchema {
  ClassMirror _schemaClass;
  String _schemaName;
  Map<Symbol, ApiConfigSchemaProperty> _properties = {};

  ApiConfigSchema(this._schemaClass, ApiConfig parent) {
    _schemaName = MirrorSystem.getName(_schemaClass.simpleName);
    parent._addSchema(_schemaName, this);

    var declarations = _schemaClass.declarations;

    var properties = _schemaClass.declarations.values.where(
      (dm) => dm is VariableMirror &&
              !dm.isConst && !dm.isFinal && !dm.isPrivate && !dm.isStatic
    );

    properties.forEach((VariableMirror vm) {
      _properties[vm.simpleName] = new ApiConfigSchemaProperty(vm, _schemaName, parent);
    });
  }

  bool hasSimpleProperty(List<String> path) {
    var property = _properties[new Symbol(path[0])];
    if (property == null) {
      return false;
    }
    if (path.length == 1) {
      return (property._ref == null);
    }
    if (property._ref == null) {
      return false;
    }
    path.removeAt(0);
    return property._ref.hasSimpleProperty(path);
  }

  Map getParameter(List<String> path, {bool repeated: false}) {
    var property = _properties[new Symbol(path[0])];
    if (path.length == 1) {
      var param = property.parameter;
      if (param != null) {
        param['repeated'] = repeated || property._repeated;
      }
      return param;
    }
    if (property._ref == null) {
      return null;
    }
    path.removeAt(0);
    return property._ref.getParameter(path, repeated: repeated || property._repeated);
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

  Map<String, Map> getParameters({String prefix: '', bool repeated: false}) {
    var parameters = {};
    _properties.values.forEach((property) {
      if (property._ref == null) {
        parameters['$prefix${property.propertyName}'] = property.parameter;
        if (repeated || property._repeated) {
          parameters['$prefix${property.propertyName}']['repeated'] = true;
        }
      } else {
        parameters.addAll(property._ref.getParameters(
          prefix: '$prefix${property.propertyName}.',
          repeated: repeated || property._repeated
        ));
      }
    });
    return parameters;
  }

  ApiMessage fromRequest(Map request) {
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
    return api.reflectee;
  }

  Map toResponse(ApiMessage message) {
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
