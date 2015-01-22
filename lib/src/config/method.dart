// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

final _jsonToBytes = JSON.encoder.fuse(UTF8.encoder);
final _bytesToJson = UTF8.decoder.fuse(JSON.decoder);

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

  ApiConfigMethod(this.id, this._instance, this.symbol, this.name, this.path,
                  this.httpMethod, this.description, this._pathParams,
                  this._queryParamTypes, this._requestSchema,
                  this._responseSchema, this._parser);

  bool matches(ParsedHttpApiRequest request) {
    UriMatch match = _parser.match(request.methodUri);
    if (match == null) {
      return false;
    }
    assert(match.rest.path.length == 0);
    request.pathParameterValues = match.parameters;
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

  Future<HttpApiResponse> invokeHttpRequest(
      ParsedHttpApiRequest request) async {
    var positionalParams = [];
    // Add path parameters to params in the correct order.
    for (var paramName in _pathParams) {
      assert(request.pathParameterValues != null);
      var value = request.pathParameterValues[paramName];
      if (value == null) {
        return httpErrorResponse(request.originalRequest,
            new BadRequestError('Required parameter: $paramName missing.'));
      }
      positionalParams.add(value);
    }
    // Build named parameter map for query parameters.
    var namedParams = {};
    // TODO: Support query parameters.
    var queryParameters = request.queryParameters;
    if (_queryParamTypes != null && queryParameters != null) {
      for (var queryParamName in queryParameters.keys) {
        Symbol querySymbol = _queryParamTypes[queryParamName];
        if (querySymbol != null) {
          // TODO: Check for duplicates. Currently latest dup wins.
          namedParams[querySymbol] = queryParameters[queryParamName];
        }
        // We ignore query parameters that doesn't match a named method
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
    } catch (error) {
      // We explicitly catch exceptions thrown by the invoke method, otherwise
      // these exceptions would be shown as 500 Unknown API Error since we
      // cannot distinguish them from e.g. an internal null pointer exception.
      return httpErrorResponse(request.originalRequest,
          new ApplicationError(error), drainRequest: false);
    }
    var result;
    if (_responseSchema != null && apiResult != null &&
        _responseSchema.hasProperties) {
      // TODO: Support other encodings.
      var jsonResult = _responseSchema.toResponse(apiResult);
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
    // Decode request body parameters to json.
    // TODO: support other encodings
    var decodedRequest = await requestBody.transform(_bytesToJson).first;
    if (_requestSchema != null && _requestSchema.hasProperties) {
      // The request schema is the last positional parameter, so just adding
      // it to the list of position parameters.
      positionalParams.add(_requestSchema.fromRequest(decodedRequest));
    }
    return _instance.invoke(symbol, positionalParams, namedParams).reflectee;
  }
}
