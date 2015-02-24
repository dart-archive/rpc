// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.config;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:uri/uri.dart';

import 'errors.dart';
import 'message.dart';
import 'utils.dart';
import 'discovery/config.dart' as discovery;

part 'config/api.dart';
part 'config/method.dart';
part 'config/property.dart';
part 'config/resource.dart';
part 'config/schema.dart';

class ApiConfigError extends Error {
  final String message;
  ApiConfigError(this.message);

  String toString() => message;
}

class ParsedHttpApiRequest {

  /// The original request given as input.
  final HttpApiRequest originalRequest;

  final Converter<Object, dynamic> jsonToBytes;

  // The first two segments of the request path is the api name and
  // version. The key is '/name/version'.
  // The method path is the remaining path segments.
  final String apiKey;

  // Key for looking up the method group targetted by the request.
  // The key is the HTTP method followed by the number of method path segments.
  final String methodKey;

  // The method path uri for this request.
  final Uri methodUri;

  // A map from path parameter name to path parameter value.
  Map<String, String> pathParameters;

  factory ParsedHttpApiRequest(HttpApiRequest request,
                               Converter<Object, dynamic> jsonToBytes) {
    var path = request.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    var pathSegments = path.split('/');
    // All HTTP api request paths must be of the form:
    //   /<apiName>/<apiVersion>/<method|resourceName>[/...].
    // Hence the number of path segments must be at least three for a valid
    // request.
    if (pathSegments.length < 3) {
      throw new BadRequestError(
          'Invalid request, missing API name and ' 'version: ${request.path}.');
    }
    var apiKey = '/${pathSegments[0]}/${pathSegments[1]}';
    var methodPathSegments = pathSegments.skip(2);
    var methodKey = '${request.httpMethod}${methodPathSegments.length}';
    var methodUri = Uri.parse(methodPathSegments.join('/'));
    return new ParsedHttpApiRequest._(request, apiKey, methodKey, methodUri,
                                      jsonToBytes);
  }

  ParsedHttpApiRequest._(this.originalRequest, this.apiKey,
                         this.methodKey, this.methodUri, this.jsonToBytes);

  String get httpMethod => originalRequest.httpMethod;

  String get path => originalRequest.path;

  Map<String, String> get queryParameters => originalRequest.queryParameters;

  String get contentType => originalRequest.contentType;

  Stream<List<int>> get body => originalRequest.body;
}

/// Helper class describing a method parameter.
class ApiParameter {
  final String name;
  final Symbol symbol;
  final bool isInt;

  ApiParameter(this.name, ParameterMirror pm)
      : this.symbol = pm.simpleName, isInt = pm.type == reflectType(int);
}
