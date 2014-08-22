library endpoints.api_server;

import 'errors.dart';
import 'auth.dart';
import 'api_config.dart';

import 'package:shelf/shelf.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  static final _cascadeResponse = new Response(501);

  /**
   * 501 response that can be returned from shelf handler
   * to trigger cascading
   */
  static Response get cascadeResponse => _cascadeResponse;

  Future<Map> _handler(String method, String request, String authHeader) {
    var jsonRequest;
    try {
      jsonRequest = JSON.decode(request);
    } on FormatException catch (e) {
      return new Future.error(
        new BadRequestError('Request data couldn\'t be decoded: $e')
      );
    }
    if (method == 'BackendService.getApiConfigs') {
      return _getApiConfigs(jsonRequest);
    }
    if (method == 'BackendService.logMessages') {
      return _logMessages(jsonRequest);
    }

    return _executeApiMethod(method, jsonRequest, authHeader);
  }

  Future<Map> _getApiConfigs(Map request) {
    context.services.logging.debug('getApiConfigs request: $request');
    // TODO: check app revision in request

    return context.services.modules.hostname().then((root) {
      // TODO:
      // need to consider cases where API is running in module
      // which would need two -dot- replacements for HTTPS-safe root
      root = root.replaceFirst('.', '-dot-');
      var configs = new List<String>();
      _apis.forEach((apiInfo) {
        if (apiInfo.isValid) {
          configs.add(apiInfo.toString(root));
        } else {
          context.services.logging.error(apiInfo.errors);
        }
      });
      return {'items': configs};
    });
  }

  Future<Map> _logMessages(Map request) {
    context.services.logging.debug('logMessages request: $request');

    List messages = request['messages'];
    messages.forEach((Map message) {
      context.services.logging.log(_logLevelMap[message['level']], message['message']);
    });
    return new Future.value({});
  }

  Future<Map> _executeApiMethod(String method, Map request, String authHeader) {
    ApiConfig api = null;
    for (var a in _apis) {
      if (a.isValid && a.canHandleCall(method)) {
        api = a;
        break;
      }
    }
    if (api == null) {
      return new Future.error(new NotFoundError('No configured API can handle this request'));
    }

    Completer completer = new Completer();

    checkAuth(authHeader, api.clientIds)
      .then((user) {
        api.handleCall(method, request, user)
          .then((response) {
            completer.complete(response);
          })
          .catchError((e) {
            if (e is EndpointsError) {
              completer.completeError(e);
            } else {
              completer.completeError(new InternalServerError('Unknown API Error: $e'));
            }
            return true;
          });
      })
      .catchError((e) {
        if (e is EndpointsError) {
          completer.completeError(e);
        } else {
          completer.completeError(new InternalServerError('Unknown User Authentication Error: $e'));
        }
        return true;
      });

    return completer.future;
  }

  /**
   * A shelf handler which can be added to shelf cascades
   *
   * Will return a 501 response (instead of the default 404)
   * when it can't handle the request.
   */
  Handler get handler => (Request request) {
    if (!request.url.path.startsWith('/_ah/spi/')) {
      return _cascadeResponse;
    }
    if (request.method != 'POST') {
      return new Response(405, body: 'Method not allowed');
    }

    Completer completer = new Completer();
    request.readAsString().then((value) {
      _handler(request.url.pathSegments.last, value, request.headers['Authorization'])
        .then((response) {
          completer.complete(
            new Response.ok(
              JSON.encode(response),
              headers: {'Content-Type' : 'application/json'}
            )
          );
        })
        .catchError((e) {
          if (e is EndpointsError) {
            completer.complete(e.response);
          } else {
            completer.complete(new InternalServerError('Unknown API Error: $e').response);
          }
        });
    });

    return completer.future;
  };

  /**
   * Handle incoming HttpRequests.
   *
   * Should only be used for /_ah/spi/ request paths
   */
  void handleRequest(HttpRequest request) {
    if (!request.uri.path.startsWith('/_ah/spi')) {
      request.drain().then((_) => _errorResponse(request.response, 501, 'Not Implemented'));
      return;
    }
    if (request.method != 'POST') {
      request.drain().then((_) => _errorResponse(request.response, 405, 'Method Not Allowed'));
      return;
    }
    request.transform(UTF8.decoder).join('').then((String data) {
      _handler(request.uri.pathSegments.last, data, request.headers.value('Authorization'))
        .then((response) {
          _jsonResponse(request.response, 200, response);
        })
        .catchError((e) {
          if (e is! EndpointsError) {
            e = new InternalServerError('Unknown API Error: $e');
          }
          _jsonResponse(request.response, e.code, e.toJson());
        });
    });
  }

  void _jsonResponse(HttpResponse response, int code, Map json) {
    var data = UTF8.encode(JSON.encode(json));
    response.headers.contentType = new ContentType('application', 'json');
    response.statusCode = code;
    response.contentLength = data.length;
    response.add(data);
    response.close();
  }

  void _errorResponse(HttpResponse response, int code, String message) {
    var data = UTF8.encode(message);
    response.headers.contentType =
      new ContentType('text', 'plain', charset: 'charset=utf-8');
    response.statusCode = code;
    response.contentLength = data.length;
    response.add(data);
    response.close();
  }

  /// Add a new api implementation to the API server
  void addApi(api) {
    _apis.add(new ApiConfig(api));
  }
}
