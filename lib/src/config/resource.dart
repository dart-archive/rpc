// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfigResource {
  final String name;
  final Map<String, ApiConfigResource> _resources;
  final List<ApiConfigMethod> _methods;

  ApiConfigResource(this.name, this._resources, this._methods);

  Map get asJson {
    Map json = {
      'methods': {},
      'resources': {}
    };
    _methods.forEach((method) {
      json['methods'][method.name] = method.asJson;
    });
    _resources.values.forEach((resource) {
      json['resources'][resource.name] = resource.asJson;
    });
    return json;
  }
}
