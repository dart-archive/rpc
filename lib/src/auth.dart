library endpoints.auth;

import 'api.dart' show ApiUser;
import 'errors.dart';
import 'dart:async';

import 'package:appengine/appengine.dart';
import 'package:googleapis/oauth2/v2.dart';
import 'package:http/http.dart';


List<String> _authSchemes = ['OAUTH', 'BEARER'];

Future<ApiUser> checkAuth(String authHeader, List<String> clientIds) {
  if (authHeader == null || authHeader == '') {
    return new Future.value(null);
  }
  if (clientIds == null || clientIds.length == 0) {
    context.services.logging.info('No Client IDs specified, authorization won\'t be checked.');
    return new Future.value(null);
  }
  var auth_parts = authHeader.split(' ');
  if (auth_parts.length != 2) {
    context.services.logging.error('Invalid Authorization header');
    return new Future.error(new UnauthorizedError('Invalid Authorization header'));
  }
  if (!_authSchemes.contains(auth_parts[0].toUpperCase())) {
    context.services.logging.error('Invalid Authorization header');
    return new Future.error(new UnauthorizedError('Invalid Authorization header'));
  }

  var httpClient = new IOClient();
  var apiClient = new Oauth2Api(httpClient);
  var token = auth_parts[1];
  var completer = new Completer();
  var request;
  if (token.startsWith('ya29.') || token.startsWith('1/')) {
    context.services.logging.info('Checking access token');
    request = apiClient.tokeninfo(accessToken: token);
  } else {
    // TODO: check the jwt token directly?
    context.services.logging.info('Checking ID token');
    request = apiClient.tokeninfo(idToken: token);
  }
  request
    .then((Tokeninfo info) {
      httpClient.close();
      context.services.logging.debug('Token Info retrieved successfully: ${info.toString()}');
      if (!clientIds.contains(info.issuedTo)) {
        context.services.logging.info('Client ID not allowed for this API');
        completer.complete(null);
        return;
      }
      // TODO: memcache the result for quicker future results? potential security issue?
      completer.complete(new ApiUser(info.userId, info.email));
    })
    .catchError((e) {
      httpClient.close();
      context.services.logging.error('Failed to verify authorization token: $e');
      completer.completeError(new UnauthorizedError('Failed to verify authorization token: $e'));
      return true;
    });

  return completer.future;
}