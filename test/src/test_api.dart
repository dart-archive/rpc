// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test_api;

import 'dart:async';

import 'package:rpc/rpc.dart';

part 'test_api/messages.dart';

class WrongMethods {
  @ApiMethod()
  void missingAnnotations1() {}

  @ApiMethod(name: 'test1')
  void missingAnnotations2() {}

  @ApiMethod(path: 'test2')
  void missingAnnotations3() {}

  @ApiMethod(name: 'test3', method: 'GET', path: 'test3')
  VoidMessage wrongMethod(VoidMessage_) { return null;}

  @ApiMethod(name: 'test4', method: 'GET', path: 'test4/{test}')
  VoidMessage wrongParameterType(bool test) { return null; }

  @ApiMethod(name: 'test5', method: 'GET', path: 'test5')
  VoidMessage wrongPathAnnotation(String test) { return null; }

  @ApiMethod(name: 'test6', method: 'GET', path: 'test6')
  String wrongResponseType1() {
    return '';
  }

  @ApiMethod(name: 'test7', method: 'GET', path: 'test7')
  bool wrongResponseType2() {
    return true;
  }

  @ApiMethod(name: 'test8', method: 'GET', path: 'test8')
  Future<bool> wrongFutureResponse() {
    return new Future.value(true);
  }

  @ApiMethod(name: 'test9', method: 'GET', path: 'test9')
  Future genericFutureResponse() {
    return new Future.value(true);
  }

  @ApiMethod(name: 'test10', method: 'GET', path: 'test10/{id}')
  VoidMessage missingPathParam1() { return null; }

  @ApiMethod(name: 'test11', method: 'POST', path: 'test11/{id}')
  VoidMessage missingPathParam2(TestMessage1 request) { return null; }

  @ApiMethod(name: 'test12', method: 'POST', path: 'test12')
  void voidResponse(VoidMessage _) {}

  @ApiMethod(name: 'test13', method: 'POST', path: 'test13')
  VoidMessage noRequest1() { return null; }

  @ApiMethod(name: 'test14', method: 'POST', path: 'test14/{id}')
  VoidMessage noRequest2(String id) { return null; }

  @ApiMethod(name: 'test15', method: 'POST', path: 'test15')
  VoidMessage genericRequest(request) { return null; }

  @ApiMethod(name: 'test16', method: 'GET', path: 'test16/{wrong')
  VoidMessage invalidPath1() { return null; }

  @ApiMethod(name: 'test17', method: 'GET', path: 'test17/wrong}')
  VoidMessage invalidPath2() { return null; }
}

class RecursiveGet {
  @ApiMethod(name: 'test1', path: 'test1')
  VoidMessage resursiveGet1(RecursiveMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test2', path: 'test2')
  VoidMessage resursiveGet2(RecursiveMessage2 request) {
    return null;
  }
}

@ApiClass(version: 'v1')
class CorrectSimple {
  final String _foo = 'ffo';

  final CorrectMethods _cm = new CorrectMethods();

  CorrectMethods _cmNonFinal = new CorrectMethods();

  @ApiMethod(path: 'test1/{path}')
  VoidMessage simple1(String path) {
    return null;
  }

  @ApiMethod(method: 'POST', path: 'test2')
  TestMessage1 simple2(TestMessage1 request) {
    return null;
  }
}

@ApiClass(name: 'correct', version: 'v1')
class CorrectMethods {
  @ApiMethod(name: 'test1', path: 'test1')
  VoidMessage method1() { return null; }

