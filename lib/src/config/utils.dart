// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

String camelCaseName(String name) {
  return name.substring(0, 1).toLowerCase() + name.substring(1);
}

void scanApi(ClassMirror klass,
             InstanceMirror klassInstance,
             String id,
             ApiConfig api,
             List<ApiConfigMethod> methods,
             List<ApiConfigResource> resources) {
  klass.declarations.values.forEach((dm) {
    ApiConfigMethod method = _checkIfMethod(dm, klassInstance, id, api);
    if (method != null) {
      methods.add(method);
      return;
    }
    ApiConfigResource resource =
        _checkIfResource(dm, klassInstance, id, api);
    if (resource != null) {
      resources.add(resource);
      return;
    }
  });
}

ApiConfigMethod _checkIfMethod(dynamic dm,
                               InstanceMirror klassInstance,
                               String id,
                               ApiConfig api) {
  if (dm is! MethodMirror ||
      !dm.isRegularMethod ||
      dm.metadata.length == 0) {
    // Do a bit of error checking to check if someone added an ApiMethod
    // annotation on a non-method.
    dm.metadata.forEach((a) {
      if (a.reflectee.runtimeType == ApiMethod) {
        var name = MirrorSystem.getName(dm.simpleName);
        api.addError(new ApiConfigError('$id: ApiMethod annotation on '
            'a non-method declaration \'$name\''));
      }
    });
    // Ignore this declaration as it is not a regular method with at least
    // one annotation.
    return null;
  }

  var metadata = getMetadata(dm, id, api, ApiMethod);
  if (metadata == null) {
    return null;
  }

  var method;
  try {
    method = new ApiConfigMethod(dm, metadata,
                                 id, api, klassInstance);
  } on ApiConfigError catch (e) {
    api.addError(e);
    return null;
  } catch (e) {
    api.addError(
        new ApiConfigError('$id: Unknown API Config error: $e.'));
    return null;
  }
  return method;
}

ApiConfigResource _checkIfResource(DeclarationMirror dm,
                                   InstanceMirror klassInstance,
                                   String id,
                                   ApiConfig api) {
  if (dm is! VariableMirror || dm.metadata.length == 0) {
    // Do a bit of error checking to check if someone added an ApiResource
    // annotation on a non-field.
    dm.metadata.forEach((a) {
      if (a.reflectee.runtimeType == ApiResource) {
        var name = MirrorSystem.getName(dm.simpleName);
        api.addError(new ApiConfigError('$id: ApiResource annotation on '
            'a non-field declaration \'$name\''));
      }
    });
    return null;
  }

  var metadata = getMetadata(dm, id, api, ApiResource);
  if (metadata == null) {
    return null;
  }

  var resource;
  try {
    var defaultName = camelCaseName(MirrorSystem.getName(dm.simpleName));
    InstanceMirror rm = klassInstance.getField(dm.simpleName);
    resource =
        new ApiConfigResource(rm, metadata, defaultName, api);
  } on ApiConfigError catch (e) {
    api.addError(e);
    return null;
  } catch (e) {
    api.addError(
        new ApiConfigError('$id: Unknown API Config error: $e.'));
    return null;
  }
  return resource;
}

// Returns the annotation of type 'apiType' if exists and valid.
// Otherwise returns null.
dynamic getMetadata(DeclarationMirror dm,
                    String id,
                    ApiConfig api,
                    Type apiType) {
  var annotations =
      dm.metadata.where((a) => a.reflectee.runtimeType == apiType).toList();
  if (annotations.length == 0) {
    return null;
  } else if (annotations.length > 1) {
    var name = MirrorSystem.getName(dm.simpleName);
    api.addError(new ApiConfigError('$id: Multiple ${apiType} annotations '
                                    'on declaration \'$name\'.'));
    return null;
  }
  return annotations.first.reflectee;
}
