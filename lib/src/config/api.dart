// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of endpoints.config;

class ApiConfig {

  final InstanceMirror _api;
  final ClassMirror _apiClass;

  final String id;
  final String _name;
  final String _version;
  final String _title;
  final String _description;
  final String apiPath;

  final List<ApiConfigError> _errors = [];
  final Map<String, ApiConfigSchema> _schemaMap = {};

  // Method map from {$HttpMethod$NumberOfPathSegments} to list of methods.
  // TODO: Measure method lookup and possibly change to tree structure to
  // avoid the list.
  final Map<String, List<ApiConfigMethod> > _methodMap = {};

  final List<ApiConfigMethod> _topLevelMethods = [];

  factory ApiConfig(api) {
    var apiInstance = reflect(api);
    var apiClass = apiInstance.type;
    var id = MirrorSystem.getName(apiClass.simpleName);
    var metas = apiClass.metadata.where(
        (m) => m.reflectee.runtimeType == ApiClass);
    if (metas.length != 1) {
      throw new ApiConfigError('$id: API Class must have exactly one '
                               '@ApiClass annotation.');
    }
    ApiClass metaData = metas.first.reflectee;
    var name = metaData.name;
    if (name == null || name.isEmpty) {
      // Default name to class id with lowercase first letter.
      name = id.substring(0, 1).toLowerCase() + id.substring(1);
    }
    String apiPath = '$name/${metaData.version}';
    return new ApiConfig._(id, apiPath, apiInstance, apiClass,
        name, metaData.version, metaData.title, metaData.description);
  }

  ApiConfig._(this.id, this.apiPath, this._api, this._apiClass, this._name,
              this._version, this._title, this._description) {
    assert(this._name != null);
    if (_version == null || _version.isEmpty) {
      _errors.add(new ApiConfigError('$id: ApiClass.version field is '
                                     'required'));
    }
    // We do not support inheritance for annotated API methods. Ie.
    // a parent class' methods are not exposed as API entry points.
    _apiClass.declarations.values.forEach((dm) {
      if (dm is! MethodMirror ||
          !dm.isRegularMethod ||
          dm.metadata.length == 0) {
        // Ignore this declaration as it is not a regular method with at least
        // one annotation.
        return;
      }
      // Check the method declaration has exactly one ApiMethod annotation.
      var annotations = dm.metadata.where(
          (a) => a.reflectee.runtimeType == ApiMethod).toList();
      if (annotations.length > 1) {
        _errors.add(new ApiConfigError('$id: Multiple ApiMethod annotations '
                                       'on method \'${dm.simpleName}\'.'));
      } else if (annotations.length == 1) {
        var method;
        try {
          method = new ApiConfigMethod(dm, annotations.first.reflectee,
                                       this, _api);
        } on ApiConfigError catch (e) {
          _errors.add(e);
          return;
        } catch (e) {
          _errors.add(
              new ApiConfigError('$id: Unknown API Config error: $e.'));
          return;
        }

        _topLevelMethods.add(method);
        addMethod(method);
      }
      // Method has no ApiMethod annotation. Ignore.
    });
  }

  void addMethod(ApiConfigMethod method) {
    var methodPathSegments = method.path.split('/');
    var methodKey = '${method.httpMethod}${methodPathSegments.length}';

    // Check for duplicates.
    //
    // For a given http method type (GET, POST, etc.) a method path can only
    // conflict/be ambiguous with another method path that has the same number
    // of path segments. This relies on path parameters being required.
    //
    // All existing methods are grouped by their http method plus their number
    // of path segments.
    // E.g. GET a/{b}/c will be in the _methodMap group with key 'GET3'.
    //
    // The only way to ensure that two methods within the same group are not
    // ambiguous is if they have at least one non-parameter path segment in the
    // same location that does not match each other. That check is done by the
    // overlappingPaths method call.
    var existingMethods = _methodMap.putIfAbsent(methodKey, () => []);
    for (ApiConfigMethod existingMethod in existingMethods) {
      List<String> existingMethodPathSegments =
          existingMethod.path.split('/');
      if (overlappingPaths(methodPathSegments, existingMethodPathSegments)) {
        _errors.add(new ApiConfigError(
            '${method.id}: Method path: ${method.path} overlaps with method '
            'path of ${existingMethod.id}: ${existingMethod.path}'));
      }
    }
    existingMethods.add(method);
  }

