library endpoints.api_config;

import 'api.dart';

import 'dart:async';
import 'dart:mirrors';
import 'dart:convert' show JSON;

part 'api_config/api.dart';
part 'api_config/method.dart';
part 'api_config/schema.dart';
part 'api_config/property.dart';


class ApiConfigError extends Error {
  final String message;
  ApiConfigError(this.message);
  String toString() => message;
}
