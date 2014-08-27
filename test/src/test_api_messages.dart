part of test_api;

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