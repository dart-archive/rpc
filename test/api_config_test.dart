import 'package:unittest/unittest.dart';

import 'package:endpoints/endpoints.dart';
import 'package:endpoints/src/api_config.dart';

import 'dart:async';
import 'dart:mirrors';

class Misconfig1 extends Api {
  @ApiMethod()
  void missingAnnotations1() {}

  @ApiMethod(name: 'test1')
  void missingAnnotations2() {}

  @ApiMethod(path: 'test2')
  void missingAnnotations3() {}

  @ApiMethod(name: 'test3', path: 'test3')
  VoidMessage doubleUser(ApiUser user1, [ApiUser user2]) { return null; }

  @ApiMethod(name: 'test4', path: 'test4')
  VoidMessage wrongOrder(ApiUser user1, TestMessage1 request) { return null;}

  @ApiMethod(name: 'test5', path: 'test5')
  VoidMessage wrongParameter(String test) { return null; }

  @ApiMethod(name: 'test6', path: 'test6')
  bool wrongResponse(VoidMessage _) {
    return true;
  }

  @ApiMethod(name: 'test7', path: 'test7')
  Future<bool> wrongFutureResponse(VoidMessage ) {
    return new Future.value(true);
  }

  @ApiMethod(name: 'test8', path: 'test8')
  Future genericFutureResponse(VoidMessage _) {
    return new Future.value(true);
  }

  @ApiMethod(name: 'test9', path: 'test9/{id}')
  VoidMessage missingPathParam1(VoidMessage _) { return null; }

  @ApiMethod(name: 'test10', path: 'test10/{id}')
  VoidMessage missingPathParam2(TestMessage1 request) { return null; }

  @ApiMethod(name: 'test11', path: 'test11')
  void voidResponse(VoidMessage _) {}

  @ApiMethod(name: 'test12', path: 'test12')
  VoidMessage noRequest() { return null; }

  @ApiMethod(name: 'test13', path: 'test13')
  VoidMessage genericRequest(request) { return null; }
}

class CorrectMethods extends Api {
  @ApiMethod(name: 'test1', path: 'test1')
  VoidMessage method1(VoidMessage _) { return null; }

  @ApiMethod(name: 'test2', path: 'test2')
  TestMessage1 method2(VoidMessage _) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test3', path: 'test3')
  TestMessage1 method3(TestMessage1 request) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test4', path: 'test4')
  TestMessage1 method4(TestMessage1 request, [ApiUser user]) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test5', path: 'test5')
  TestMessage1 method5(TestMessage1 request, ApiUser user) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test6', path: 'test6')
  TestMessage1 method6(VoidMessage _, ApiUser user) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test7', path: 'test7')
  TestMessage1 method7(VoidMessage _, [ApiUser user]) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test8', path: 'test8/{count}')
  TestMessage1 method8(TestMessage1 request) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test9', path: 'test9')
  Future<TestMessage1> method9(VoidMessage _) {
    return new Future.value(new TestMessage1());
  }

  @ApiMethod(name: 'test10', path: 'test10')
  Future<VoidMessage> method10(VoidMessage _) {
    return new Future.value(new VoidMessage());
  }

  @ApiMethod(name: 'test11', path: 'test11/{submessage.count}')
  TestMessage1 method11(TestMessage1 request) {
    return new TestMessage1();
  }
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
    test('correct', () {
      var test_mirror = reflectClass(CorrectMethods);
      var tester = new ApiConfig(new Tester());
      var methods = test_mirror.declarations.values.where(
        (dm) => dm is MethodMirror &&
                dm.isRegularMethod &&
                dm.metadata.length > 0 &&
                dm.metadata.first.reflectee.runtimeType == ApiMethod
      );
      methods.forEach((MethodMirror mm) {
        expect(() => new ApiConfigMethod(mm, 'Test', tester), returnsNormally);
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
