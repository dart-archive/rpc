// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of endpoints.config;


final _bytesToJson = UTF8.decoder.fuse(JSON.decoder);
final _jsonToBytes = JSON.encoder.fuse(UTF8.encoder);
final RegExp _pathMatcher = new RegExp(r'\{(.*?)\}');
const List<String> _allowedMethods =
    const ['GET', 'DELETE', 'PUT', 'POST', 'PATCH'];
const List<String> _bodyLessMethods = const ['GET', 'DELETE'];

class ApiConfigMethod {
  final Symbol symbol;
  final String id;
  final String name;
  final String path;
  final String httpMethod;
  final String description;

  final InstanceMirror _instance;
  final List<String> _pathParams;
  final Map<String, Symbol> _queryParamTypes;
  final ApiConfigSchema _requestSchema;
  final ApiConfigSchema _responseSchema;
  final UriParser _parser;

  factory ApiConfigMethod(MethodMirror mm,
                          ApiMethod metadata,
                          String parentId,
                          ApiConfig api,
                          InstanceMirror instance) {
    var id = '$parentId.' + MirrorSystem.getName(mm.simpleName);
    var name = metadata.name;
    if (name == null || name.isEmpty) {
      // Default name is class name with lowercase first letter.
      var className = MirrorSystem.getName(mm.simpleName);
      name = camelCaseName(className);
    }
    if (metadata.path == null || metadata.path.isEmpty) {
      throw new ApiConfigError('$id: ApiMethod.path field is required.');
    }
    if (metadata.path.startsWith('/')) {
      throw new ApiConfigError('$id: path cannot start with \'/\'.');
    }
    var httpMethod = metadata.method.toUpperCase();
    if (!_allowedMethods.contains(httpMethod)) {
      throw new ApiConfigError(
          '$id: Unknown HTTP method: ${httpMethod}.');
    }

    var returnType = mm.returnType;
    // Note: I cannot to #void to get the symbol since void is a keyword.
    if (returnType.simpleName == const Symbol('void')) {
      throw new ApiConfigError('$id: API Method cannot be void, use '
                               'VoidMessage as return type instead.');
    }
    if (returnType.isSubtypeOf(reflectType(Future))) {
      var types = returnType.typeArguments;
      if (types.length == 1) {
        returnType = types[0];
      } else {
        throw new ApiConfigError('$id: Future return type has to have one '
                                 'specific type defined.');
      }
    }
    if (returnType is! ClassMirror ||
        returnType.simpleName == #dynamic ||
        returnType.isAbstract) {
      throw new ApiConfigError('$id: API Method return type has to be a '
                               'instantiable class.');
    }
    var responseSchema = new ApiConfigSchema(returnType, api);

    // Setup a uri parser used to match a uri to this method.
    var parser;
    try {
      var template = new UriTemplate('${api.apiPath}/${metadata.path}');
      parser = new UriParser(template);
    } catch (e) {
      throw new ApiConfigError(
          '$id: Invalid path: _path. Failed with error: $e');
    }

    var pathParams = [];
    var queryParamTypes = {};
    var requestSchema = _parseParameters(
        id, mm, api, httpMethod, metadata.path, pathParams, queryParamTypes);

    return new ApiConfigMethod._(id, instance, mm.simpleName,
        name, metadata.path, httpMethod, metadata.description,
        pathParams, queryParamTypes, requestSchema, responseSchema, parser);


  }

  ApiConfigMethod._(this.id, this._instance, this.symbol, this.name, this.path,
                    this.httpMethod, this.description, this._pathParams,
                    this._queryParamTypes, this._requestSchema,
                    this._responseSchema, this._parser);

