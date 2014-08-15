library endpoints.api_server;

import 'api.dart';
import 'api_config.dart';

import 'package:shelf/shelf.dart';
import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io' show Platform;

import 'package:appengine/appengine.dart';

class ApiServer {

  List<ApiConfig> _apis = [];
  Cascade _cascade;

  static final _cascadeResponse = new Response(501);
  static Response get cascadeResponse => _cascadeResponse;
  static bool checkCascade(Response r) => (r == _cascadeResponse);

  ApiServer() {
    _cascade = new Cascade(shouldCascade: checkCascade).add(_getApiConfigs).add(_executeApiMethod);
  }

  _getApiConfigs(Request request) {
    if (request.method != 'POST') {
      return _cascadeResponse;
    }
    if (request.url.toString() != '/_ah/spi/BackendService.getApiConfigs') {
      return _cascadeResponse;
    }

    Completer completer = new Completer();

    request.readAsString().then((value) {
      // TODO: check app_revision if provided in value
      context.services.logging.debug('getApiConfigs request: $value');
      context.services.modules.hostname().then((root) {
        root = root.replaceFirst('.', '-dot-');
        var configs = new List<String>();
        _apis.forEach((apiInfo) {
          if (apiInfo.isValid) {
            configs.add(apiInfo.toString(root));
          } else {
            context.services.logging.error(apiInfo.errors);
          }
        });
        var response = JSON.encode({'items': configs});
        completer.complete(
          new Response.ok(response, headers: {'Content-Type' : 'application/json'})
        );
      });
    });

    return completer.future;
  }

  _executeApiMethod(Request request) {
    if (request.method != 'POST') {
      return _cascadeResponse;
    }
    if (!request.url.toString().startsWith('/_ah/spi/')) {
      return _cascadeResponse;
    }

    var headers = {'Content-Type' : 'application/json'};

    var api = null;
    var method = request.url.pathSegments.last;
    for (var a in _apis) {
      if (a.isValid && a.canHandleCall(method)) {
        api = a;
        break;
      }
    }
    if (api == null) {
      return new Response.notFound(new ApiError(404, 'Not found.').toString(), headers: headers);
    }

    Completer completer = new Completer();

    request.readAsString().then((value) {
      context.services.logging.debug('Request: $value');
      context.services.logging.debug('Headers: ${JSON.encode(request.headers)}');

      var requestMap;
      try {
        requestMap = JSON.decode(value);
      } on FormatException catch (e) {
        completer.complete(
          new Response.notFound(
            new ApiError(
              400,
              'Bad Request',
              'Request data couldn\'t be decoded'
            ).toString(),
            headers: headers
          )
        );
      }

      api.handleCall(method, requestMap)
        .then((response) => completer.complete(new Response.ok(JSON.encode(response), headers: headers)))
        .catchError((e) {
          print("HandleCall Error: $e");
          if (e is ApiError) {
            completer.complete(new Response(e.code, body: e.toString(), headers: headers));
          } else {
            completer.complete(new Response(500, body: new ApiError(500, 'Unknown Error', 'Unknown Error').toString(), headers: headers));
          }
          return true;
        });
    });

    return completer.future;
  }

  Handler get handler => _cascade.handler;

  void addApi(Api api) {
    _apis.add(new ApiConfig(api));
  }
}
