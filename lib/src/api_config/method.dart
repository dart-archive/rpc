part of endpoints.api_config;

RegExp _pathMatcher = new RegExp(r'\{(.*?)\}');

class ApiConfigMethod {
  Symbol _symbol;
  String _apiClass;
  String _methodName;
  String _name;
  String _path;
  List<String> _pathParams = [];
  String _httpMethod;
  String _description;
  ClassMirror _requestMessage;
  ClassMirror _responseMessage;
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

    var type = mm.returnType;
    if (type.simpleName == new Symbol('void')) {
      throw new ApiConfigError('$_methodName: API Method return type has to be a sub-class of ApiMessage or Future<ApiMessage>');
    }
    if (type.isSubtypeOf(reflectType(Future))) {
      var types = type.typeArguments;
      if (types.length == 1) {
        type = types[0];
      } else {
        throw new ApiConfigError('$_methodName: API Method return type has to be a sub-class of ApiMessage or Future<ApiMessage>');
      }
    }
    if (type.simpleName != #dynamic && type.isSubtypeOf(reflectType(ApiMessage))) {
      if (type.reflectedType == VoidMessage) {
        _responseMessage = null;
      } else {
        _responseMessage = type;
      }
    } else {
      throw new ApiConfigError('$_methodName: API Method return type has to be a sub-class of ApiMessage or Future<ApiMessage>');
    }

    if (mm.parameters.length > 2) {
      throw new ApiConfigError('$_methodName: API Methods can only accept at most one ApiMessage and one ApiUser as parameter');
    }
    if (mm.parameters.length == 0) {
      throw new ApiConfigError('$_methodName: ApiMessage request parameter needs to be specified');
    }
    var param = mm.parameters[0];
    if (param.isNamed || param.isOptional) {
      throw new ApiConfigError('$_methodName: Request parameter can\'t be optional or named');
    }
    type = param.type;
    if (type.simpleName != #dynamic && type.isSubtypeOf(reflectType(ApiMessage))) {
      if (type.reflectedType == VoidMessage) {
        _requestMessage = null;
      } else {
        _requestMessage = type;
      }
    } else {
      throw new ApiConfigError('$_methodName: API Method parameter has to be a sub-class of ApiMessage');
    }
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

    if (_requestMessage != null) {
      _requestSchema = parent._getSchema(MirrorSystem.getName(_requestMessage.simpleName));
      if (_requestSchema == null) {
        _requestSchema = new ApiConfigSchema(_requestMessage, parent);
      }
    }
    if (_responseMessage != null) {
      _responseSchema = parent._getSchema(MirrorSystem.getName(_responseMessage.simpleName));
      if (_responseSchema == null) {
        _responseSchema = new ApiConfigSchema(_responseMessage, parent);
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
    if (_requestMessage != null) {
      descriptor['request'] = {
        '\$ref': MirrorSystem.getName(_requestMessage.simpleName)
      };
    }
    if (_responseMessage != null) {
      descriptor['response'] = {
        '\$ref': MirrorSystem.getName(_responseMessage.simpleName)
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
    if (_requestMessage == null) {
      method['request']['body'] = 'empty';
    } else {
      method['request']['body'] = 'autoTemplate(backendRequest)';
      method['request']['bodyName'] = 'resource';
    }

    if (['GET', 'DELETE'].contains(_httpMethod)) {
      //TODO: all request parameters, set path parameters to required
      method['request']['parameters'] = {};
    } else {
      //TODO: Request & path parameters
      method['request']['parameters'] = {};
    }
    if (_pathParams.length > 0) {
      method['request']['parameterOrder'] = _pathParams;
    }

    method['response'] = {};
    if (_responseMessage == null) {
      method['response']['body'] = 'empty';
    } else {
      method['response']['body'] = 'autoTemplate(backendResponse)';
      method['response']['bodyName'] = 'resource';
    }

    return method;
  }

  Future<Map> invoke(InstanceMirror api, Map request, [ApiUser user]) {
    var completer = new Completer();
    new Future.sync(() {
      var params = [];
      if (_requestMessage != null) {
        params.add(_requestSchema.fromRequest(request));
      } else {
        params.add(null);
      }
      if (_checkAuth) {
        if (_authRequired && user == null) {
          completer.completeError(new ApiUnauthorizedException("User authentication required."));
          return;
        }
        params.add(user);
      }
      var response;
      try {
        response = api.invoke(_symbol, params).reflectee;
      } on ApiException catch (e) {
        completer.completeError(e);
        return;
      } catch (e) {
        context.services.logging.error('Unhandled Error in API Method: $e');
        completer.completeError(new ApiInternalServerException('Unhandled Error in API Method: $e'));
        return;
      }
      if (response is! Future) {
        response = new Future.value(response);
      }
      response.then((message) {
        if (_responseMessage == null || message == null) {
          completer.complete({});
          return;
        }
        completer.complete(_responseSchema.toResponse(message));
      });
    });
    return completer.future;
  }
}
