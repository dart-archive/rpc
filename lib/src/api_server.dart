library endpoints.api_server;

import 'api.dart';

import 'package:shelf/shelf.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert' show JSON;
import 'dart:mirrors';

import 'package:appengine/appengine.dart';

class ApiInfo {
  Type _apiClass;
  String name;
  String version;
  String description;
  
  ApiInfo(Api api) {
    _apiClass = api.runtimeType;
    ClassMirror apiMirror = reflectClass(_apiClass);
    ApiClass metaData = apiMirror.metadata.first.reflectee;
    name = metaData.name;
    version = metaData.version;
    description = metaData.description; 
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
    json['name'] = name;
    json['version'] = version;
    json['description'] = description;
    json['defaultVersion'] = 'true';
    json['abstract'] = 'false';
    json['adapater'] = {
      'bns': '$root/_ah/spi',
      'type': 'lily',
      'deadline': 10.0
    };

    return json;
  }
  
  String toString() => JSON.encode(toJson());
}

class ApiServer {

  List<ApiInfo> _apis = [];
  Cascade _cascade = new Cascade();

  ApiServer() {
    _cascade = _cascade.add(_getApiConfigs);
  }
  
  _getApiConfigs(Request request) {    
    if (request.method != 'POST') {
      return new Response.notFound('');
    }
    if (request.url.toString() != '/_ah/spi/BackendService.getApiConfigs') {
      return new Response.notFound('');
    }
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
    Completer completer = new Completer();
    
    request.readAsString().then((value) {
      // TODO: check app_revision if provided in value
      context.services.logging.debug(value);
      var configs = _apis.map((apiInfo) => apiInfo.toString()).toList();
      var response = JSON.encode({'items': configs});
      completer.complete(
        new Response.ok(response, headers: {'Content-Type' : 'application/json'})
      );
    });
 
    return completer.future;
  }
  
  Handler get handler => _cascade.handler;
  
  void addApi(Api api) {
    _apis.add(new ApiInfo(api));
    // TODO create request handlers for API methods
  }

}