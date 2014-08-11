library endpoints.api_config;

import 'api.dart';

import 'dart:io' show Platform;
import 'dart:async';
import 'dart:mirrors';
import 'dart:convert' show JSON;

class ApiConfigMethod {
  Symbol _methodName;
  String _name;
  String _path;
  String _method;
  ClassMirror _requestMessage;
  ClassMirror _responseMessage;
  
  ApiConfigMethod(MethodMirror mm) {
    ApiMethod metadata = mm.metadata.first.reflectee;
    _methodName = mm.simpleName;
    _name = metadata.name;
    _path = metadata.path;
    _method = metadata.method.toUpperCase();

    var type = mm.returnType;
    if (type.simpleName == new Symbol('void')) {
      _responseMessage = reflectType(VoidMessage);
    } else {
      if (type.isSubtypeOf(reflectType(Future))) {
        var types = type.typeArguments;
        if (types.length == 1) {
          if (types[0].simpleName != new Symbol('dynamic') && types[0].isSubtypeOf(reflectType(ApiMessage))) {
            _responseMessage = types[0];
          }
        }
      } else {
        if (type.simpleName != new Symbol('dynamic') && type.isSubtypeOf(reflectType(ApiMessage))) {
          _responseMessage = type;
        }
      }
    }
    if (_responseMessage == null) {
      throw new ArgumentError("API Method return type has to be ApiMessage or Future<ApiMessage>");
    }
    if (mm.parameters.length > 1) {
      throw new ArgumentError("API Methods can only accept at one ApiMessage as parameter");
    }
    if (mm.parameters.length == 0) {
      _requestMessage = reflectType(VoidMessage);
    } else {
      var param = mm.parameters[0];
      if (param.isNamed || param.isOptional) {
        throw new ArgumentError("API Method parameter can't be optional or named");
      }
      type = param.type;
      if (type.simpleName != new Symbol('dynamic') && type.isSubtypeOf(reflectType(ApiMessage))) {
        _requestMessage = type;
      } else {
        throw new ArgumentError("API Method parameter has to be a sub-class of ApiMessage");
      }
    }
  }
  
  ClassMirror get requestMessage => _requestMessage;
  ClassMirror get responseMessage => _responseMessage;
}

class ApiConfig {

  String _name;
  String _version;
  String _description;
  String _prefix;

  InstanceMirror _api;
  Map<String, ApiConfigMethod> _methodMap = {};

  ApiConfig(Api api) {
    _api = reflect(api);

    var apiMirror = _api.type;
    if (apiMirror.metadata.length == 0 || apiMirror.metadata.first.reflectee.runtimeType != ApiClass) {
      throw new ArgumentError("Api class needs to have @ApiClass annotation");
    }

    ApiClass metaData = apiMirror.metadata.first.reflectee;
    _name = metaData.name;
    _version = metaData.version;
    _description = metaData.description;
    _prefix = apiMirror.simpleName.toString();

    var methods = apiMirror.declarations.values.where(
      (dm) => dm is MethodMirror &&
              dm.isRegularMethod &&
              dm.metadata.length > 0 &&
              dm.metadata.first.reflectee.runtimeType == ApiMethod
    );

    methods.forEach((MethodMirror mm) {
      var method = new ApiConfigMethod(mm);
      _methodMap[mm.simpleName.toString()] = method;
    });
  }

  Map toJson() {
    Map json = {};
    // TODO: better way to determine root URL
    Map env = Platform.environment;
    String root = 'https://${env['GAE_LONG_APP_ID']}.appspot.com';
    if (env['GAE_PARTITION'] == 'dev') {
      root = 'https://localhost:${env['GAE_SERVER_PORT']}';
    }
    json['extends'] = 'thirdParty.api';
    json['root'] = '$root/_ah/api';
    json['name'] = _name;
    json['version'] = _version;
    json['description'] = _description;
    json['defaultVersion'] = 'true';
    json['abstract'] = 'false';
    json['adapter'] = {
      'bns': '$root/_ah/spi',
      'type': 'lily',
      'deadline': 10.0
    };

    return json;
  }

  String toString() => JSON.encode(toJson());
}