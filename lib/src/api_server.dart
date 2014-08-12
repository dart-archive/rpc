library endpoints.api_server;

import 'api.dart';
import 'api_config.dart';

import 'package:shelf/shelf.dart';
import 'dart:async';
import 'dart:convert' show JSON;


import 'package:appengine/appengine.dart';

class ApiServer {

  List<ApiConfig> _apis = [];
  Cascade _cascade;

  ApiServer() {
    _cascade = new Cascade().add(_getApiConfigs).add(_executeApiMethod);
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
      var configs = new List<String>();
      _apis.forEach((apiInfo) {
        if (apiInfo.isValid) {
          configs.add(apiInfo.toString());
        } else {
          context.services.logging.error(apiInfo.errors);
        }
      });
      var response = JSON.encode({'items': configs});
      completer.complete(
        new Response.ok(response, headers: {'Content-Type' : 'application/json'})
      );
    });

    return completer.future;
  }

  _executeApiMethod(Request request) {
    if (request.method != 'POST') {
      return new Response.notFound('Not found.');
    }
    if (!request.url.toString().startsWith('/_ah/spi/')) {
      return new Response.notFound('Not found.');
    }

    Completer completer = new Completer();

    request.readAsString().then((value) {
      context.services.logging.debug(value);
      // TODO:
      // Find API that can execute this request
      // Execute request and wait for reply
      // return response or notfound otherwise
      completer.complete(new Response.notFound('Not implemented yet.'));
    });

    return completer.future;
  }

  Handler get handler => _cascade.handler;

  void addApi(Api api) {
    _apis.add(new ApiConfig(api));
  }
}