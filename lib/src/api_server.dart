library endpoints.api_server;

import 'errors.dart';
import 'auth.dart';
import 'api_config.dart';

import 'package:shelf/shelf.dart';
import 'dart:async';
import 'dart:convert' show JSON;

import 'package:appengine/appengine.dart';

const _logLevelMap = const {
  'debug': LogLevel.DEBUG,
  'info': LogLevel.INFO,
  'warning': LogLevel.WARNING,
  'error': LogLevel.ERROR,
  'criticial': LogLevel.CRITICAL
};

class ApiServer {

  List<ApiConfig> _apis = [];
  Cascade _cascade;

  static final _cascadeResponse = new Response(501);
  static Response get cascadeResponse => _cascadeResponse;

  ApiServer() {
    _cascade = new Cascade(statusCodes: [501])
      .add(_getApiConfigs)
      .add(_logMessages)
      .add(_executeApiMethod);
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

  _logMessages(Request request) {
    if (request.method != 'POST') {
      return _cascadeResponse;
    }
    if (request.url.toString() != '/_ah/spi/BackendService.logMessages') {
      return _cascadeResponse;
    }

    Completer completer = new Completer();

    request.readAsString().then((value) {
      context.services.logging.debug('logMessages request: $value');
      List messages = JSON.decode(value)['messages'];
      messages.forEach((Map message) {
        context.services.logging.log(_logLevelMap[message['level']], message['message']);
      });

      completer.complete(new Response.ok(''));
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

    ApiConfig api = null;
    var method = request.url.pathSegments.last;
    for (var a in _apis) {
      if (a.isValid && a.canHandleCall(method)) {
        api = a;
        break;
      }
    }
    if (api == null) {
      return new NotFoundError('No configured API can handle this request').response;
    }

    Completer completer = new Completer();

    request.readAsString().then((value) {
      context.services.logging.debug('Request: $value');

      var requestMap;
      try {
        requestMap = JSON.decode(value);
      } on FormatException catch (e) {
        completer.complete(
          new BadRequestError('Request data couldn\'t be decoded').response
        );
      }

      checkAuth(request.headers, api.clientIds)
        .then((user) {
          api.handleCall(method, requestMap, user)
            .then((response) {
              print('Call handled.');
              completer.complete(new Response.ok(JSON.encode(response), headers: {'Content-Type' : 'application/json'}));
            })
            .catchError((e) {
              if (e is EndpointsError) {
                completer.complete(e.response);
              } else {
                completer.complete(new InternalServerError('Unknown API Error: $e').response);
              }
              return true;
            });
        })
        .catchError((e) {
          if (e is EndpointsError) {
            completer.complete(e.response);
          } else {
            completer.complete(new InternalServerError('Unknown User Authentication Error: $e').response);
          }
          return true;
        });
    });

    return completer.future;
  }

  Handler get handler => _cascade.handler;

  void addApi(api) {
    _apis.add(new ApiConfig(api));
  }
}
