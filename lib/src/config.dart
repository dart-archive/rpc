// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library endpoints.config;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';
import 'package:crypto/crypto.dart';
import 'package:uri/uri.dart';

import 'annotations.dart';
import 'errors.dart';
import 'message.dart';

part 'config/api.dart';
part 'config/method.dart';
part 'config/property.dart';
part 'config/resource.dart';
part 'config/schema.dart';
part 'config/utils.dart';


class ApiConfigError extends Error {
  final String message;
  ApiConfigError(this.message);
  String toString() => message;
}
