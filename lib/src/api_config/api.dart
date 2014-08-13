part of endpoints.api_config; 

class ApiConfig {

  InstanceMirror _api;
  ClassMirror _apiClass;

  String _name;
  String _version;
  String _description;
  String _apiClassName;

  List<ApiConfigError> _errors = [];
  Map<String, ApiConfigMethod> _methodMap = {};
  Map<String, ApiConfigSchema> _schemaMap = {};

  ApiConfig(Api api) {
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
      }
      _methodMap[method.methodName] = method;
    });
  }

  ApiConfigSchema _getSchema(name) => _schemaMap[name];
  
  _addSchema(ApiConfigSchema schema) {
    if (schema != null) {
      if (!_schemaMap.containsKey(schema.schemaName)) {
        _schemaMap[schema.schemaName] = schema;
      }
    }
  }

  bool get isValid => _errors.isEmpty;

  String get errors => '$_apiClassName:\n' + _errors.join('\n');

  Map toJson() {
    Map json = {};
    // TODO: better way to determine root URL
    Map env = Platform.environment;
    String root = 'https://${env['GAE_LONG_APP_ID']}.appspot.com';
    if (env['GAE_PARTITION'] == 'dev') {
      root = 'https://localhost:${env['GAE_SERVER_PORT']}';
    }
    json['extends'] = 'thirdParty.api';
    json['root'] = '$root/_ah/api';
    json['name'] = _name;
    json['version'] = _version;
    json['description'] = _description;
    json['defaultVersion'] = 'true';
    json['abstract'] = 'false';
    json['adapter'] = {
      'bns': '$root/_ah/spi',
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

    _schemaMap.values.forEach((schema) {
      json['descriptor']['schemas'][schema.schemaName] = schema.descriptor;
    });

    return json;
  }

  String toString() => JSON.encode(toJson());
}
