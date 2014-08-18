import 'package:unittest/unittest.dart';

import 'package:endpoints/endpoints.dart';
import 'package:endpoints/src/api_config.dart';

import 'dart:async';
import 'dart:mirrors';

class Misconfig1 {
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

class CorrectMethods {
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
class Misconfig2 {}

@ApiClass(name: 'test')
class Misconfig3 {}

@ApiClass(version: 'test')
class Misconfig4 {}

@ApiClass(name: 'Tester', version: 'v1test')
class Tester {}

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
  DateTime date;
  List<String> messages;
  TestMessage2 submessage;
  List<TestMessage2> submessages;

  TestMessage1({this.count});
}

class TestMessage2 extends ApiMessage {
  int count;
}

class TestMessage3 extends ApiMessage {
  @ApiProperty(variant: 'int64')
  int count64;

  @ApiProperty(variant: 'uint64')
  int count64u;

  @ApiProperty(variant: 'int32')
  int count32;

  @ApiProperty(variant: 'uint32')
  int count32u;
}

main () {
  group('api_config', () {
    test('misconfig', () {
      List _misconfig_apis = [new Misconfig1(), new Misconfig2(), new Misconfig3(), new Misconfig4()];
      _misconfig_apis.forEach((api) {
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

    test('variants', () {
      var tester = new ApiConfig(new Tester());
      var message = new ApiConfigSchema(reflectClass(TestMessage3), tester);
      var instance = message.fromRequest({'count32': 1, 'count32u': 2, 'count64': '3', 'count64u': '4'});
      expect(instance.count32, 1);
      expect(instance.count32u, 2);
      expect(instance.count64, 3);
      expect(instance.count64u, 4);
      var json = message.toResponse(instance);
      expect(json['count32'], 1);
      expect(json['count32u'], 2);
      expect(json['count64'], '3');
      expect(json['count64u'], '4');
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
        'messages': ['1', '2', '3'],
        'date': '2014-01-23T11:12:13.456Z',
        'submessage': {
          'count': 4
        },
        'submessages': [
          {'count': 5},
          {'count': 6},
          {'count': 7}
        ]
      });
      expect(instance, new isInstanceOf<TestMessage1>());
      expect(instance.count, 1);
      expect(instance.message, 'message');
      expect(instance.value, 12.3);
      expect(instance.messages, ['1', '2', '3']);
      expect(instance.date.isUtc, true);
      expect(instance.date.year, 2014);
      expect(instance.date.month, 1);
      expect(instance.date.day, 23);
      expect(instance.date.hour, 11);
      expect(instance.date.minute, 12);
      expect(instance.date.second, 13);
      expect(instance.date.millisecond, 456);
      expect(instance.submessage, new isInstanceOf<TestMessage2>());
      expect(instance.submessage.count, 4);
      expect(instance.submessages, new isInstanceOf<List<TestMessage2>>());
      expect(instance.submessages.length, 3);
      expect(instance.submessages[0].count, 5);
      expect(instance.submessages[1].count, 6);
      expect(instance.submessages[2].count, 7);
    });

    test('bad-request-creation', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage1), tester);
      expect(() => m1.fromRequest({'count': 'x'}), throwsA(new isInstanceOf<ApiBadRequestException>()));
      expect(() => m1.fromRequest({'date': 'x'}), throwsA(new isInstanceOf<ApiBadRequestException>()));
      expect(() => m1.fromRequest({'value': 'x'}), throwsA(new isInstanceOf<ApiBadRequestException>()));
      expect(() => m1.fromRequest({'messages': 'x'}), throwsA(new isInstanceOf<ApiBadRequestException>()));
      expect(() => m1.fromRequest({'submessage': 'x'}), throwsA(new isInstanceOf<ApiBadRequestException>()));
      expect(() => m1.fromRequest({'submessage': {'count': 'x'}}), throwsA(new isInstanceOf<ApiBadRequestException>()));
      expect(() => m1.fromRequest({'submessages': ['x']}), throwsA(new isInstanceOf<ApiBadRequestException>()));
      expect(() => m1.fromRequest({'submessages': [{'count': 'x'}]}), throwsA(new isInstanceOf<ApiBadRequestException>()));
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
      var date = new DateTime.now();
      var utcDate = date.toUtc();
      instance.date = date;
      var instance2 = new TestMessage2();
      instance2.count = 4;
      instance.submessage = instance2;
      var instance3 = new TestMessage2();
      instance3.count = 5;
      var instance4 = new TestMessage2();
      instance4.count = 6;
      var instance5 = new TestMessage2();
      instance5.count = 7;
      instance.submessages = [instance3, instance4, instance5];

      var response = m1.toResponse(instance);
      expect(response, new isInstanceOf<Map>());
      expect(response['count'], 1);
      expect(response['message'], 'message');
      expect(response['value'], 12.3);
      expect(response['check'], true);
      expect(response['messages'], ['1', '2', '3']);
      expect(response['date'], utcDate.toIso8601String());
      expect(response['submessage'], new isInstanceOf<Map>());
      expect(response['submessage']['count'], 4);
      expect(response['submessages'], new isInstanceOf<List>());
      expect(response['submessages'].length, 3);
      expect(response['submessages'][0]['count'], 5);
      expect(response['submessages'][1]['count'], 6);
      expect(response['submessages'][2]['count'], 7);
    });
  });
}
