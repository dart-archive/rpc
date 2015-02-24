// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

final _bytesToJson = UTF8.decoder.fuse(JSON.decoder);

class ApiConfigMethod {
  final Symbol symbol;
  final String id;
  final String name;
  final String path;
  final String httpMethod;
  final String description;

  final InstanceMirror _instance;
  final List<ApiParameter> _pathParams;
  final List<ApiParameter> _queryParams;
  final ApiConfigSchema _requestSchema;
  final ApiConfigSchema _responseSchema;
  final UriParser _parser;

  ApiConfigMethod(this.id, this._instance, this.symbol, this.name, this.path,
                  this.httpMethod, this.description, this._pathParams,
                  this._queryParams, this._requestSchema,
                  this._responseSchema, this._parser);

  bool matches(ParsedHttpApiRequest request) {
    UriMatch match = _parser.match(request.methodUri);
    if (match == null) {
      return false;
    }
    assert(match.rest.path.length == 0);
    request.pathParameters = match.parameters;
    return true;
  }

  discovery.RestMethod get asDiscovery {
    var method = new discovery.RestMethod();
    method..id = id
          ..path = path
          ..httpMethod = httpMethod.toUpperCase()
          ..description = description
          ..parameterOrder = _pathParams.map((param) => param.name).toList();
    method.parameters = new Map<String, discovery.JsonSchema>();
    _pathParams.forEach((param) {
      var schema = new discovery.JsonSchema();
      schema..type = param.isInt ? discovery.JsonSchema.PARAM_INTEGER_TYPE
                                 : discovery.JsonSchema.PARAM_STRING_TYPE
            ..required = true
            ..description = 'Path parameter: \'${param.name}\'.'
            ..location = discovery.JsonSchema.PARAM_LOCATION_PATH;
      method.parameters[param.name] = schema;
    });
    if (_queryParams != null) {
      _queryParams.forEach((param) {
        var schema = new discovery.JsonSchema();
        schema..type = param.isInt ? discovery.JsonSchema.PARAM_INTEGER_TYPE
                                   : discovery.JsonSchema.PARAM_STRING_TYPE
              ..required = false
              ..description = 'Query parameter: \'${param.name}\'.'
              ..location = discovery.JsonSchema.PARAM_LOCATION_QUERY;
        method.parameters[param.name] = schema;
      });
    }
    if (_requestSchema != null && _requestSchema.containsData) {
      method.request =
          new discovery.RestMethodRequest()..P_ref = _requestSchema.schemaName;
    }
    if (_responseSchema != null && _responseSchema.containsData) {
      method.response = new discovery.RestMethodResponse()
                            ..P_ref = _responseSchema.schemaName;
    }
    return method;
  }

  Future<HttpApiResponse> invokeHttpRequest(
      ParsedHttpApiRequest request) async {
    var positionalParams = [];
    // Add path parameters to params in the correct order.
    assert(_pathParams != null);
    assert(request.pathParameters != null);
    for (int i = 0; i < _pathParams.length; ++i) {
      var param = _pathParams[i];
      var value = request.pathParameters[param.name];
      if (value == null) {
        return httpErrorResponse(request.originalRequest,
            new BadRequestError('Required parameter: ${param.name} missing.'));
      }
      if (param.isInt) {
        try {
          positionalParams.add(int.parse(value));
        } on FormatException catch (error) {
          return httpErrorResponse(request.originalRequest,
              new BadRequestError('Invalid integer value: $value for '
                                  'path parameter: ${param.name}. '
                                  '${error.toString()}'));
        }
      } else {
        positionalParams.add(value);
      }
    }
    // Build named parameter map for query parameters.
    var namedParams = {};
    if (_queryParams != null && request.queryParameters != null) {
      for (int i = 0; i < _queryParams.length; ++i) {
        var param = _queryParams[i];
        // Check if there is a parameter value for the given name.
        var value = request.queryParameters[param.name];
        if (value != null) {
          if (param.isInt) {
            try {
              namedParams[param.symbol] = int.parse(value);
            } on FormatException catch (error) {
              return httpErrorResponse(request.originalRequest,
                  new BadRequestError('Invalid integer value: $value for '
                                      'query parameter: ${param.name}. '
                                      '${error.toString()}'));
            }
          } else {
            namedParams[param.symbol] = value;
          }
        }
        // We ignore query parameters that don't match a named method
        // parameter.
      }
    }
    var apiResult;
    try {
      if (bodyLessMethods.contains(httpMethod)) {
        apiResult = await invokeNoBody(request.body,
                                       positionalParams, namedParams);
      } else {
        apiResult =
            await invokeWithBody(request.body, positionalParams, namedParams);
      }
    } on RpcError catch (error) {
      // Catch RpcError explicitly and wrap them in the http error response.
      return httpErrorResponse(request.originalRequest, error,
                               drainRequest: false);
    } catch (error) {
      // All other exceptions thrown are caught and wrapped as ApplicationError
      // with status code 500. Otherwise these exceptions would be shown as
      // Unknown API Error since we cannot distinguish them from e.g. an
      // internal null pointer exception.
      return httpErrorResponse(request.originalRequest,
          new ApplicationError(error), drainRequest: false);
    }
    var result;
    if (_responseSchema != null && apiResult != null &&
        _responseSchema.containsData) {
      // TODO: Support other encodings.
      var jsonResult = _responseSchema.toResponse(apiResult);
      var encodedResultIterable = [request.jsonToBytes.convert(jsonResult)];
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
  }

  Future<dynamic> invokeNoBody(Stream<List<int>> requestBody,
                               List positionalParams,
                               Map namedParams) async {
    // Drain the request body just in case.
    await requestBody.drain();
    return _instance.invoke(symbol, positionalParams, namedParams).reflectee;
  }

  Future<dynamic> invokeWithBody(Stream<List<int>> requestBody,
                                 List positionalParams,
                                 Map namedParams) async {
    assert(_requestSchema != null);
    // Decode request body parameters to json.
    // TODO: support other encodings
    var decodedRequest = {};
    if (_requestSchema.containsData) {
      decodedRequest = await requestBody.transform(_bytesToJson).first;
    }
    // The request schema is the last positional parameter, so just adding
    // it to the list of position parameters.
    positionalParams.add(_requestSchema.fromRequest(decodedRequest));
    return _instance.invoke(symbol, positionalParams, namedParams).reflectee;
  }
}
