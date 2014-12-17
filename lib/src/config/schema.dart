// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of endpoints.config;

String _capitalize(String string) => "${string.substring(0,1).toUpperCase()}${string.substring(1)}";

class ApiConfigSchema {
  final String schemaName;
  final ClassMirror _schemaClass;
  final String _autoName;
  Map<Symbol, ApiConfigSchemaProperty> _properties = {};

  factory ApiConfigSchema(ClassMirror schemaClass,
                          ApiConfig api,
                          {String name}) {
    var autoName = MirrorSystem.getName(schemaClass.simpleName);
    var schemaName = autoName;
    if (name != null && name.isNotEmpty) {
      schemaName = name;
    }

    var schema = api._getSchema(schemaName);
    if (schema == null) {
      schema = new ApiConfigSchema._internal(
          schemaClass, schemaName, autoName, api);
    } else {
      if (schema._autoName != autoName) {
        throw new ApiConfigError('$schemaName cannot have two different sets '
                                 'of properties.');
      }
    }

    return schema;
  }

  ApiConfigSchema._internal(this._schemaClass, this.schemaName,
                            this._autoName, ApiConfig api) {
    var methods = _schemaClass.declarations.values.where(
      (mm) => mm is MethodMirror && mm.isConstructor
    );
    if (!methods.isEmpty && methods.where(
        (mm) => mm.simpleName == _schemaClass.simpleName).isEmpty) {
      throw new ApiConfigError('$schemaName needs to have an unnamed '
                               'constructor.');
    }

    api._addSchema(schemaName, this);

    _createProperties(api);
  }

  void _createProperties(ApiConfig api) {
    var properties = _schemaClass.declarations.values.where(
      (dm) => dm is VariableMirror &&
              !dm.isConst && !dm.isFinal && !dm.isPrivate && !dm.isStatic
    );

    properties.forEach((VariableMirror vm) {
      var prop = new ApiConfigSchemaProperty(vm, api);
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

  Map getParameter(List<String> path,
                   {bool repeated: false, bool required: true}) {
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

  Map<String, Map> getParameters(
      {String prefix: '', bool repeated: false, bool required: true}) {
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
    InstanceMirror schema = _schemaClass.newInstance(new Symbol(''), []);
    if (request != null) {
      request.forEach((name, value) {
        if (value != null) {
          var sym = new Symbol(name);
          var prop = _properties[sym];
          if (prop != null) {
            schema.setField(sym, prop.fromRequest(value));
          }
        }
      });
    }
    // Check required/default
    _properties.forEach((sym, prop) {
      if (prop.required || prop.hasDefault) {
        var value = schema.getField(sym);
        if (value.hasReflectee) {
          value = value.reflectee;
        }
        if (value == null) {
          if (prop.hasDefault) {
            schema.setField(sym, prop.defaultValue);
            return;
          }
          if (prop.required) {
            throw new BadRequestError(
                'Required field ${prop.propertyName} is missing');
          }
        }
      }
    });
    return schema.reflectee;
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
