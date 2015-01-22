// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfig extends ApiConfigResource {

  final String apiKey;
  final String _version;
  final String _title;
  final String _description;

  final Map<String, ApiConfigSchema> _schemaMap;

  // Method map from {$HttpMethod$NumberOfPathSegments} to list of methods.
  // TODO: Measure method lookup and possibly change to tree structure to
  // avoid the list.
  final Map<String, List<ApiConfigMethod>> _methodMap;

  ApiConfig(this.apiKey, String name, this._version, this._title,
            this._description, Map<String, ApiConfigResource> resources,
            List<ApiConfigMethod> methods, this._schemaMap, this._methodMap)
      : super(name, resources, methods);

  Future<HttpApiResponse> handleHttpRequest(ParsedHttpApiRequest request) {
    final List<ApiConfigMethod> methods = _methodMap[request.methodKey];
    if (methods != null) {
      for (var method in methods) {
        // TODO: improve performance of this (measure first).
        if (method.matches(request)) {
          return method.invokeHttpRequest(request);
        }
      }
    }
    return httpErrorResponse(request.originalRequest, new NotFoundError(
        'No method found matching HTTP method: ${request.httpMethod} '
        'and method url path: ${request.path}.'));
  }

  Map toJson(String serverUrl, [String apiPathPrefix]) {
    String servicePath;
    if (apiPathPrefix != null) {
      servicePath = '$apiPathPrefix$apiKey/';
    } else {
      servicePath = '${apiKey.substring(1)}/';
    }
    Map json = {
      'kind': 'discovery#restDescription',
      'etag': '',
      'discoveryVersion': 'v1',
      'id': '$name:$_version',
      'name': name,
      'version': _version,
      'revision': '0',
      'title': _title == null ? name : _title,
      'description': _description == null ? '' : _description,
      // TODO: Handle icons and documentationLink fields.
      'protocol': 'rest',
      'baseUrl': '$serverUrl$servicePath',
      'basePath': '/$servicePath',
      'rootUrl': serverUrl,
      'servicePath': servicePath,
      // TODO: Handle batch requests, ie. 'batchPath'.
      // TODO: Add support for toplevel API parameters.
      'parameters': {},
      'schemas': {},
    };
    _schemaMap.values.where(
        (schema) => (schema.hasProperties)).forEach((schema) {
      json['schemas'][schema.schemaName] = schema.descriptor;
    });
    // Add methods and resources by calling the inherited asJson getter.
    json.addAll(asJson);
    // TODO: Check if this is stable or not. E.g. if the hash map is
    // deterministic.
    var sha1 = new SHA1();
    sha1.add(UTF8.encode(json.toString()));
    json['etag'] = CryptoUtils.bytesToHex(sha1.close());
    return json;
  }
}
