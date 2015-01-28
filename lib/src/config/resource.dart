// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

class ApiConfigResource {
  final String name;
  final Map<String, ApiConfigResource> _resources;
  final List<ApiConfigMethod> _methods;

  ApiConfigResource(this.name, this._resources, this._methods);

  Map<String, discovery.RestMethod> get _methodsAsDiscovery {
    var methods = new Map<String, discovery.RestMethod>();
    _methods.forEach((method) => methods[method.name] = method.asDiscovery);
    return methods;
  }

  Map<String, discovery.RestResource> get _resourcesAsDiscovery {
    var resources = new Map<String, discovery.RestResource>();
    _resources.values.forEach(
        (resource) => resources[resource.name] = resource.asDiscovery);
    return resources;
  }

  discovery.RestResource get asDiscovery {
    var resource = new discovery.RestResource();
    resource..resources = _resourcesAsDiscovery
            ..methods = _methodsAsDiscovery;
    return resource;
  }
}
