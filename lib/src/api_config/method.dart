part of endpoints.api_config;

final RegExp _pathMatcher = new RegExp(r'\{(.*?)\}');
const List<String> _allowedMethods = const ['GET', 'DELETE', 'PUT', 'POST', 'PATCH'];
const List<String> _bodyLessMethods = const ['GET', 'DELETE'];

class ApiConfigMethod {
  Symbol _symbol;
  String _apiClass;
  String _methodName;
  String _name;
  String _path;
  List<String> _pathParams = [];
  Map<String, ApiConfigSchemaProperty> _parameters = {};
  String _httpMethod;
  String _description;
  ApiConfigSchema _requestSchema;
  ApiConfigSchema _responseSchema;

  bool _authRequired = false;
  bool _checkAuth = false;

  ApiConfigMethod(MethodMirror mm, String this._apiClass, ApiConfig parent) {
    ApiMethod metadata = mm.metadata.first.reflectee;
    _symbol = mm.simpleName;
    _methodName = _apiClass + "." + MirrorSystem.getName(_symbol);
    _name = metadata.name;
    _path = metadata.path;
    _httpMethod = metadata.method.toUpperCase();
    _description = metadata.description;

    if (_name == null || _name == '') {
      throw new ApiConfigError('$_methodName: missing method name');
    }
    if (_path == null || _path == '') {
      throw new ApiConfigError('$_methodName: missing method path');
    }

    if (!_allowedMethods.contains(_httpMethod)) {
      throw new ApiConfigError('$_methodName: Unknown HTTP method');
    }

    var type = mm.returnType;
    if (type.simpleName == new Symbol('void')) {
      throw new ApiConfigError('$_methodName: API Method can\'t be void, use VoidMessage as return type instead.');
    }
    if (type.isSubtypeOf(reflectType(Future))) {
      var types = type.typeArguments;
      if (types.length == 1) {
        type = types[0];
      } else {
        throw new ApiConfigError('$_methodName: Future return type has to have one specific type defined');
      }
    }
    if (type is! ClassMirror || type.simpleName == #dynamic || type.isAbstract) {
      throw new ApiConfigError('$_methodName: API Method return type has to be a instantiable class');
    }
    ClassMirror responseMessage = type;

    if (mm.parameters.length > 2) {
      throw new ApiConfigError('$_methodName: API Methods can only accept at most one request message and one ApiUser as parameter');
    }
    if (mm.parameters.length == 0) {
      throw new ApiConfigError('$_methodName: ApiMessage request parameter needs to be specified');
    }
    var param = mm.parameters[0];
    if (param.isNamed || param.isOptional) {
      throw new ApiConfigError('$_methodName: Request parameter can\'t be optional or named');
    }
    type = param.type;
    if (type is! ClassMirror || type.simpleName == #dynamic || type.isAbstract) {
      throw new ApiConfigError('$_methodName: API Method parameter has to be a instantiable class');
    }
    ClassMirror requestMessage = type;

    if (mm.parameters.length == 2) {
      var userParam = mm.parameters[1];
      if (userParam.isNamed) {
        throw new ApiConfigError('$_methodName: API Method User parameter can\'t be named');
      }
      if (userParam.type.reflectedType != ApiUser) {
        throw new ApiConfigError('$_methodName: Second API Method parameter must be of type ApiUser');
      }
      _checkAuth = true;
      if (!userParam.isOptional) {
        _authRequired = true;
      }
    }

    if (requestMessage != null) {
      _requestSchema = parent._getSchema(MirrorSystem.getName(requestMessage.simpleName));
      if (_requestSchema == null) {
        _requestSchema = new ApiConfigSchema(requestMessage, parent);
      }
    }
    if (responseMessage != null) {
      _responseSchema = parent._getSchema(MirrorSystem.getName(responseMessage.simpleName));
      if (_responseSchema == null) {
        _responseSchema = new ApiConfigSchema(responseMessage, parent);
      }
    }

    var pathParams = _pathMatcher.allMatches(_path);
    pathParams.forEach((Match m) {
      var param = m.group(1);
      if (_requestSchema == null || !_requestSchema.hasSimpleProperty(param.split('.'))) {
        throw new ApiConfigError('$_methodName: Path parameters must be simple properties of the request message.');
      }
      _pathParams.add(param);
    });
  }

  Symbol get symbol => _symbol;
  String get methodName => _methodName;
  String get name => _name;

  Map get descriptor {
    var descriptor = {};
    if (_requestSchema != null && _requestSchema.hasProperties) {
      descriptor['request'] = {
        '\$ref': _requestSchema.schemaName
      };
    }
    if (_responseSchema != null && _responseSchema.hasProperties) {
      descriptor['response'] = {
        '\$ref': _responseSchema.schemaName
      };
    }
    return descriptor;
  }

  Map get resourceMethod {
    var method = {};
    method['path'] = _path;
    method['httpMethod'] = _httpMethod;
    method['rosyMethod'] = '${_methodName}';
    method['scopes'] = ['https://www.googleapis.com/auth/userinfo.email', 'https://www.googleapis.com/auth/userinfo.profile'];
    method['description'] = _description;
    method['request'] = {};
    if (_requestSchema == null || !_requestSchema.hasProperties || _bodyLessMethods.contains(_httpMethod)) {
      method['request']['body'] = 'empty';
    } else {
      method['request']['body'] = 'autoTemplate(backendRequest)';
      method['request']['bodyName'] = 'resource';
    }

    if (_bodyLessMethods.contains(_httpMethod)) {
      if (_requestSchema == null  || !_requestSchema.hasProperties) {
        method['request']['parameters'] = {};
      } else {
        method['request']['parameters'] = _requestSchema.getParameters();
        _pathParams.forEach((paramName) {
          method['request']['parameters'][paramName]['required'] = true;
        });

        // Add required parameters to Parameter list (after path params)
        method['request']['parameters'].forEach((name, param) {
          if (param['required'] == true) {
            if (!_pathParams.contains(name)) {
              _pathParams.add(name);
            }
          }
        });
      }
    } else {
      method['request']['parameters'] = {};
      _pathParams.forEach((paramName) {
        var param = _requestSchema.getParameter(paramName.split('.'));
        param['required'] = true;
        method['request']['parameters'][paramName] = param;
      });
    }
    if (_pathParams.length > 0) {
      method['request']['parameterOrder'] = _pathParams;
    }

    method['response'] = {};
    if (_responseSchema == null || !_responseSchema.hasProperties) {
      method['response']['body'] = 'empty';
    } else {
      method['response']['body'] = 'autoTemplate(backendResponse)';
      method['response']['bodyName'] = 'resource';
    }

    return method;
  }

  Future<Map> invoke(InstanceMirror api, Map request, [ApiUser user]) {
    return new Future.sync(() {
      var params = [];
      if (_requestSchema != null && _requestSchema.hasProperties) {
        params.add(_requestSchema.fromRequest(request));
      } else {
        params.add(null);
      }
      if (_checkAuth) {
        if (_authRequired && user == null) {
          throw new UnauthorizedError("User authentication required.");
        }
        params.add(user);
      }
      var response = api.invoke(_symbol, params).reflectee;
      if (response is! Future) {
        response = new Future.value(response);
      }
      return response.then((message) {
        if (_responseSchema == null || message == null || !_responseSchema.hasProperties) {
          return {};
        }
        return _responseSchema.toResponse(message);
      });
    });
  }
}