  static ApiConfigSchema _parseParameters(
      String id,
      MethodMirror mm,
      ApiConfig parent,
      String httpMethod,
      String path,
      List<String> pathParams,
      Map<String, Symbol> queryParamTypes) {
    assert(path != null);

    // Parse the path to get the number and order of the path parameters
    // and to validate the same order is given in the method signature.
    // The path parameters must be parsed before the query or request
    // parameters since the number of path parameters is needed.
    var parsedPathParams = _pathMatcher.allMatches(path);
    if (parsedPathParams.length > 0 &&
        (mm.parameters == null ||
         mm.parameters.length < parsedPathParams.length)) {
        throw new ApiConfigError('$id: missing methods parameters specified '
            'in method path: $path.');
    }
    for (int i = 0; i < parsedPathParams.length; ++i) {
      String pathParamName = parsedPathParams.elementAt(i).group(1);
      pathParams.add(pathParamName);
      _parsePathParameter(id, pathParamName, mm.parameters[i]);
    }

    var requestSchema;
    if (_bodyLessMethods.contains(httpMethod)) {
      // If this is a method without body it can have named parameters
      // passed via the query string. There must be a named parameter
      // for each parameter in the query string.
      _parseQueryParameters(id, mm, path, pathParams.length, queryParamTypes);
    } else {
      // Methods with a body must have exactly one additional parameter, namely
      // the class parameter corresponding to the request body.
      var requestType =
          _parseRequestParameter(id, httpMethod, mm, pathParams.length);
      requestSchema = new ApiConfigSchema(requestType, parent);
    }
    return requestSchema;
  }

  static _parsePathParameter(
      String id, String pathParamName, ParameterMirror pm) {
    if (pm.simpleName != MirrorSystem.getSymbol(pathParamName)) {
      throw new ApiConfigError('$id: method path and method parameter name'
                               ' or order does not match.');
    }
    if (pm.isOptional || pm.isNamed) {
      throw new ApiConfigError('$id: No support for optional path '
                               'parameters in API methods.');
    }
    if (pm.type is! ClassMirror || pm.type.simpleName != #String) {
      throw new ApiConfigError('$id: Path parameter must be of type '
                               'String.');
    }
  }

  static _parseQueryParameters(String id,
                               MethodMirror mm,
                               String path,
                               int queryParamIndex,
                               Map<String, Symbol> queryParamTypes) {
    Map queryParameters = Uri.parse(path).queryParameters;
    for (int i = queryParamIndex; i < mm.parameters.length; ++i) {
      var paramMirror = mm.parameters[i];
      if (!paramMirror.isNamed) {
        throw new ApiConfigError('$id: Method parameters populated by query '
            'string argument must be a named parameter.');
      }
      var methodParamName = paramMirror.simpleName.toString();
      if (queryParameters.remove(methodParamName) == null) {
        throw new ApiConfigError('$id: Missing parameter: $methodParamName '
                                 'in method query string.');
      }
      queryParamTypes[methodParamName] = paramMirror.simpleName;
    }
    if (queryParameters.isNotEmpty) {
      throw new ApiConfigError('$id: Missing named parameter(s): '
          '${queryParameters.keys.toString()} from method signature.');
    }
  }

  static ClassMirror _parseRequestParameter(String id,
                                            String httpMethod,
                                            MethodMirror mm,
                                            int requestParamIndex) {
    if (mm.parameters.length  != requestParamIndex + 1) {
      throw new ApiConfigError('$id: API methods using $httpMethod must '
          'have a signature of path parameters followed by exactly one '
          'request parameter.');
    }

    // Validate the request parameter, following the path parameters.
    var requestParam = mm.parameters[requestParamIndex];
    if (requestParam.isNamed || requestParam.isOptional) {
      throw new ApiConfigError('$id: Request parameter cannot be optional '
                               'or named.');
    }
    var requestType = requestParam.type;
    if (requestType is! ClassMirror ||
        requestType.simpleName == #dynamic ||
        requestType.isAbstract) {
      throw new ApiConfigError('$id: API Method parameter has to be a '
                               'instantiable class.');
    }
    return requestType;
  }

  UriTemplate get template => _parser.template;

  bool matches(HttpApiRequest request) {
    UriMatch match = _parser.match(request.uri);
    if (match == null) {
      return false;
    }
    assert(match.rest.path.length == 0);
    request.pathParameters = match.parameters;
    return true;
  }

