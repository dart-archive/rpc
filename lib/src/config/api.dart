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

  discovery.RestDescription generateDiscoveryDocument(String baseUrl,
                                                      String apiPrefix) {
    String servicePath;
    if (!baseUrl.endsWith('/')) {
      baseUrl = '$baseUrl/';
    }
    if (apiPrefix != null && apiPrefix.isNotEmpty) {
      if (apiPrefix.startsWith('/')) {
        apiPrefix = apiPrefix.substring(1);
      }
      servicePath = '$apiPrefix$apiKey/';
    } else {
      servicePath = '${apiKey.substring(1)}/';
    }
    var doc = new discovery.RestDescription();
    doc..kind = 'discovery#restDescription'
       ..discoveryVersion = 'v1'
       ..id = '$name:$_version'
       ..name = '$name'
       ..version = _version
       ..revision = '0'
       ..protocol = 'rest'
       ..baseUrl = '$baseUrl$servicePath'
       ..basePath = '/$servicePath'
       ..rootUrl = baseUrl
       ..servicePath = servicePath
       ..parameters = {}
       ..schemas = _schemasAsDiscovery
       ..methods = _methodsAsDiscovery
       ..resources = _resourcesAsDiscovery;
    if (_title != null) {
      doc.title = _title;
    }
    if (_description != null) {
      doc.description = _description;
    }
    // TODO: Figure out the best way to compute the sha1. E.g. update toString
    // to change as needed when (nested) fields change.
    var sha1 = new SHA1();
    sha1.add(UTF8.encode(doc.toString()));
    doc.etag = CryptoUtils.bytesToHex(sha1.close());
    return doc;
  }

  Map<String, discovery.JsonSchema> get _schemasAsDiscovery {
    var schemas = new Map<String, discovery.JsonSchema>();
    _schemaMap.forEach((String name, ApiConfigSchema schema) {
      if (schema.containsData) {
        schemas[name] = schema.asDiscovery;
      }
    });
    return schemas;
  }

  discovery.DirectoryListItems get asDirectoryListItem {
    var item = new discovery.DirectoryListItems();
    // TODO: Support preferred, icons, and documentation link as part
    // of metadata.
    item..kind = 'discovery#directoryItem'
        ..id = '$name:$_version'
        ..name = name
        ..version = _version
        ..preferred = true;
    if (_title != null) {
      item.title = _title;
    }
    if (_description != null) {
      item.description = _description;
    }
    return item;
  }
}
