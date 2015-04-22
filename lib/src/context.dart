// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.context;

import 'package:gcloud/service_scope.dart' as ss;

const INVOCATION_CONTEXT = #rpc.invocationContext;

InvocationContext get context => ss.lookup(INVOCATION_CONTEXT);

// Invocation context used to give access to the current request information
// in the invoked api methods.
class InvocationContext {
  final Map<String, dynamic> requestHeaders;
  final Uri requestUri;

  InvocationContext(this.requestHeaders, this.requestUri);

  String get baseUrl {
    var url = requestUri.toString();
    return url.substring(0, url.indexOf(requestUri.path));
  }
}