  Map get asJson {
    Map json = {
      'id': id,
      'path': path,
      'httpMethod': httpMethod.toUpperCase(),
      'description': description,
      'parameters': {},
      // TODO: query string parameters
      'parameterOrder': _pathParams,
    };
    _pathParams.forEach((param) {
      json['parameters'][param] =
        {
         // TODO: Add support for integers.
         'type'       : 'string',
         'required'   : true,
         // TODO: Make it possible to give a description for each parameter
         // in the ApiMethod annotatation.
         'description': 'Path parameter: \'${param}\'.',
         'location'   : 'path'
        };
    });
    if (_requestSchema != null && _requestSchema.hasProperties) {
      json['request'] = {
        '\$ref': _requestSchema.schemaName
      };
    }
    if (_responseSchema != null && _responseSchema.hasProperties) {
      json['response'] = {
        '\$ref': _responseSchema.schemaName
      };
    }
    return json;
  }

  Future<HttpApiResponse> invokeHttpRequest(HttpApiRequest request) {
    var positionalParams = [];
    // Add path parameters to params in the correct order.
    for (var paramName in _pathParams) {
      assert(request.pathParameters != null);
      var value = request.pathParameters[paramName];
      if (value == null) {
        return new Future.error(
            new BadRequestError('Required parameter: $paramName missing.'));
      }
      positionalParams.add(value);
    }
    // Build named parameter map for query parameters.
    var namedParams = {};
    assert(_queryParamTypes != null);
    var queryParameters = request.queryParameters;
    if (_queryParamTypes.isNotEmpty && queryParameters != null) {
      for (var queryParamName in queryParameters.keys) {
        Symbol querySymbol = _queryParamTypes[queryParamName];
        if (querySymbol != null) {
          return new Future.error(new BadRequestError(
              'Invalid request, no parameter named: $queryParamName.'));
        }
        // TODO: Check for duplicates. Currently latest dup wins.
        namedParams[querySymbol] = queryParameters[queryParamName];
      }
    }
    var apiResult;
    if (_bodyLessMethods.contains(httpMethod)) {
      apiResult = invokeNoBody(request, positionalParams, namedParams);
    } else {
      apiResult = invokeWithBody(request, positionalParams, namedParams);
    }
    return apiResult.then((value) {
      var result;
      if (_responseSchema != null && value != null &&
          _responseSchema.hasProperties) {
        // TODO: Support other encodings.
        var jsonResult = _responseSchema.toResponse(value);
        var encodedResultIterable = [_jsonToBytes.convert(jsonResult)];
        result = new Stream.fromIterable(encodedResultIterable);
      } else {
        // Return an empty stream.
        result = new Stream.fromIterable([]);
      }
      var headers = {
        HttpHeaders.CONTENT_TYPE: request.contentType,
        HttpHeaders.CACHE_CONTROL: 'no-cache, no-store, must-revalidate',
        HttpHeaders.PRAGMA: 'no-cache',
        HttpHeaders.EXPIRES: '0'
      };
      return new HttpApiResponse(HttpStatus.OK, result, headers: headers);
    });
  }

  Future<dynamic> invokeNoBody(HttpApiRequest request,
                               List positionalParams,
                               Map namedParams) {
    // Drain the request body just in case.
    return request.body.drain().then((_) {
      request.bodyProcessed = true;
      try {
        var result =
            _instance.invoke(symbol, positionalParams, namedParams).reflectee;
        return result;
      } catch (error) {
        // We explicitly catch exceptions thrown by the invoke method, otherwise
        // these exceptions would be shown as 500 Unknown API Error since we
        // cannot distinguish them from e.g. an internal null pointer exception.
        return new Future.error(new ApplicationError(error));
      };
    });
  }

  Future<dynamic> invokeWithBody(HttpApiRequest request,
                                 List positionalParams,
                                 Map namedParams) {
    // Decode request body parameters to json.
    // TODO: support other encodings
    return request.body.transform(_bytesToJson).first.then((bodyParams) {
      request.bodyProcessed = true;
      if (_requestSchema != null && _requestSchema.hasProperties) {
        // The request schema is the last positional parameter, so just adding
        // it to the list of position parameters.
        positionalParams.add(_requestSchema.fromRequest(bodyParams));
      }
      try {
        var result =
            _instance.invoke(symbol, positionalParams, namedParams).reflectee;
        return result;
      } catch (error) {
        // We explicitly catch exceptions thrown by the invoke method, otherwise
        // these exceptions would be shown as 500 Unknown API Error since we
        // cannot distinguish them from e.g. an internal null pointer exception.
        return new Future.error(new ApplicationError(error));
      }
    });
  }
}
