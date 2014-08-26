library test_api;

import 'dart:async';

import 'package:endpoints/endpoints.dart';

class Misconfig1 {
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

@ApiClass()
class Misconfig2 {}

@ApiClass(name: 'test')
class Misconfig3 {}

@ApiClass(version: 'test')
class Misconfig4 {}

@ApiClass(name: 'Tester', version: 'v1test')
class Tester {}

class RecursiveMessage1 {
  String message;
  RecursiveMessage1 item;
}

class RecursiveMessage2 {
  String message;
  RecursiveMessage3 item;
}

class RecursiveMessage3 {
  String message;
  RecursiveMessage2 item;
}

class TestMessage1 {
  int count;
  String message;
  double value;
  bool check;
  DateTime date;
  List<String> messages;
  TestMessage2 submessage;
  List<TestMessage2> submessages;

  @ApiProperty(
      values: const {
        'test1': 'test1',
        'test2': 'test2',
        'test3': 'test3'
      }
  )
  String enumValue;

  @ApiProperty(required: true)
  int requiredValue;

  @ApiProperty(defaultValue: 10)
  int defaultValue;

  @ApiProperty(minValue: 10, maxValue: 100)
  int limit;

  @ApiProperty(ignore: true)
  int ignored;

  TestMessage1({this.count});
}

class TestMessage2 {
  int count;
}

class TestMessage3 {
  @ApiProperty(variant: 'int64')
  int count64;

  @ApiProperty(variant: 'uint64')
  int count64u;

  @ApiProperty(variant: 'int32')
  int count32;

  @ApiProperty(variant: 'uint32')
  int count32u;
}

class WrongSchema1 {
  WrongSchema1.myConstructor();
}