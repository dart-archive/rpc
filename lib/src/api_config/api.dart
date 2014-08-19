part of endpoints.api_config;

class ApiConfig {

  InstanceMirror _api;
  ClassMirror _apiClass;

  String _name;
  String _version;
  String _description;
  String _apiClassName;
  List<String> _clientIds = [];

  List<ApiConfigError> _errors = [];
  Map<String, ApiConfigMethod> _methodMap = {};
  Map<String, ApiConfigSchema> _schemaMap = {};

  ApiConfig(api) {
    _api = reflect(api);
    _apiClass = _api.type;
    _apiClassName = MirrorSystem.getName(_apiClass.simpleName);

    var metas = _apiClass.metadata.where((m) => m.reflectee.runtimeType == ApiClass);

    if (metas.length == 0) {
      _errors.add(new ApiConfigError('API Class needs to have @ApiClass annotation'));
      return;
    }

    ApiClass metaData = metas.first.reflectee;
    _name = metaData.name;
    _version = metaData.version;
    _description = metaData.description;
    _clientIds = metaData.allowedClientIds;

    if (_name == null || _name == '') {
      _errors.add(new ApiConfigError('ApiClass.name is required'));
    }
    if (_version == null || _version == '') {
      _errors.add(new ApiConfigError('ApiClass.version is required'));
    }

    var methods = _apiClass.declarations.values.where(
      (dm) => dm is MethodMirror &&
              dm.isRegularMethod &&
              dm.metadata.length > 0 &&
              dm.metadata.first.reflectee.runtimeType == ApiMethod
    );

    methods.forEach((MethodMirror mm) {
      ApiConfigMethod method;
      try {
        method = new ApiConfigMethod(mm, _apiClassName, this);
      } on ApiConfigError catch (e) {
        _errors.add(e);
        return;
      } catch (e) {
        _errors.add(new ApiConfigError('Unknown API Config error: $e'));
        return;
      }
      _methodMap[method.methodName] = method;
    });
  }

  ApiConfigSchema _getSchema(name) => _schemaMap[name];

  _addSchema(schemaName, ApiConfigSchema schema) {
    if (schema != null) {
      if (!_schemaMap.containsKey(schemaName)) {
        _schemaMap[schemaName] = schema;
      }
    }
  }

  bool get isValid => _errors.isEmpty;

  String get errors => '$_apiClassName:\n' + _errors.join('\n');

  List<String> get clientIds => _clientIds;

  bool canHandleCall(String method) => _methodMap.containsKey(method);

  Future<Map> handleCall(String method, Map request, [ApiUser user]) {
    return _methodMap[method].invoke(_api, request, user);
  }

  Map toJson([String root = 'localhost:8080']) {
    Map json = {};
    json['extends'] = 'thirdParty.api';
    json['root'] = 'https://$root/_ah/api';
    json['name'] = _name;
    json['version'] = _version;
    json['description'] = _description;
    json['defaultVersion'] = 'true';
    json['abstract'] = 'false';
    json['adapter'] = {
      'bns': 'https://$root/_ah/spi',
      'type': 'lily',
      'deadline': 10.0
    };
    json['methods'] = {};
    json['descriptor'] = {
      'methods': {},
      'schemas' : {}
    };

    _methodMap.values.forEach((method) {
      json['descriptor']['methods'][method.methodName] = method.descriptor;
      json['methods']['${_name}.${method.name}'] = method.resourceMethod;
    });

    _schemaMap.values.where((schema) => (schema.propertyCount > 0)).forEach((schema) {
      json['descriptor']['schemas'][schema.schemaName] = schema.descriptor;
    });

    return json;
  }

  String toString([String root = 'localhost:8080']) => JSON.encode(toJson(root));
}