  bool overlappingPaths(List<String> pathSegments1,
                        List<String> pathSegments2) {
    assert(pathSegments1.length == pathSegments2.length);
    for (int i = 0; i < pathSegments1.length; ++i) {
      if (!pathSegments1[i].startsWith('{') &&
          !pathSegments2[i].startsWith('{') &&
          pathSegments1[i] != pathSegments2[i]) {
        return false;
      }
    }
    return true;
  }

  ApiConfigSchema _getSchema(String name) => _schemaMap[name];

  addSchema(schemaName, ApiConfigSchema schema) {
    if (schema != null) {
      if (_schemaMap.containsKey(schemaName)) {
        throw new ApiConfigError(
            '_id: Duplicate schema with name: ${schemaName}.');
      }
      _schemaMap[schemaName] = schema;
    }
  }

  bool get isValid => _errors.isEmpty;

  String get errors => '$id:\n' + _errors.join('\n');

  void addError(ApiConfigError error) => _errors.add(error);

  Future<Map> handleCall(String httpMethod,
                         String methodPath,
                         Map<String, String> queryParams,
                         Map requestBody) {
    String methodKey = '$httpMethod${methodPath.split('/').length}';
    List<ApiConfigMethod> methods = _methodMap[methodKey];
    Uri methodUri = Uri.parse(methodPath);
    if (methods != null) {
      for (var method in methods) {
        // TODO: improve performance of this (measure first).
        UriMatch match = method.matches(methodUri);
        if (match != null) {
          assert(match.rest.path.length == 0);
          return method.invoke(match.parameters, queryParams, requestBody);
        }
      }
    }
    return new Future.error(
        new NotFoundError('Unknown method: $httpMethod $apiPath/'
                          '$methodPath.'));
  }

  Map toJson(String root, [String apiPathPrefix = '']) {
    String servicePath;
    if (apiPathPrefix != null) {
      servicePath = '$apiPathPrefix/$apiPath/';
    } else {
      servicePath = apiPath;
    }
    Map json = {
      'kind'            : 'discovery#restDescription',
      'etag'            : '',
      'discoveryVersion': 'v1',
      'id'              : '$_name:$_version',
      'name'            : _name,
      'version'         : _version,
      'revision'        : '0',
      'title'           : _title == null ? _name : _title,
      'description'     : _description == null ? '' : _description,
      // TODO: Handle icons and documentationLink fields.
      'protocol'        : 'rest',
      'baseUrl'         : '$root$servicePath',
      'basePath'        : '/$servicePath',
      'rootUrl'         : root,
      'servicePath'     : servicePath,
      // TODO: Handle batch requests, ie. 'batchPath'.
      // TODO: Add support for toplevel API parameters.
      'parameters'      : {},
      'schemas'         : {},
      'methods'         : {},
      // TODO: Add support for resources.
      'resources'       : {}
    };
    _schemaMap.values.where((schema) => (schema.hasProperties))
        .forEach((schema) {
          json['schemas'][schema.schemaName] = schema.descriptor;
        });
    _topLevelMethods.forEach((method) {
        json['methods'][method.name] = method.toJson;
    });
    // TODO: Check if this is stable or not. E.g. if the hash map is not
    // deterministic.
    var sha1 = new SHA1();
    sha1.add(UTF8.encode(json.toString()));
    json['etag'] = CryptoUtils.bytesToHex(sha1.close());
    return json;
  }
}
