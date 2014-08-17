import 'package:unittest/unittest.dart';

import 'package:endpoints/endpoints.dart';
import 'package:endpoints/src/api_config.dart';

import 'dart:async';
import 'dart:mirrors';

class Misconfig1 extends Api {
  @ApiMethod()
  void missingAnnotations1() {}

  @ApiMethod(name: 'test')
  void missingAnnotations2() {}

  @ApiMethod(path: 'test')
  void missingAnnotations3() {}
}

@ApiClass()
class Misconfig2 extends Api {}

@ApiClass(name: 'test')
class Misconfig3 extends Api {}

@ApiClass(version: 'test')
class Misconfig4 extends Api {}

@ApiClass(name: 'Tester', version: 'v1test')
class Tester extends Api {}

class RecursiveMessage1 extends ApiMessage {
  String message;
  RecursiveMessage1 item;
}

class RecursiveMessage2 extends ApiMessage {
  String message;
  RecursiveMessage3 item;
}

class RecursiveMessage3 extends ApiMessage {
  String message;
  RecursiveMessage2 item;
}

class TestMessage1 extends ApiMessage {
  int count;
  String message;
  double value;
  bool check;
  List<String> messages;
  TestMessage2 submessage;
  List<TestMessage2> submessages;
  
  TestMessage1({this.count});
}

class TestMessage2 extends ApiMessage {
  int count;  
}

main () {
  group('api_config', () {
    test('misconfig', () {
      List _misconfig_apis = [new Misconfig1(), new Misconfig2(), new Misconfig3(), new Misconfig4()];
      _misconfig_apis.forEach((Api api) {
        var api_config = new ApiConfig(api);
        expect(api_config.isValid, false);  
      });
    });
    test('correct', () {
      var api_config = new ApiConfig(new Tester());
      expect(api_config.isValid, true);
      expect(api_config.toJson()['name'], 'Tester');
      expect(api_config.toJson()['version'], 'v1test');
    });
  });

  group('api_config_methods', () {
    test('misconfig', () {
      var test_mirror = reflectClass(Misconfig1);
      var tester = new ApiConfig(new Tester());
      var methods = test_mirror.declarations.values.where(
        (dm) => dm is MethodMirror &&
                dm.isRegularMethod &&
                dm.metadata.length > 0 &&
                dm.metadata.first.reflectee.runtimeType == ApiMethod
      );
      methods.forEach((MethodMirror mm) {
        expect(() => new ApiConfigMethod(mm, 'Test', tester), throwsA(new isInstanceOf<ApiConfigError>('ApiConfigError')));
      });
    });
  });
  
  group('api_config_schema', () {
    test('recursion', () {
      expect(new Future.sync(() {
        var tester = new ApiConfig(new Tester());
        var m1 = new ApiConfigSchema(reflectClass(RecursiveMessage1), tester);
      }), completes);
      expect(new Future.sync(() {
        var tester = new ApiConfig(new Tester());
        var m2 = new ApiConfigSchema(reflectClass(RecursiveMessage2), tester);
      }), completes);
      expect(new Future.sync(() {
        var tester = new ApiConfig(new Tester());
        var m3 = new ApiConfigSchema(reflectClass(RecursiveMessage3), tester);
      }), completes);
      expect(new Future.sync(() {
        var tester = new ApiConfig(new Tester());
        var m2 = new ApiConfigSchema(reflectClass(RecursiveMessage2), tester);
        var m3 = new ApiConfigSchema(reflectClass(RecursiveMessage3), tester);
      }), completes);
    });
    
    test('request-parsing', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage1), tester);
      var instance = m1.fromRequest({});
      expect(instance, new isInstanceOf<TestMessage1>());
      instance = m1.fromRequest({
        'count': 1,
        'message': 'message',
        'value': 12.3,
        'check': true,
        'messages': ['1', '2', '3']
      });
      expect(instance, new isInstanceOf<TestMessage1>());
      expect(instance.count, 1);
      expect(instance.message, 'message');
      expect(instance.value, 12.3);
      expect(instance.messages, ['1', '2', '3']);
    });
    
    test('response-creation', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage1), tester);
      var instance = new TestMessage1();
      instance.count = 1;
      instance.message = 'message';
      instance.value = 12.3;
      instance.check = true;
      instance.messages = ['1', '2', '3'];
      
      var response = m1.toResponse(instance);
      expect(response, new isInstanceOf<Map>());
      expect(response['count'], 1);
      expect(response['message'], 'message');
      expect(response['value'], 12.3);
      expect(response['check'], true);
      expect(response['messages'], ['1', '2', '3']);
    });
  });
}
