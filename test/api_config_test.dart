import 'package:unittest/unittest.dart';

import 'package:dart_endpoints/endpoints.dart';
import 'package:dart_endpoints/src/api_config.dart';

import 'dart:mirrors';

class Misconfig extends Api {
  @ApiMethod()
  void missingAnnotations1() {}

  @ApiMethod(name: 'test')
  void missingAnnotations2() {}

  @ApiMethod(path: 'test')
  void missingAnnotations3() {}
}

main () {
  group('api_config_methods', () {
    test('misconfig', () {
      var test_mirror = reflectClass(Misconfig);
      var methods = test_mirror.declarations.values.where(
        (dm) => dm is MethodMirror &&
                dm.isRegularMethod &&
                dm.metadata.length > 0 &&
                dm.metadata.first.reflectee.runtimeType == ApiMethod
      );
      methods.forEach((MethodMirror mm) {
        expect(() => new ApiConfigMethod(mm, 'Test'), throwsA(new isInstanceOf<ApiConfigError>('ApiConfigError')));
      });
    });
  });

  group('api_config', () {
    test('misconfig', () {
      var api_config = new ApiConfig(new Misconfig());
      expect(api_config.isValid, false);
    });
  });
}