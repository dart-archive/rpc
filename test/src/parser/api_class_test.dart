// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library api_class_tests;

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:unittest/unittest.dart';

@ApiClass(version: 'v1')
class CorrectMinimum {}

@ApiClass(name: 'testApi',
          version: 'v1',
          title: 'The Test API',
          description: 'An API used to test the implementation')
class CorrectFull {}

class WrongNoMetadata {}

@ApiClass()
class WrongNoVersionMinimum {}

@ApiClass(name: 'testApi',
          title: 'The Test API',
          description: 'An API used to test the implementation')
class WrongNoVersionFull {}

void main() {
  group('api-class-correct', () {
    test('full', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectFull());
      expect(apiCfg.name, 'testApi');
      expect(apiCfg.version, 'v1');
      expect(apiCfg.title, 'The Test API');
      expect(apiCfg.description, 'An API used to test the implementation');
    });

    test('minimum', (){
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new CorrectMinimum());
      expect(apiCfg.version, 'v1');
      // Check the defaults are as expected.
      expect(apiCfg.name, 'correctMinimum');
      expect(apiCfg.title, isNull);
      expect(apiCfg.description, isNull);
    });
  });

  group('api-class-wrong', () {
    test('no-metadata', (){
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongNoMetadata());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongNoMetadata: Missing required @ApiClass annotation.'),
        new ApiConfigError(
            'WrongNoMetadata: @ApiClass.version field is required.')
        ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('min-no-version', (){
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongNoVersionMinimum());
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongNoVersionMinimum: @ApiClass.version field is required.')
        ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });

    test('full-no-version', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new WrongNoVersionFull());
      expect(apiCfg.name, 'testApi');
      expect(apiCfg.version, isNull);
      expect(apiCfg.title, 'The Test API');
      expect(apiCfg.description, 'An API used to test the implementation');
      expect(parser.isValid, isFalse);
      var expectedErrors = [
        new ApiConfigError(
            'WrongNoVersionFull: @ApiClass.version field is required.')
        ];
      expect(parser.errors.toString(), expectedErrors.toString());
    });
  });
}