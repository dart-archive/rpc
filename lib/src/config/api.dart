// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of endpoints.config;

class ApiConfig {

  final String id;
  final String apiPath;
  final String _name;
  final String _version;
  final String _title;
  final String _description;

  final List<ApiConfigError> _errors = [];
  final Map<String, ApiConfigSchema> _schemaMap = {};

  // Method map from {$HttpMethod$NumberOfPathSegments} to list of methods.
  // TODO: Measure method lookup and possibly change to tree structure to
  // avoid the list.
  final Map<String, List<ApiConfigMethod> > _methodMap = {};

  final List<ApiConfigMethod> _topLevelMethods = [];
  final Map<String, ApiConfigResource> _resources = {};

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
      // Default name is the class name with lowercase first letter.
      name = camelCaseName(id);
    }
    String apiPath = '/$name/${metaData.version}';
    return new ApiConfig._(id, apiPath, name, metaData.version,
                           metaData.title, metaData.description,
                           apiInstance, apiClass);
  }

  ApiConfig._(this.id, this.apiPath, this._name, this._version, this._title,
              this._description, InstanceMirror apiInstance,
              ClassMirror apiClass) {
    assert(this._name != null);
    if (_version == null || _version.isEmpty) {
      _errors.add(new ApiConfigError('$id: ApiClass.version field is '
                                     'required'));
    }
    // Scan for API methods and resources.
    List<ApiConfigResource> resources = [];
    scanApi(apiClass, apiInstance, id, this, _topLevelMethods, resources);

    // Setup the resources and check for duplicates.
    resources.forEach((resource) {
      if (_resources.containsKey(resource.name)) {
        addError(new ApiConfigError('$id: Duplicate resource with name: '
                                    '${resource.name}'));
        return;
      }
      _resources[resource.name] = resource;
    });

    // Add methods to api.
    _topLevelMethods.forEach(addMethod);
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
      if (_overlappingPaths(methodPathSegments, existingMethodPathSegments)) {
        _errors.add(new ApiConfigError(
            '${method.id}: Method path: ${method.path} overlaps with method '
            'path of ${existingMethod.id}: ${existingMethod.path}'));
      }
    }
    existingMethods.add(method);
  }

  bool _overlappingPaths(List<String> pathSegments1,
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

  Future<HttpApiResponse> handleHttpRequest(HttpApiRequest request) {
    final List<ApiConfigMethod> methods = _methodMap[request.methodKey];
    if (methods != null) {
      for (var method in methods) {
        // TODO: improve performance of this (measure first).
        if (method.matches(request)) {
          return method.invokeHttpRequest(request);
        }
      }
    }
    return new Future.error(
        new NotFoundError('Unknown method: ${request.httpMethod} '
                          '${request.uri.path}.'));
  }

  Map toJson(String root, [String apiPathPrefix]) {
    String servicePath;
    if (apiPathPrefix != null) {
      servicePath = '$apiPathPrefix$apiPath/';
    } else {
      servicePath = '${apiPath.substring(1)}/';
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
      'resources'       : {}
    };
    _schemaMap.values.where((schema) => (schema.hasProperties))
        .forEach((schema) {
          json['schemas'][schema.schemaName] = schema.descriptor;
        });
    _resources.values.forEach((resource) {
      json['resources'][resource.name] = resource.asJson;
    });
    _topLevelMethods.forEach((method) {
        json['methods'][method.name] = method.asJson;
    });
    // TODO: Check if this is stable or not. E.g. if the hash map is
    // deterministic.
    var sha1 = new SHA1();
    sha1.add(UTF8.encode(json.toString()));
    json['etag'] = CryptoUtils.bytesToHex(sha1.close());
    return json;
  }
}
