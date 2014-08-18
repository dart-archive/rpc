library endpoints.auth;

import 'api.dart' show ApiUser;
import 'errors.dart';
import 'dart:async';

import 'package:appengine/appengine.dart';
import 'package:google_oauth2_v2_api/oauth2_v2_api_console.dart';
import 'package:google_oauth2_v2_api/oauth2_v2_api_client.dart';

List<String> _authSchemes = ['OAUTH', 'BEARER'];

Future<ApiUser> checkAuth(Map<String, String> headers) {
  var auth_header = headers['Authorization'];
  if (auth_header == null) {
    return new Future.value(null);
  }
  var auth_parts = auth_header.split(' ');
  if (auth_parts.length != 2) {
    context.services.logging.error('Invalid Authorization header');
    return new Future.error(new ApiUnauthorizedException('Invalid Authorization header'));
  }
  if (!_authSchemes.contains(auth_parts[0].toUpperCase())) {
    context.services.logging.error('Invalid Authorization header');
    return new Future.error(new ApiUnauthorizedException('Invalid Authorization header'));
  }

  var client = new Oauth2();
  var token = auth_parts[1];
  var completer = new Completer();
  var request;
  if (token.startsWith('ya29.') || token.startsWith('1/')) {
    context.services.logging.info('Checking access token');
    request = client.tokeninfo(access_token: token);
  } else {
    // TODO: check the jwt token directly?
    context.services.logging.info('Checking ID token');
    request = client.tokeninfo(id_token: token);
  }
  request
    .then((Tokeninfo info) {
      // TODO: check if info.issued_to matches allowed client_ids
      // TODO: memcache the result for quicker future results? potential security issue?
      context.services.logging.debug('Token Info retrieved successfully: ${info.toString()}');
      completer.complete(new ApiUser(info.user_id, info.email));
    })
    .catchError((e) {
      context.services.logging.error('Failed to verify authorization token: $e');
      completer.completeError(new ApiUnauthorizedException('Failed to verify authorization token: $e'));
      return true;
    });

  return completer.future;
}