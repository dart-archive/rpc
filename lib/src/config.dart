// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library endpoints.config;

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
