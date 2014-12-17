library endpoints.api_config;

import 'dart:async';
import 'dart:mirrors';
import 'dart:convert' show JSON;

import 'annotations.dart';
import 'errors.dart';

part 'config/api.dart';
part 'config/method.dart';
part 'config/schema.dart';
part 'config/property.dart';


class ApiConfigError extends Error {
  final String message;
  ApiConfigError(this.message);
  String toString() => message;
}
