// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

String _capitalize(String string) => "${string.substring(0,1).toUpperCase()}${string.substring(1)}";

class ApiConfigSchema {
  final String schemaName;
  final ClassMirror schemaClass;
  final Map<Symbol, ApiConfigSchemaProperty> _properties = {};
  bool propertiesInitialized = false;

  ApiConfigSchema(this.schemaName, this.schemaClass);

  // Helper to add properties. We use this to be able to create the schema
  // before having parsed its properties to detect cycles. However we don't
  // want to support updating properties in general, hence the assert.
  void initProperties(Map<Symbol, ApiConfigSchemaProperty> properties) {
    assert(_properties.isEmpty);
    _properties.addAll(properties);
    propertiesInitialized = true;
  }

  bool get hasProperties => !_properties.isEmpty;

  discovery.JsonSchema get asDiscovery {
    var schema = new discovery.JsonSchema();
    // TODO: Check up on schema name, currently it is qualified symbol name.
    schema..id = schemaName
          ..type = 'object'
          ..properties = new Map<String, discovery.JsonSchema>();
    _properties.values.forEach((prop) {
      schema.properties[prop.name] = prop.asDiscovery;
    });
    return schema;
  }

  fromRequest(Map request) {
    InstanceMirror schema = schemaClass.newInstance(new Symbol(''), []);
    _properties.forEach((sym, prop) {
      if (request.containsKey(prop.name)) {
        schema.setField(sym, prop.fromRequest(request[prop.name]));
      } else if (prop.hasDefault) {
        schema.setField(sym, prop.fromRequest(prop.defaultValue));
      } else if (prop.required) {
        throw new BadRequestError('Required field ${prop.name} is missing');
      }
    });
    return schema.reflectee;
  }

  Map toResponse(result) {
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
