// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfigResource {
  final String name;
  final Map<String, ApiConfigResource> _resources = {};
  final List<ApiConfigMethod> _methods = [];

  factory ApiConfigResource(InstanceMirror resourceInstance,
                            ApiResource metadata,
                            String defaultName,
                            ApiConfig api) {
    var name = defaultName;
    if (metadata != null && metadata.name != null && metadata.name.isNotEmpty) {
      name = metadata.name;
    }
    return new ApiConfigResource._(name,
                                   api,
                                   resourceInstance,
                                   resourceInstance.type);
  }

  ApiConfigResource._(this.name,
                      ApiConfig api,
                      InstanceMirror resourceInstance,
                      ClassMirror resourceClass) {
    var id = MirrorSystem.getName(resourceClass.simpleName);

    // Scan for API methods and nested resources.
    List<ApiConfigResource> resources = [];
    scanApi(resourceClass, resourceInstance, id, api, _methods, resources);

    // Setup the resources and check for duplicates.
    resources.forEach((resource) {
      if (_resources.containsKey(resource.name)) {
        api.addError(new ApiConfigError('$id: Duplicate resource with name: '
                                        '${resource.name}'));
        return;
      }
      _resources[resource.name] = resource;
    });

    // Add all methods to the api.
    _methods.forEach((m) => api.addMethod(m));
  }

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
