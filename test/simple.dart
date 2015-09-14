import 'dart:io';

import 'package:rpc/rpc.dart';
import 'package:logging/logging.dart';

class PostRequest {
  MediaMessage myFile;
  String field;
}

class PostRequest1 {
  String field;
}

class StringMessage {
  String message;
}

@ApiClass(version: 'v1')
class Cloud {
  @ApiMethod(path: 'method', method: 'POST')
  StringMessage method(PostRequest request) {
    print(new String.fromCharCodes(request.myFile.bytes));
    print(request.field);
    return new StringMessage()..message = 'ok';
  }

  @ApiMethod(path: 'method1', method: 'POST')
  StringMessage method1(PostRequest1 request) {
    print(request.field);
    return new StringMessage()..message = 'ok';
  }
}

main() async {
//  Logger.root.level = Level.ALL;
//  Logger.root.onRecord.listen((LogRecord rec) {
//    print('${rec.level.name}: ${rec.time}: ${rec.message}');
//  });
  var server = await HttpServer.bind(InternetAddress.ANY_IP_V4, 8080);

  var apiServer = new ApiServer();
  apiServer.addApi(new Cloud());
  apiServer.enableDiscoveryApi();

  server.listen((HttpRequest request) {
    apiServer.httpRequestHandler(request);
  });
}