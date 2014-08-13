import 'package:unittest/unittest.dart';

import 'package:endpoints/endpoints.dart';
import 'package:endpoints/src/api_config.dart';

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

List _misconfig_apis = [new Misconfig1(), new Misconfig2(), new Misconfig3(), new Misconfig4()];

@ApiClass(name: 'Tester', version: 'v1test')
class Tester extends Api {}

main () {
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

  group('api_config', () {
    test('misconfig', () {
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
}
