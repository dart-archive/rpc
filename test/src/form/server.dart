library test.form.server;

import 'dart:async';
import 'dart:io';

import 'package:rpc/rpc.dart';
import 'package:logging/logging.dart';

class SimpleMessage {
  String field1;
  String field2;
}

class SimpleMixMessage {
  String field1;
  MediaMessage field2;
}

class MegaMixMessage {
  String name;
  int age;
  MediaMessage resume;
}

class MultipleFile {
  List<MediaMessage> files;
}

class MultipleFile2 {
  Map<String, MediaMessage> files;
}

@ApiClass(version: 'v1')
class TestAPI {
  @ApiResource()
  PostAPI post = new PostAPI();
}

class PostAPI {
  @ApiMethod(path: 'post/simple', method: 'POST')
  SimpleMessage test1(SimpleMessage message) {
    return message;
  }

  @ApiMethod(path: 'post/simple-mix', method: 'POST')
  SimpleMixMessage test2(SimpleMixMessage message) {
    return message;
  }

  @ApiMethod(path: 'post/mega-mix', method: 'POST')
  MegaMixMessage test3(MegaMixMessage message) {
    return message;
  }

  @ApiMethod(path: 'post/collection/list', method: 'POST')
  MultipleFile test4(MultipleFile message) {
    return message;
  }

  @ApiMethod(path: 'post/collection/map', method: 'POST')
  MultipleFile2 test5(MultipleFile2 message) {
    return message;
  }
}

Future main() async {
//  Logger.root.level = Level.ALL;
//  Logger.root.onRecord.listen((LogRecord rec) {
//    print('${rec.level.name}: ${rec.time}: ${rec.message}');
//  });

  ApiServer _apiServer = new ApiServer(apiPrefix: '', prettyPrint: true);
  _apiServer.enableDiscoveryApi();
  _apiServer.addApi(new TestAPI());

  final server = await HttpServer.bind(InternetAddress.ANY_IP_V4, 4242);
  server.listen((HttpRequest request) {
    _apiServer.httpRequestHandler(request);
  });
}
