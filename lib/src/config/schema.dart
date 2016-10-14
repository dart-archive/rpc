// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfigSchema {
  final String schemaName;
  final ClassMirror schemaClass;
  final Map<Symbol, ApiConfigSchemaProperty> _properties = {};
  // This bool tells whether the schema is used as a request in which case it
  // must have a zero-argument constructor in order for us to instantiate it
  // using reflection.
  final bool isUsedForRequest;
  bool propertiesInitialized = false;

  ApiConfigSchema(this.schemaName, this.schemaClass, this.isUsedForRequest);

  // Helper to add properties. We use this to be able to create the schema
  // before having parsed its properties to detect cycles. However we don't
  // want to support updating properties in general, hence the assert.
  void initProperties(Map<Symbol, ApiConfigSchemaProperty> properties) {
    assert(_properties.isEmpty);
    _properties.addAll(properties);
    propertiesInitialized = true;
  }

  bool get containsData => !_properties.isEmpty;

  discovery.JsonSchema get asDiscovery {
    var schema = new discovery.JsonSchema();
    schema
      ..id = schemaName
      ..type = 'object'
      ..properties = new Map<String, discovery.JsonSchema>();
    _properties.values.forEach((prop) {
      schema.properties[prop.name] = prop.asDiscovery;
    });
    return schema;
  }

  fromRequest(request) {
    if (request is! Map) {
      throw new BadRequestError(
          'Invalid parameter: \'$request\', should be an instance of type '
          '\'$schemaName\'.');
    }
    bool initializeConstructorParameters = false;
    for (InstanceMirror im in schemaClass.metadata) {
      if (im.reflectee is ApiMessage
          && im.reflectee.withConstructorParameters) {
        initializeConstructorParameters = true;
        break;
      }
    }

    Map objectFieldValues = new Map();
    for (Symbol sym in _properties.keys) {
      final prop = _properties[sym];

      if (request.containsKey(prop.name)) {
        // MediaMessage special case
        if (request[prop.name] is MediaMessage ||
            request[prop.name] is List<MediaMessage>) {
          // If in form, there is an (input[type="file"] multiple) and the user
          // put only one file. It's not an error and it should be accept.
          // Maybe it cans be optimized.
          if (schemaClass.instanceMembers[sym]
                      .returnType
                      .reflectedType
                      .toString() ==
                  'List<MediaMessage>' &&
              request[prop.name] is MediaMessage) {
            objectFieldValues[sym] = [request[prop.name]];
          } else if (request[prop.name] is List) {
            objectFieldValues[sym] = prop.fromRequest(request[prop.name]);
          } else {
            objectFieldValues[sym] = request[prop.name];
          }
        } else {
          objectFieldValues[sym] = prop.fromRequest(request[prop.name]);
        }
      } else if (prop.hasDefault) {
        objectFieldValues[sym] = prop.fromRequest(prop.defaultValue);
      } else if (prop.required) {
        throw new BadRequestError('Required field ${prop.name} is missing');
      }
    }

    List positionalArguments = new List();
    Map namedArguments = new Map();
    var constructors;
    if (initializeConstructorParameters && (constructors =
        schemaClass.declarations.values.where((mm) => mm is MethodMirror &&
            mm.isConstructor && mm.simpleName == schemaClass.simpleName &&
            mm.parameters.isNotEmpty)).isNotEmpty) {

      var constructor = constructors.first;
      for (ParameterMirror pm in constructor.parameters) {

        if (!objectFieldValues.containsKey(pm.simpleName)) {
          if (pm.isOptional) {
            continue;
          } else {
            String parameterName = MirrorSystem.getName(pm.simpleName);
            throw new BadRequestError('Required field $parameterName is missing');
          }
        }

        if (pm.isNamed) {
          namedArguments[pm.simpleName] = objectFieldValues[pm.simpleName];
        } else {
          positionalArguments.add(objectFieldValues[pm.simpleName]);
        }
      }
    }

    InstanceMirror schema = schemaClass.newInstance(new Symbol(''),
        positionalArguments, namedArguments);


    objectFieldValues.forEach((Symbol sym, var value) {
      schema.setField(sym, value);
    });

    return schema.reflectee;
  }

  toResponse(result) {
    var response = {};
    InstanceMirror mirror = reflect(result);
    _properties.forEach((sym, prop) {
      var value = prop.toResponse(mirror.getField(sym).reflectee);
      if (value != null) {
        response[prop.name] = value;
      }
    });
    return response;
  }
}

// Schema for explicitly handling List<'some value'> as either return
// or argument type. For the arguments it is only supported for POST requests.
class NamedListSchema extends ApiConfigSchema {
  ApiConfigSchemaProperty _itemsProperty;

  NamedListSchema(String schemaName, ClassMirror schemaClass, bool isRequest)
      : super(schemaName, schemaClass, isRequest);

  void initItemsProperty(ApiConfigSchemaProperty itemsProperty) {
    assert(_itemsProperty == null);
    _itemsProperty = itemsProperty;
  }

  bool get containsData => _itemsProperty != null;

  discovery.JsonSchema get asDiscovery {
    var schema = new discovery.JsonSchema();
    schema
      ..id = schemaName
      ..type = 'array'
      ..items = _itemsProperty.asDiscovery;
    return schema;
  }

  fromRequest(request) {
    if (request is! List) {
      throw new BadRequestError(
          'Invalid parameter: \'$request\', should be an instance of type '
          '\'$schemaName\'.');
    }
    // TODO: Performance optimization, we don't need to decode a list of
    // primitive-type since it is already the correct list.
    return request.map(_itemsProperty.fromRequest).toList();
  }

  // TODO: Performance optimization, we don't need to encode a list of
  // primitive-type since it is already the correct list.
  toResponse(result) => result.map(_itemsProperty.toResponse).toList();
}

// Schema for explicitly handling Map<String, 'some value'> as either return
// or argument type. For the arguments it is only supported for POST requests.
class NamedMapSchema extends ApiConfigSchema {
  ApiConfigSchemaProperty _additionalProperty;

  NamedMapSchema(String schemaName, ClassMirror schemaClass, bool isRequest)
      : super(schemaName, schemaClass, isRequest);

  void initAdditionalProperty(ApiConfigSchemaProperty additionalProperty) {
    assert(_additionalProperty == null);
    _additionalProperty = additionalProperty;
  }

  bool get containsData => _additionalProperty != null;

  discovery.JsonSchema get asDiscovery {
    var schema = new discovery.JsonSchema();
    schema
      ..id = schemaName
      ..type = 'object'
      ..additionalProperties = _additionalProperty.asDiscovery;
    return schema;
  }

  fromRequest(request) {
    if (request is! Map) {
      throw new BadRequestError(
          'Invalid parameter: \'$request\', must be an instance of type '
          '\'$schemaName\'.');
    }
    // Map from String to the type of the additional property.
    var decodedRequest = {};
    // TODO: Performance optimization, we don't need to decode a map from
    // <String, primitive-type> since it is already the correct map.
    request.forEach((String key, value) {
      decodedRequest[key] = _additionalProperty.fromRequest(value);
    });
    return decodedRequest;
  }

  toResponse(result) {
    var encodedResult = {};
    // TODO: Performance optimization, we don't need to encode a map from
    // <String, primitive-type> since it is already the correct map.
    (result as Map).forEach((String key, value) {
      encodedResult[key] = _additionalProperty.toResponse(value);
    });
    return encodedResult;
  }
}