  @ApiMethod(name: 'test2', path: 'test2')
  TestMessage1 method2() {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test3', path: 'test3/{count}')
  TestMessage1 method3(String count) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test4', path: 'test4/{count}/{more}')
  TestMessage1 method4(String count, String more) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test5', path: 'test5/{count}/some/{more}')
  TestMessage1 method5(String count, String more) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test6', method: 'POST', path: 'test6')
  TestMessage1 method6(VoidMessage _) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test7', method: 'POST', path: 'test7')
  VoidMessage method7(TestMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test8', method: 'POST', path: 'test8')
  TestMessage1 method8(TestMessage1 request) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test9', method: 'POST', path: 'test9/{count}')
  TestMessage1 method9(String count, VoidMessage _) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test10', method: 'POST', path: 'test10/{count}')
  TestMessage1 method10(String count, TestMessage1 request) {
    return new TestMessage1();
  }

  @ApiMethod(name: 'test11', method: 'POST', path: 'test11/{count}')
  VoidMessage method11(String count, TestMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test12', method: 'POST', path: 'test12')
  Future<TestMessage1> method12(VoidMessage _) {
    return new Future.value(new TestMessage1());
  }

  @ApiMethod(name: 'test13', method: 'POST', path: 'test13')
  Future<VoidMessage> method13(VoidMessage _) {
    return new Future.value(new VoidMessage());
  }

  @ApiMethod(name: 'test11', method: 'POST', path: 'test11/{count}/bar')
  VoidMessage method14(String count, TestMessage1 request) {
    return null;
  }
}

class NoAnnotation {}

@ApiClass()
class NoVersion1 {
}

@ApiClass(name: 'test')
class NoVersion2 {}

@ApiClass(version: 'test')
class AmbiguousMethodPaths1 {
  @ApiMethod(path: 'test1')
  TestMessage1 method1a() {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test1')
  TestMessage1 method1b() {
    return new TestMessage1();
  }
}

@ApiClass(version: 'test')
class AmbiguousMethodPaths2 {
  @ApiMethod(path: 'test2/{path}')
  TestMessage1 method2a(String path) {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test2/path')
  TestMessage1 method2b() {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test2/other')
  TestMessage1 method2c() {
    return new TestMessage1();
  }
}

@ApiClass(version: 'test')
class AmbiguousMethodPaths3 {
  @ApiMethod(path: 'test3/path')
  TestMessage1 method3a() {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test3/{path}')
  TestMessage1 method3b(String path) {
    return new TestMessage1();
  }
}

@ApiClass(version: 'test')
class AmbiguousMethodPaths4 {
  @ApiMethod(path: 'test4/{path}')
  TestMessage1 method4a(String path) {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test4/{other}')
  TestMessage1 method4b(String other) {
    return new TestMessage1();
  }
}

@ApiClass(version: 'test')
class AmbiguousMethodPaths5 {
 @ApiMethod(path: 'test5/other/some')
  TestMessage1 method5a() {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test5/{other}/some')
  TestMessage1 method5b(String other) {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test5/other/{some}')
  TestMessage1 method5c(String some) {
    return new TestMessage1();
  }
}

@ApiClass(version: 'test')
class AmbiguousMethodPaths6 {
  @ApiMethod(path: 'test6/{other}/some')
  TestMessage1 method6a(String other) {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test6/other/some')
  TestMessage1 method6b() {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test6/other/{some}')
  TestMessage1 method6c(String some) {
    return new TestMessage1();
  }
}

@ApiClass(version: 'test')
class AmbiguousMethodPaths7 {
  @ApiMethod(path: 'test7/other/{some}')
  TestMessage1 method7a(String some) {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test7/{other}/some')
  TestMessage1 method7b(String other) {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test7/other/some')
  TestMessage1 method7c() {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test7/{another}/some')
  TestMessage1 method7d(String another) {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test7/{other}/{some}')
  TestMessage1 method7e(String other, String some) {
    return new TestMessage1();
  }

  @ApiMethod(path: 'test7/{another}/{someother}')
  TestMessage1 method7f(String another, String someother) {
    return new TestMessage1();
  }
}

@ApiClass(name: 'Tester', version: 'v1test')
class Tester {}

@ApiClass(version: 'v1test')
class TesterWithOneResource {

  @ApiResource()
  final SomeResource someResource = new SomeResource();
}

@ApiClass(version: 'v1test')
class TesterWithTwoResources {

  @ApiResource()
  final SomeResource someResource = new SomeResource();

  @ApiResource(name: 'nice_name')
  final NamedResource namedResource = new NamedResource();
}

@ApiClass(version: 'v1test')
class TesterWithNestedResources {

  @ApiResource()
  final ResourceWithNested resourceWithNested = new ResourceWithNested();
}

@ApiClass(version: 'v1test')
class TesterWithDuplicateResourceNames {

  @ApiResource()
  final SomeResource someResource = new SomeResource();

  @ApiResource(name: 'someResource')
  final NamedResource namedResource = new NamedResource();
}

@ApiClass(version: 'v1test')
class TesterWithMultipleResourceAnnotations {

  @ApiResource()
  @ApiResource()
  final SomeResource someResource = new SomeResource();
}


class MultipleResourceMethodAnnotations {

  @ApiMethod(path: 'multi')
  @ApiMethod(path: 'multi2')
  VoidMessage multiAnnotations() { return null; }
}

class SomeResource {

  @ApiMethod(path: 'someResourceMethod')
  VoidMessage method1() { return null; }
}

class NamedResource {

  @ApiMethod(path: 'namedResourceMethod')
  VoidMessage method1() { return null; }
}

class ResourceWithNested {

  @ApiResource()
  NestedResource nestedResource = new NestedResource();
}

class NestedResource {

  @ApiMethod(path: 'nestedResourceMethod')
  VoidMessage method1() { return null; }
}
