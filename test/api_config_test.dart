// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:mirrors';

import 'package:rpc/rpc.dart';
import 'package:rpc/src/config.dart';
import 'package:rpc/src/parser.dart';
import 'package:rpc/src/discovery/config.dart';
import 'package:unittest/unittest.dart';

import 'src/test_api.dart';

final ApiConfigSchema discoveryDocSchema =
    new ApiParser().parseSchema(reflectType(RestDescription));

main () {
  group('api_config_misconfig', () {

    test('no_apiclass_annotation', () {
      var parser = new ApiParser();
      ApiConfig apiCfg = parser.parse(new NoAnnotation());
      var expected = [
          new ApiConfigError(
              'NoAnnotation: Missing required @ApiClass annotation.'),
          new ApiConfigError(
              'NoAnnotation: @ApiClass.version field is required.')
        ];
        expect(parser.errors.toString(), expected.toString());
      });

    test('no_apiclass_version', () {
      var parser = new ApiParser();
      parser.parse(new NoVersion());
      var expected = [new ApiConfigError(
          'NoVersion: @ApiClass.version field is required.')];
      expect(parser.errors.toString(), expected.toString());
    });

    List ambiguousPaths = [new AmbiguousMethodPaths1(),
                           new AmbiguousMethodPaths2(),
                           new AmbiguousMethodPaths3(),
                           new AmbiguousMethodPaths4(),
                           new AmbiguousMethodPaths5(),
                           new AmbiguousMethodPaths6(),
                           new AmbiguousMethodPaths7()];
    ambiguousPaths.forEach((ambiguous) {
      test(ambiguous.toString(), () {
        var parser = new ApiParser();
        ApiConfig apiConfig = parser.parse(ambiguous);
        expect(parser.isValid, isFalse);
        var config = apiConfig.generateDiscoveryDocument('baseUrl', '');
        expect(config.version, 'test');
      });
    });
  });

  group('api_config_correct', () {

    test('correct_simple', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new Tester());
      expect(parser.isValid, isTrue);
      Map expectedJson = {
        'kind': 'discovery#restDescription',
        'etag': '8ce09ed6f8ebe8682b517e05d21c2d4a27b83d09',
        'discoveryVersion': 'v1',
        'id': 'Tester:v1test',
        'name': 'Tester',
        'version': 'v1test',
        'revision': '0',
        'protocol': 'rest',
        'baseUrl': 'http://localhost:8080/Tester/v1test/',
        'basePath': '/Tester/v1test/',
        'rootUrl': 'http://localhost:8080/',
        'servicePath': 'Tester/v1test/',
        'parameters': {},
        'schemas': {},
        'methods': {},
        'resources': {}
      };
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080/', '');
      // Encode the discovery document for the Tester API as json.
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json, expectedJson);
    });

    test('correct_simple2', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new CorrectSimple());
      expect(parser.isValid, isTrue);
      Map expectedSchemas = {
        'TestMessage2': {
          'id': 'TestMessage2',
          'type': 'object',
          'properties': {'count': {'type': 'integer', 'format': 'int32'}}
        },
        'TestMessage1': {
          'id': 'TestMessage1',
          'type': 'object',
          'properties': {
            'count': {'type': 'integer', 'format': 'int32'},
            'message': {'type': 'string'},
            'value': {'type': 'number', 'format': 'double'},
            'check': {'type': 'boolean'},
            'date': {'type': 'string', 'format': 'date-time'},
            'messages': {'type': 'array', 'items': {'type': 'string'}},
            'submessage': {'\$ref': 'TestMessage2'},
            'submessages': {'type': 'array',
                            'items': {'\$ref': 'TestMessage2'}
                           },
            'enumValue': {
              'type': 'string',
              'enum': ['test1', 'test2', 'test3'],
              'enumDescriptions': ['test1', 'test2', 'test3']
            },
            'defaultValue': {
              'type': 'integer',
              'default': '10',
              'format': 'int32'
            },
            'limit': {
              'type': 'integer',
              'format': 'int32',
              'minimum': 10,
              'maximum': 100
            }
          }
        }
      };
      Map expectedMethods = {
        'simple1': {
          'id': 'CorrectSimple.simple1',
          'path': 'test1/{path}',
          'httpMethod': 'GET',
          'parameters': {
            'path': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'path\'.',
              'location': 'path'
            }
          },
          'parameterOrder': ['path']
        },
        'simple2': {
          'id': 'CorrectSimple.simple2',
          'path': 'test2',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'TestMessage1'},
          'response': {'\$ref': 'TestMessage1'}
        }
      };
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080/', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);
    });

    test('correct_extended', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new CorrectMethods());
      expect(parser.isValid, isTrue);
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      var expectedJsonMethods = {
        'test1': {
          'id': 'CorrectMethods.method1',
          'path': 'test1',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': []
        },
        'test2': {
          'id': 'CorrectMethods.method2',
          'path': 'test2',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {'\$ref': 'TestMessage1'}
        },
        'test3': {
          'id': 'CorrectMethods.method3',
          'path': 'test3/{count}',
          'httpMethod': 'GET',
          'parameters': {
            'count': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'count\'.',
              'location': 'path'
            }
          },
          'parameterOrder': ['count'],
          'response': {'\$ref': 'TestMessage1'}
        },
        'test4': {
          'id': 'CorrectMethods.method4',
          'path': 'test4/{count}/{more}',
          'httpMethod': 'GET',
          'parameters': {
            'count': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'count\'.',
              'location': 'path'
            },
            'more': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'more\'.',
              'location': 'path'
            }
          },
          'parameterOrder': ['count', 'more'],
          'response': {'\$ref': 'TestMessage1'}
        },
        'test5': {
          'id': 'CorrectMethods.method5',
          'path': 'test5/{count}/some/{more}',
          'httpMethod': 'GET',
          'parameters': {
            'count': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'count\'.',
              'location': 'path'
            },
            'more': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'more\'.',
              'location': 'path'
            }
          },
          'parameterOrder': ['count', 'more'],
          'response': {'\$ref': 'TestMessage1'}
        },
        'test6': {
          'id': 'CorrectMethods.method6',
          'path': 'test6',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'response': {'\$ref': 'TestMessage1'}
        },
        'test7': {
          'id': 'CorrectMethods.method7',
          'path': 'test7',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'TestMessage1'}
        },
        'test8': {
          'id': 'CorrectMethods.method8',
          'path': 'test8',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'TestMessage1'},
          'response': {'\$ref': 'TestMessage1'}
        },
        'test9': {
          'id': 'CorrectMethods.method9',
          'path': 'test9/{count}',
          'httpMethod': 'POST',
          'parameters': {
            'count': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'count\'.',
              'location': 'path'
            }
          },
          'parameterOrder': ['count'],
          'response': {'\$ref': 'TestMessage1'}
        },
        'test10': {
          'id': 'CorrectMethods.method10',
          'path': 'test10/{count}',
          'httpMethod': 'POST',
          'parameters': {
            'count': {
              'type': 'string',
              'required': true,
              'description': 'Path parameter: \'count\'.',
              'location': 'path'
            }
          },
          'parameterOrder': ['count'],
          'request': {'\$ref': 'TestMessage1'},
          'response': {'\$ref': 'TestMessage1'}
        },
        'test11': {
          'id': 'CorrectMethods.method11',
          'path': 'test11/{count}',
          'httpMethod': 'POST',
          'parameters': {
            'count': {
              'type': 'string',
              'description': 'Path parameter: \'count\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['count'],
          'request': {'\$ref': 'TestMessage1'}
        },
        'test12': {
          'id': 'CorrectMethods.method12',
          'path': 'test12',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'response': {'\$ref': 'TestMessage1'}
        },
        'test13': {
          'id': 'CorrectMethods.method13',
          'path': 'test13',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': []
        },
        'test14': {
          'id': 'CorrectMethods.method14',
          'path': 'test14/{count}/bar',
          'httpMethod': 'POST',
          'parameters': {
            'count': {
              'type': 'string',
              'description': 'Path parameter: \'count\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['count'],
          'request': {'\$ref': 'TestMessage1'}
        },
        'test15': {
          'id': 'CorrectMethods.method15',
          'path': 'test15/{count}',
          'httpMethod': 'POST',
          'parameters': {
            'count': {
              'type': 'integer',
              'description': 'Path parameter: \'count\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['count'],
          'response': {'\$ref': 'TestMessage1'}
        },
        'test16': {
          'id': 'CorrectMethods.method16',
          'path': 'test16/{count}',
          'httpMethod': 'POST',
          'parameters': {
            'count': {
              'type': 'integer',
              'description': 'Path parameter: \'count\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['count'],
          'request': {'\$ref': 'TestMessage1'},
          'response': {'\$ref': 'TestMessage1'}
        },
        'test17': {
          'id': 'CorrectMethods.method17',
          'path': 'test17/{count}/bar',
          'httpMethod': 'POST',
          'parameters': {
            'count': {
              'type': 'integer',
              'description': 'Path parameter: \'count\'.',
              'required': true,
              'location': 'path'
            }
          },
          'parameterOrder': ['count'],
          'request': {'\$ref': 'TestMessage1'},
          'response': {'\$ref': 'TestMessage1'}
        }
      };
      expect(json['methods'], expectedJsonMethods);
    });
  });

  group('api_config_resources_misconfig', () {

    test('multiple_method_annotations', () {
      var parser = new ApiParser();
      var metadata = new ApiResource();
      parser.parseResource(
          'foo', reflect(new MultipleMethodAnnotations()), metadata);
      expect(parser.isValid, isFalse);
      var errors = [
        new ApiConfigError(
            'foo: Multiple ApiMethod annotations on declaration '
            '\'multiAnnotations\'.')];
      expect(parser.errors.toString(), errors.toString());
    });

    test('multiple_resource_annotations', () {
      var parser = new ApiParser();
      ApiConfig apiConfig =
          parser.parse(new TesterWithMultipleResourceAnnotations());
      expect(parser.isValid, isFalse);
      var errors = [
        new ApiConfigError('TesterWithMultipleResourceAnnotations: Multiple '
            'ApiResource annotations on declaration \'someResource\'.')];
      expect(parser.errors.toString(), errors.toString());
    });

    test('duplicate_resources', () {
      var parser = new ApiParser();
      ApiConfig apiConfig =
          parser.parse(new TesterWithDuplicateResourceNames());
      expect(parser.isValid, isFalse);
      var errors = [
        new ApiConfigError('TesterWithDuplicateResourceNames: Duplicate '
                           'resource with name: someResource')];
      expect(parser.errors.toString(), errors.toString());
    });
  });

  group('api_config_resources_correct', () {

    test('simple', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new TesterWithOneResource());
      expect(parser.isValid, isTrue);
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      Map expectedResources = {
        'someResource': {
          'methods': {
            'method1': {
              'id': 'TesterWithOneResource.someResource.method1',
              'path': 'someResourceMethod',
              'httpMethod': 'GET',
              'parameters': {},
              'parameterOrder': []
            }
          },
          'resources': {}
        }
      };
      expect(json['resources'], expectedResources);
    });

    test('two_resources', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new TesterWithTwoResources());
      expect(parser.isValid, isTrue);
      var expectedResources = {
        'someResource': {
          'methods': {
            'method1': {
              'id': 'TesterWithTwoResources.someResource.method1',
              'path': 'someResourceMethod',
              'httpMethod': 'GET',
              'parameters': {},
              'parameterOrder': []
            }
          },
          'resources': {}
        },
        'nice_name': {
          'methods': {
            'method1': {
              'id': 'TesterWithTwoResources.namedResource.method1',
              'path': 'namedResourceMethod',
              'httpMethod': 'GET',
              'parameters': {},
              'parameterOrder': []
            }
          },
          'resources': {}
        }
      };
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['resources'], expectedResources);
    });

    test('nested_resources', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new TesterWithNestedResources());
      expect(parser.isValid, isTrue);
      var expectedResources = {
        'resourceWithNested': {
          'methods': {},
          'resources': {
            'nestedResource': {
              'methods': {
                'method1': {
                  'id': 'TesterWithNestedResources.resourceWithNested'
                        '.nestedResource.method1',
                  'path': 'nestedResourceMethod',
                  'httpMethod': 'GET',
                  'parameters': {},
                  'parameterOrder': []
                }
              },
              'resources': {}
            }
          }
        }
      };
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080', null);
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['resources'], expectedResources);
    });
  });

  group('api_config_methods', () {

    test('misconfig', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new WrongMethods());
      expect(parser.isValid, isFalse);
      var errors = [
        new ApiConfigError(
            'WrongMethods: Missing required @ApiClass annotation.'),
        new ApiConfigError(
            'WrongMethods: @ApiClass.version field is required.'),
        new ApiConfigError('WrongMethods.missingAnnotations1: ApiMethod.path '
            'field is required.'),
        new ApiConfigError('WrongMethods.missingAnnotations1: API Method '
            'cannot be void, use VoidMessage as return type instead.'),
        new ApiConfigError('WrongMethods.missingAnnotations2: ApiMethod.path '
            'field is required.'),
        new ApiConfigError('WrongMethods.missingAnnotations2: API Method '
            'cannot be void, use VoidMessage as return type instead.'),
        new ApiConfigError('WrongMethods.missingAnnotations3: API Method '
            'cannot be void, use VoidMessage as return type instead.'),
        new ApiConfigError('WrongMethods.wrongMethodParameter: Non-path '
            'parameter \'_\' must be a named parameter.'),
        new ApiConfigError('WrongMethods.wrongMethodParameter: Query '
            'parameter \'_\' must be of type int or String.'),
        new ApiConfigError('WrongMethods.wrongParameterType: Path parameter '
            '\'test\' must be of type int or String.'),
        new ApiConfigError('WrongMethods.wrongPathAnnotation: Non-path '
            'parameter \'test\' must be a named parameter.'),
        new ApiConfigError('WrongMethods.wrongResponseType1: Return type: '
            'String is not a valid return type.'),
        new ApiConfigError('WrongMethods.wrongResponseType2: Return type: '
            'bool is not a valid return type.'),
        new ApiConfigError('WrongMethods.wrongFutureResponse: Return type: '
            'bool is not a valid return type.'),
        new ApiConfigError('WrongMethods.genericFutureResponse: API Method '
            'return type has to be a instantiable class.'),
        new ApiConfigError('WrongMethods.missingPathParam1: Missing methods '
            'parameters specified in method path: test10/{id}.'),
        new ApiConfigError('WrongMethods.missingPathParam2: Expected method '
            'parameter with name \'id\', but found parameter with name '
            '\'request\'.'),
        new ApiConfigError('WrongMethods.missingPathParam2: Path parameter '
            '\'id\' must be of type int or String.'),
        new ApiConfigError('WrongMethods.missingPathParam2: API methods using '
            'POST must have a signature of path parameters followed by one '
            'request parameter.'),
        new ApiConfigError('WrongMethods.voidResponse: API Method cannot be '
            'void, use VoidMessage as return type instead.'),
        new ApiConfigError('WrongMethods.noRequest1: API methods using POST '
            'must have a signature of path parameters followed by one request '
            'parameter.'),
        new ApiConfigError('WrongMethods.noRequest2: API methods using POST '
            'must have a signature of path parameters followed by one request '
            'parameter.'),
        new ApiConfigError('WrongMethods.genericRequest: API Method parameter '
            'has to be an instantiable class.'),
        new ApiConfigError('WrongMethods.invalidPath1: Invalid path: '
            'test16/{wrong. Failed with error: ParseException: test16/{wrong'),
        new ApiConfigError('WrongMethods.invalidPath2: Invalid path: '
            'test17/wrong}. Failed with error: ParseException: test17/wrong}')
      ];
      expect(parser.errors.toString(), errors.toString());
    });

    test('recursion', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new Recursive());
      expect(parser.isValid, isTrue);
    });

    test('correct', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new CorrectMethods());
      expect(parser.isValid, isTrue);
    });

    test('correct_schema_list_map', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new CorrectListMapTester());
      expect(parser.isValid, isTrue);
      var expectedSchemas = {
        'ListOfString': {
          'id': 'ListOfString', 'type': 'array', 'items': {'type': 'string'}
        },
        'MapOfint': {
          'id': 'MapOfint',
          'type': 'object',
          'additionalProperties': {'type': 'integer', 'format': 'int32'}
        },
        'MapOfListOfint': {
          'id': 'MapOfListOfint',
          'type': 'object',
          'additionalProperties':
            {'type': 'array', 'items': {'type': 'integer', 'format': 'int32'}}
        },
        'ListOfMapOfbool': {
          'id': 'ListOfMapOfbool',
          'type': 'array',
          'items':
            {'type': 'object', 'additionalProperties': {'type': 'boolean'}}
        },
        'ListOfListOfint': {
          'id': 'ListOfListOfint',
          'type': 'array',
          'items':
            {'type': 'array', 'items': {'type': 'integer', 'format': 'int32'}}
        },
        'ListOfListOfbool': {
          'id': 'ListOfListOfbool',
          'type': 'array',
          'items': {'type': 'array', 'items': {'type': 'boolean'}}
        },
        'MapOfMapOfint': {
          'id': 'MapOfMapOfint',
          'type': 'object',
          'additionalProperties': {
            'type': 'object',
            'additionalProperties': {'type': 'integer', 'format': 'int32'}
          }
        },
        'MapOfMapOfbool': {
          'id': 'MapOfMapOfbool',
          'type': 'object',
          'additionalProperties':
            {'type': 'object', 'additionalProperties': {'type': 'boolean'}}
        }
      };
      var expectedMethods = {
        'test1': {
          'id': 'CorrectListMapTester.test1',
          'path': 'returnsList',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {'\$ref': 'ListOfString'}
        },
        'test2': {
          'id': 'CorrectListMapTester.test2',
          'path': 'takesList',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'ListOfString'}
        },
        'test3': {
          'id': 'CorrectListMapTester.test3',
          'path': 'returnsMap',
          'httpMethod': 'GET',
          'parameters': {},
          'parameterOrder': [],
          'response': {'\$ref': 'MapOfint'}
        },
        'test4': {
          'id': 'CorrectListMapTester.test4',
          'path': 'takesMap',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'MapOfint'}
        },
        'test5': {
          'id': 'CorrectListMapTester.test5',
          'path': 'takesMapOfList',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'MapOfListOfint'},
          'response': {'\$ref': 'ListOfMapOfbool'}
        },
        'test6': {
          'id': 'CorrectListMapTester.test6',
          'path': 'takeListOfList',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'ListOfListOfint'},
          'response': {'\$ref': 'ListOfListOfbool'}
        },
        'test7': {
          'id': 'CorrectListMapTester.test7',
          'path': 'takeMapOfMap',
          'httpMethod': 'POST',
          'parameters': {},
          'parameterOrder': [],
          'request': {'\$ref': 'MapOfMapOfint'},
          'response': {'\$ref': 'MapOfMapOfbool'}
        }
      };
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080/', '');
      // Encode the discovery document for the Tester API as json.
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['schemas'], expectedSchemas);
      expect(json['methods'], expectedMethods);
    });

    test('wrong_schema_list', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new WrongListTester());
      expect(parser.isValid, isFalse);
      var errors = [
        new ApiConfigError(
            'ListOfdynamic: ListOfdynamicProperty: Properties cannot be of '
            'type: \'dynamic\'.'),
        new ApiConfigError('ListOfListOfdynamic: ListOfListOfdynamicProperty: '
            'Properties cannot be of type: \'dynamic\'.')];
      expect(parser.errors.toString(), errors.toString());
    });

    test('wrong_schema_map', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new WrongMapTester());
      expect(parser.isValid, isFalse);
      var errors = [
        new ApiConfigError(
            'MapOfdynamic: Maps must have keys of type \'String\'.'),
        new ApiConfigError(
            'MapOfdynamic: Maps must have keys of type \'String\'.'),
        new ApiConfigError(
            'MapOfdynamic: MapOfdynamicProperty: Properties cannot be of type: '
            '\'dynamic\'.'),
        new ApiConfigError(
            'MapOfString: Maps must have keys of type \'String\'.'),
        new ApiConfigError(
            'MapOfString: Maps must have keys of type \'String\'.'),
        new ApiConfigError(
            'MapOfMapOfdynamic: Maps must have keys of type \'String\'.')
        ];
      expect(parser.errors.toString(), errors.toString());
    });
  });

  group('api_config_schema', () {

    group('misconfig', () {
      test('wrong_schema', () {
        var parser = new ApiParser();
        parser.parseSchema(reflectClass(WrongSchema1));
        var errors = [new ApiConfigError('WrongSchema1: Schema '
            '\'WrongSchema1\' must have an unnamed constructor.')];
        expect(parser.errors.toString(), errors.toString());
      });
      test('schema_with_conflicting_classes', () {
        var parser = new ApiParser();
        parser.parseSchema(reflectClass(WrongSchema2));
        var errors = [new ApiConfigError('TestMessage2: Schema '
            '\'messages2.TestMessage2\' has a name conflict with '
            '\'test_api.TestMessage2\'.')];
        expect(parser.errors.toString(), errors.toString());
      });
      test('schema_with_nested_conflicting_classes', () {
        var parser = new ApiParser();
        parser.parseSchema(reflectClass(WrongSchema3));
        var errors = [new ApiConfigError('TestMessage2: Schema '
            '\'messages2.TestMessage2\' has a name conflict with '
            '\'test_api.TestMessage2\'.')];
        expect(parser.errors.toString(), errors.toString());
      });
    });

    test('recursion', () {
      expect(new Future.sync(() {
        var parser = new ApiParser();
        parser.parseSchema(reflectClass(RecursiveMessage1));
      }), completes);
      expect(new Future.sync(() {
        var parser = new ApiParser();
        parser.parseSchema(reflectClass(RecursiveMessage2));
      }), completes);
      expect(new Future.sync(() {
        var parser = new ApiParser();
        parser.parseSchema(reflectClass(RecursiveMessage3));
      }), completes);
      expect(new Future.sync(() {
        var parser = new ApiParser();
        parser.parseSchema(reflectClass(RecursiveMessage2));
        parser.parseSchema(reflectClass(RecursiveMessage3));
      }), completes);
    });

    test('variants', () {
      var parser = new ApiParser();
      var message = parser.parseSchema(reflectClass(TestMessage3));
      var instance = message.fromRequest(
          {'count32': 1, 'count32u': 2, 'count64': '3', 'count64u': '4'});
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
      var parser = new ApiParser();
      var m1 = parser.parseSchema(reflectClass(TestMessage1));
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
    });

    test('request-parsing-map-list', () {
      var parser = new ApiParser();
      var schema = parser.parseSchema(reflectClass(TestMessage5));
      var jsonRequest ={
        'myStrings': ['foo', 'bar'],
        'listOfObjects' : [
          {'count': 4},
          {'count': 2}
        ],
        'mapStringToString': {
          'foo': 'bar',
          'bar': 'foo'
        },
        'mapStringToObject': {
          'some':  {'count': 2},
          'other': {'count': 4}
        }
      };
      var schemaInstance = schema.fromRequest(jsonRequest);
      var jsonResponse = schema.toResponse(schemaInstance);
      expect(jsonResponse, jsonRequest);
    });

    test('required', () {
      var parser = new ApiParser();
      var m1 = parser.parseSchema(reflectClass(TestMessage4));
      expect(() => m1.fromRequest({'requiredValue': 1}), returnsNormally);
    });

    test('bad-request-creation', () {
      var parser = new ApiParser();
      var m1 = parser.parseSchema(reflectClass(TestMessage1));
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
      var parser = new ApiParser();
      var m1 = parser.parseSchema(reflectClass(TestMessage4));
      var requests = [{}, {'count': 1}];
      requests.forEach((request) {
        expect(
          () => m1.fromRequest(request),
          throwsA(new isInstanceOf<BadRequestError>())
        );
      });
    });

    test('response-creation', () {
      var parser = new ApiParser();
      var m1 = parser.parseSchema(reflectClass(TestMessage1));
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
    });
  });

  group('api_config_query_methods', () {

    test('correct', () {
      var expectedJsonMethods = {
        'query1': {
          'id': 'CorrectQueryParameterTester.query1',
          'path': 'query1',
          'httpMethod': 'GET',
          'parameters': {
            'name': {
              'type': 'string',
              'description': 'Query parameter: \'name\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query2': {
          'id': 'CorrectQueryParameterTester.query2',
          'path': 'query2/{pathParam}',
          'httpMethod': 'GET',
          'parameters': {
            'pathParam': {
              'type': 'string',
              'description': 'Path parameter: \'pathParam\'.',
              'required': true,
              'location': 'path'
            },
            'queryParam': {
              'type': 'string',
              'description': 'Query parameter: \'queryParam\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': ['pathParam']
        },
        'query3': {
          'id': 'CorrectQueryParameterTester.query3',
          'path': 'query3',
          'httpMethod': 'GET',
          'parameters': {
            'qp1': {
              'type': 'string',
              'description': 'Query parameter: \'qp1\'.',
              'required': false,
              'location': 'query'
            },
            'qp2': {
              'type': 'string',
              'description': 'Query parameter: \'qp2\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query4': {
          'id': 'CorrectQueryParameterTester.query4',
          'path': 'query4',
          'httpMethod': 'GET',
          'parameters': {
            'qp': {
              'type': 'integer',
              'description': 'Query parameter: \'qp\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query5': {
          'id': 'CorrectQueryParameterTester.query5',
          'path': 'query5',
          'httpMethod': 'GET',
          'parameters': {
            'qp1': {
              'type': 'string',
              'description': 'Query parameter: \'qp1\'.',
              'required': false,
              'location': 'query'
            },
            'qp2': {
              'type': 'integer',
              'description': 'Query parameter: \'qp2\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query6': {
          'id': 'CorrectQueryParameterTester.query6',
          'path': 'query6',
          'httpMethod': 'GET',
          'parameters': {
            'qp1': {
              'type': 'integer',
              'description': 'Query parameter: \'qp1\'.',
              'required': false,
              'location': 'query'
            },
            'qp2': {
              'type': 'string',
              'description': 'Query parameter: \'qp2\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        },
        'query7': {
          'id': 'CorrectQueryParameterTester.query7',
          'path': 'query7',
          'httpMethod': 'GET',
          'parameters': {
            'qp1': {
              'type': 'integer',
              'description': 'Query parameter: \'qp1\'.',
              'required': false,
              'location': 'query'
            },
            'qp2': {
              'type': 'integer',
              'description': 'Query parameter: \'qp2\'.',
              'required': false,
              'location': 'query'
            }
          },
          'parameterOrder': []
        }
      };

      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new CorrectQueryParameterTester());
      expect(parser.isValid, isTrue);
      var discoveryDoc =
          apiConfig.generateDiscoveryDocument('http://localhost:8080/', null);
      // Encode the discovery document for the Tester API as json.
      var json = discoveryDocSchema.toResponse(discoveryDoc);
      expect(json['methods'], expectedJsonMethods);
    });

    test('misconfig', () {
      var parser = new ApiParser();
      ApiConfig apiConfig = parser.parse(new WrongQueryParameterTester());
      expect(parser.isValid, isFalse);
      var errors = [
        new ApiConfigError('WrongQueryParameterTester.query1: Non-path '
            'parameter \'path\' must be a named parameter.'),
        new ApiConfigError('WrongQueryParameterTester.query2: Expected method '
            'parameter with name \'queryParam\', but found parameter with '
            'name \'pathParam\'.'),
        new ApiConfigError('WrongQueryParameterTester.query3: Query parameter '
            '\'queryParam\' must be of type int or String.'),
        new ApiConfigError('WrongQueryParameterTester.query4: No support for '
            'optional path parameters in API methods.'),
        new ApiConfigError('WrongQueryParameterTester.query5: Non-path '
            'parameter \'queryParam\' must be a named parameter.')];
      expect(parser.errors.toString(), errors.toString());
    });
  });
}
