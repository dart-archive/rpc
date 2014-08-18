part of endpoints.api_config;

class ApiConfigMethod {
  Symbol _symbol;
  String _apiClass;
  String _methodName;
  String _name;
  String _path;
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
      _responseMessage = reflectClass(VoidMessage);
    } else {
      if (type.isSubtypeOf(reflectType(Future))) {
        var types = type.typeArguments;
        if (types.length == 1) {
          if (types[0].simpleName != #dynamic && types[0].isSubtypeOf(reflectType(ApiMessage))) {
            _responseMessage = types[0];
          }
        }
      } else {
        if (type.simpleName != #dynamic && type.isSubtypeOf(reflectType(ApiMessage))) {
          _responseMessage = type;
        }
      }
    }
    if (_responseMessage == null) {
      throw new ApiConfigError('$_methodName: API Method return type has to be a sub-class of ApiMessage or Future<ApiMessage>');
    }
    if (mm.parameters.length > 2) {
      throw new ApiConfigError('$_methodName: API Methods can only accept at most one ApiMessage and one ApiUser as parameter');
    }
    if (mm.parameters.length == 0) {
      _requestMessage = reflectClass(VoidMessage);
    } else {
      var param = mm.parameters[0];
      var userParam;
      type = param.type;
      if (type.simpleName == #dynamic) {
        throw new ApiConfigError('$_methodName: API Method parameters can\'t be dynamid');
      }

      if (type.isSubtypeOf(reflectType(ApiMessage))) {
        if (param.isNamed || param.isOptional) {
          throw new ApiConfigError('$_methodName: API Method Request parameter can\'t be optional or named');
        }
        _requestMessage = type;
      } else {
        if (type.reflectedType == ApiUser) {
          _requestMessage = reflectClass(VoidMessage);
          userParam = param;
        } else {
          throw new ApiConfigError('$_methodName: API Method parameter has to be a sub-class of ApiMessage');
        }
      }
      if (mm.parameters.length == 2) {
        if (userParam != null) {
          throw new ApiConfigError('$_methodName: Only on API User parameter allowed.');
        }
        userParam = mm.parameters[1];
      }
      if (userParam != null) {
        if (userParam.isNamed) {
          throw new ApiConfigError('$_methodName: API Method User parameter can\'t be named');
        }
        type = userParam.type;
        if (type.reflectedType != ApiUser) {
          throw new ApiConfigError('$_methodName: Second API Method parameter must be of type ApiUser');
        }
        _checkAuth = true;
        if (!userParam.isOptional) {
          _authRequired = true;
        }
      }
    }

    if (_requestMessage.reflectedType != VoidMessage) {
      _requestSchema = parent._getSchema(MirrorSystem.getName(_requestMessage.simpleName));
      if (_requestSchema == null) {
        _requestSchema = new ApiConfigSchema(_requestMessage, parent);
      }
    }
    if (_responseMessage.reflectedType != VoidMessage) {
      _responseSchema = parent._getSchema(MirrorSystem.getName(_responseMessage.simpleName));
      if (_responseSchema == null) {
        _responseSchema = new ApiConfigSchema(_responseMessage, parent);
      }
    }
  }

  Symbol get symbol => _symbol;
  String get methodName => _methodName;
  String get name => _name;

  Map get descriptor {
    var descriptor = {};
    if (_requestMessage.reflectedType != VoidMessage) {
      descriptor['request'] = {
        '\$ref': MirrorSystem.getName(_requestMessage.simpleName)
      };
    }
    if (_responseMessage.reflectedType != VoidMessage) {
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
    if (_requestMessage.reflectedType == VoidMessage) {
      method['request']['body'] = 'empty';
    } else {
      method['request']['body'] = 'autoTemplate(backendRequest)';
      method['request']['bodyName'] = 'resource';
    }

    //TODO: Request & path parameters
    method['request']['parameters'] = {};

    method['response'] = {};
    if (_responseMessage.reflectedType == VoidMessage) {
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
      if (_requestMessage.reflectedType != VoidMessage) {
        params.add(_requestSchema.fromRequest(request));
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
      } catch (e) {
        completer.completeError(new ApiInternalServerException('Unhandled Error in API Method: $e'));
      }
      if (response is! Future) {
        response = new Future.value(response);
      }
      response.then((message) {
        if (_responseMessage.reflectedType == VoidMessage || message == null) {
          completer.complete({});
          return;
        }
        completer.complete(_responseSchema.toResponse(message));
      });
    });
    return completer.future;
  }
}
