import 'package:unittest/unittest.dart';

import 'package:endpoints/endpoints.dart';
import 'package:endpoints/src/config.dart';

import 'dart:async';
import 'dart:mirrors';

import 'src/test_api.dart';

main () {
  group('api_config_misconfig', () {
    List _misconfig_apis = [new Misconfig1(), new Misconfig2(), new Misconfig3(), new Misconfig4()];
    _misconfig_apis.forEach((api) {
      test(api.runtimeType.toString(), () {
        var api_config = new ApiConfig(api);
        expect(api_config.isValid, false);
      });
    });
  });

  group('api_config_correct', () {
    test('correct_simple', () {
      var api_config = new ApiConfig(new Tester());
      expect(api_config.isValid, true);
      expect(api_config.toJson()['name'], 'Tester');
      expect(api_config.toJson()['version'], 'v1test');
    });
    test('correct_extended', () {
      var api_config = new ApiConfig(new CorrectMethods());
      expect(api_config.isValid, true);
      var config = api_config.toJson();
      expect(config['name'], 'correct');
      expect(config['version'], 'v1');
      expect(config['methods'].keys.length, 11);
    });
  });

  group('api_config_methods', () {

    test('misconfig', () {
      var test_mirror = reflectClass(WrongMethods);
      var tester = new ApiConfig(new Tester());
      var methods = test_mirror.declarations.values.where(
        (dm) => dm is MethodMirror &&
                dm.isRegularMethod &&
                dm.metadata.length > 0 &&
                dm.metadata.first.reflectee.runtimeType == ApiMethod
      );
      methods.forEach((MethodMirror mm) {
        expect(
          () => new ApiConfigMethod(mm, 'Test', tester),
          throwsA(new isInstanceOf<ApiConfigError>('ApiConfigError'))
        );
      });
    });

    test('recursion', () {
      var test_mirror = reflectClass(ResursiveGet);
      var tester = new ApiConfig(new Tester());
      var methods = test_mirror.declarations.values.where(
        (dm) => dm is MethodMirror &&
                dm.isRegularMethod &&
                dm.metadata.length > 0 &&
                dm.metadata.first.reflectee.runtimeType == ApiMethod
      );
      methods.forEach((MethodMirror mm) {
        expect(
          () => new ApiConfigMethod(mm, 'Test', tester),
          throwsA(new isInstanceOf<ApiConfigError>('ApiConfigError'))
        );
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

    group('misconfig', () {
      List _wrong_schemas = [WrongSchema1];
      _wrong_schemas.forEach((schema) {
        test(schema.toString(), () {
          var tester = new ApiConfig(new Tester());
          expect(
            () => new ApiConfigSchema(reflectClass(schema), tester),
            throwsA(new isInstanceOf<ApiConfigError>())
          );
        });
      });

      test('double_name1', () {
        var tester = new ApiConfig(new Tester());
        new ApiConfigSchema(reflectClass(TestMessage1), tester, name: "MyMessage");
        expect(
          () => new ApiConfigSchema(reflectClass(TestMessage2), tester, name: "MyMessage"),
          throwsA(new isInstanceOf<ApiConfigError>())
        );
      });
      test('double_name2', () {
        var tester = new ApiConfig(new Tester());
        new ApiConfigSchema(reflectClass(TestMessage1), tester, name: "MyMessage");
        expect(
          () => new ApiConfigSchema(reflectClass(TestMessage1), tester, fields: ['count', 'value'], name: "MyMessage"),
          throwsA(new isInstanceOf<ApiConfigError>())
        );
      });
    });

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
      var instance = m1.fromRequest({'requiredValue': 10});
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
        ],
        'enumValue': 'test1',
        'limit': 50,
        'ignored': 10
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
      expect(instance.enumValue, 'test1');
      expect(instance.defaultValue, 10);
      expect(instance.ignored, null);
    });

    test('required', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage4), tester);
      expect(() => m1.fromRequest({'requiredValue': 1}), returnsNormally);
    });

    test('bad-request-creation', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage1), tester);
      var requests = [
        {'count': 'x'},
        {'date': 'x'},
        {'value': 'x'},
        {'messages': 'x'},
        {'submessage': 'x'},
        {'submessage': {'count': 'x'}},
        {'submessages': ['x']},
        {'submessages': [{'count': 'x'}]},
        {'enumValue': 'x'},
        {'limit': 1},
        {'limit': 1000}
      ];
      requests.forEach((request) {
        expect(
          () => m1.fromRequest(request),
          throwsA(new isInstanceOf<BadRequestError>())
        );
      });
    });

    test('missing-required', () {
      var tester = new ApiConfig(new Tester());
      var m1 = new ApiConfigSchema(reflectClass(TestMessage4), tester);
      var requests = [{}, {'count': 1}];
      requests.forEach((request) {
        expect(
          () => m1.fromRequest(request),
          throwsA(new isInstanceOf<BadRequestError>())
        );
      });
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
      instance.enumValue = 'test1';
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
      instance.ignored = 10;

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
      expect(response['enumValue'], 'test1');
      expect(response['ignored'], null);
    });

    group('ListResponse', () {
      test('misconfig', () {
        var tester = new ApiConfig(new Tester());
        ListResponse message1 = new ListResponse();
        expect(
          () => new ApiConfigSchema(reflect(message1).type, tester),
          throwsA(new isInstanceOf<ApiConfigError>())
        );
      });

      test('correct', () {
        var tester = new ApiConfig(new Tester());
        ListResponse<TestMessage1> message1 = new ListResponse<TestMessage1>();
        ListResponse<TestMessage2> message2 = new ListResponse<TestMessage2>();
        expect(() => new ApiConfigSchema(reflect(message1).type, tester), returnsNormally);

        var m1 = new ApiConfigSchema(reflect(message1).type, tester);
        expect(m1.schemaName, 'TestMessage1List');

        var m2 = new ApiConfigSchema(reflect(message2).type, tester);
        expect(m2.schemaName, 'TestMessage2List');

        var instance = m1.fromRequest({'items': [{'count': 1}]});
        expect(instance, new isInstanceOf<ListResponse<TestMessage1>>());
        expect(instance.items.length, 1);
        expect(instance.items[0], new isInstanceOf<TestMessage1>());
        expect(instance.items[0].count, 1);

        var test1 = new TestMessage1();
        test1.count = 1;
        test1.message = 'test';
        message1.add(test1);
        var json = m1.toResponse(message1);
        expect(json['items'].length, 1);
        expect(json['items'][0]['count'], 1);
        expect(json['items'][0]['message'], 'test');

        message1 = new ListResponse<TestMessage1>([test1]);
        json = m1.toResponse(message1);
        expect(json['items'].length, 1);
        expect(json['items'][0]['count'], 1);
        expect(json['items'][0]['message'], 'test');
      });

      test('ListResponse fields', () {
        var tester = new ApiConfig(new Tester());
        ListResponse<TestMessage1> message1 = new ListResponse<TestMessage1>();
        var m1 = new ApiConfigSchema(reflect(message1).type, tester, fields: ['count', 'value']);
        var instance = m1.fromRequest({
          'items': [
            {'count': 1, 'message': 'test', 'value': 2.3}
          ]
        });
        expect(instance.items[0].count, 1);
        expect(instance.items[0].message, null);
        expect(instance.items[0].value, 2.3);

        m1 = new ApiConfigSchema(reflect(message1).type, tester, fields: ['count', 'value'], name: 'Test');
        expect(m1.schemaName, 'TestList');
        expect(m1.descriptor['properties']['items']['items']['\$ref'], 'Test');
      });
    });
  });
}
