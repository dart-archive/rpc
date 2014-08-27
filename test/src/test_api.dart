library test_api;

import 'dart:async';
import 'package:endpoints/endpoints.dart';

part 'test_api_messages.dart';

class WrongMethods {
  @ApiMethod()
  void missingAnnotations1() {}

  @ApiMethod(name: 'test1')
  void missingAnnotations2() {}

  @ApiMethod(path: 'test2')
  void missingAnnotations3() {}

  @ApiMethod(name: 'test3', path: 'test3')
  VoidMessage wrongUserParam(VoidMessage_, VoidMessage user) { return null;}

  @ApiMethod(name: 'test4', path: 'test4')
  VoidMessage wrongParameter(String test) { return null; }

  @ApiMethod(name: 'test5', path: 'test5')
  String wrongResponse1(VoidMessage _) {
    return '';
  }

  @ApiMethod(name: 'test6', path: 'test6')
  bool wrongResponse2(VoidMessage _) {
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

class ResursiveGet {
  @ApiMethod(name: 'test1', path: 'test1')
  VoidMessage resursiveGet1(RecursiveMessage1 request) {
    return null;
  }

  @ApiMethod(name: 'test2', path: 'test2')
  VoidMessage resursiveGet2(RecursiveMessage2 request) {
    return null;
  }
}

@ApiClass(name: 'correct', version: 'v1')
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

class Misconfig1 {}

@ApiClass()
class Misconfig2 {
}

@ApiClass(name: 'test')
class Misconfig3 {}

@ApiClass(version: 'test')
class Misconfig4 {}

@ApiClass(name: 'Tester', version: 'v1test')
class Tester {}
