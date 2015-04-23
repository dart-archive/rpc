// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc_generator_tests;

import 'dart:io';

import 'package:discoveryapis_generator/src/utils.dart';
import 'package:path/path.dart';
import 'package:unittest/unittest.dart';


class GeneratorTestConfiguration extends SimpleConfiguration {

  Directory tmpDir;

  GeneratorTestConfiguration() {
    // We create our own tmp dir to make it easy to cleanup once the tests are
    // done, independent of whether they failed or not.
    tmpDir = Directory.systemTemp.createTempSync();
  }

  void onDone(bool success) {
    tmpDir.deleteSync(recursive: true);
    super.onDone(success);
  }
}

main() {
  var config = new GeneratorTestConfiguration();
  unittestConfiguration = config;
  var rpcRootPath = findPackageRoot('.');
  if (rpcRootPath == null && Platform.packageRoot != null) {
    rpcRootPath = findPackageRoot(Platform.packageRoot);
  }
  // Common path to the necessary test data.
  var dataPath = join(rpcRootPath, 'test', 'src', 'generator', 'data');

  void copyFiles(String srcPath, String dstPath, List<String> files) {
    assert(srcPath != null && srcPath.isNotEmpty);
    assert(dstPath != null && dstPath.isNotEmpty);
    assert(files != null && files.isNotEmpty);
    files.forEach((fileName) =>
        new File(join(srcPath, fileName)).copySync(join(dstPath, fileName)));
  }

  // Creates a package directory with a lib directory and an optional pubspec
  // file.
  String setupPackage({bool addPubSpec: true}) {
    var packagePath = absolute(config.tmpDir.createTempSync().path);
    new Directory(join(absolute(packagePath), 'lib')).createSync();
    if (addPubSpec) {
      new File(join(dataPath, 'pubspec.yamll'))
          .copySync(join(absolute(packagePath), 'pubspec.yaml'));
    }
    return packagePath;
  }

  ProcessResult runPub(String workingDir, List<String> arguments) {
    // We assume pub is placed next to the dart executable.
    var pubDir = new File(Platform.executable).parent;
    var pub = join(absolute(pubDir.path), 'pub');
    var pubFile = new File(pub);
    if (!pubFile.existsSync() && !Platform.isWindows) {
      pubDir = new File(Platform.environment['_']).parent;
      pub = join(absolute(pubDir.path), 'pub');
      pubFile = new File(pub);
    }
    if (pubFile.existsSync()) {
      return Process.runSync(pub, arguments, workingDirectory: workingDir);
    }
    return null;
  }

  ProcessResult runGenerator(String workingDir,
                              List<String> arguments) {
    var args = [join(rpcRootPath, 'bin', 'generate.dart')]..addAll(arguments);
    var dartFile = new File(Platform.executable);
    if (!dartFile.existsSync() && !Platform.isWindows) {
      dartFile = new File(Platform.environment['_']);
    }
    if (dartFile.existsSync()) {
      return Process.runSync(dartFile.path, args, workingDirectory: workingDir);
    }
    return null;
  }

  void checkFilesIdentical(String libPath, String actual, String expected) {
    var actualCode = new File(join(libPath, 'client', actual));
    var expectedCode = new File(join(dataPath, expected));
    expect(actualCode.readAsStringSync(), expectedCode.readAsStringSync());
  }

  group('rpc-generator-correct', () {
    test('multipleApis-discovery', () {
      var packagePath = setupPackage();
      var libPath = join(packagePath, 'lib');
      copyFiles(dataPath, libPath, ['multipleApis.dart',
                                    'multipleApisMessages.dart',
                                    'multipleApisResources.dart']);
      var result = runPub(packagePath, ['get']);
      if (result == null) {
        logMessage('Could not find pub. Skipping $currentTestCase!');
        return;
      }
      expect(result.exitCode, 0);
      result = runGenerator(
          packagePath, ['discovery', '-i', join(libPath, 'multipleApis.dart')]);
      if (result == null) {
        logMessage('Could not find dart. Skipping $currentTestCase!');
        return;
      }
      var expectedDiscovery =
          new File(join(dataPath, 'expected_multiple_discovery.json'));
      expect(result.stdout, expectedDiscovery.readAsStringSync());
    });

    test('multipleApis-client', () {
      var packagePath = setupPackage();
      var libPath = join(packagePath, 'lib');
      copyFiles(dataPath, libPath, ['multipleApis.dart',
                                    'multipleApisMessages.dart',
                                    'multipleApisResources.dart']);
      var result = runPub(packagePath, ['get']);
      if (result == null) {
        logMessage('Could not find pub. Skipping $currentTestCase!');
        return;
      }
      expect(result.exitCode, 0);
      result = runGenerator(
          packagePath, ['client', '-i', join(libPath, 'multipleApis.dart')]);
      if (result == null) {
        logMessage('Could not find dart. Skipping $currentTestCase!');
        return;
      }
      expect('[SUCCESS]'.allMatches(result.stdout).length, 2);
      checkFilesIdentical(
          libPath, 'apioneapi.dart', 'expected_apioneapi.dartt');
      checkFilesIdentical(
          libPath, 'apitwoapi.dart', 'expected_apitwoapi.dartt');
    });

    test('toyApi-discovery', () {
      var packagePath = setupPackage();
      var libPath = join(packagePath, 'lib');
      var rpcExamplePath = join(rpcRootPath, 'example');
      copyFiles(rpcExamplePath, libPath, ['toyapi.dart']);
      var result = runPub(packagePath, ['get']);
      if (result == null) {
        logMessage('Could not find pub. Skipping $currentTestCase!');
        return;
      }
      expect(result.exitCode, 0);
      result = runGenerator(
          packagePath, ['discovery', '-i', join(libPath, 'toyapi.dart')]);
      if (result == null) {
        logMessage('Could not find dart. Skipping $currentTestCase!');
        return;
      }
      var expectedDiscovery =
          new File(join(dataPath, 'expected_toy_discovery.json'));
      expect(result.stdout, expectedDiscovery.readAsStringSync());
    });

    test('toyApi-client', () {
      var packagePath = setupPackage();
      var libPath = join(packagePath, 'lib');
      var rpcExamplePath = join(rpcRootPath, 'example');
      copyFiles(rpcExamplePath, libPath, ['toyapi.dart']);
      var result = runPub(packagePath, ['get']);
      if (result == null) {
        logMessage('Could not find pub. Skipping $currentTestCase!');
        return;
      }
      expect(result.exitCode, 0);
      result = runGenerator(
          packagePath, ['client', '-i', join(libPath, 'toyapi.dart')]);
      if (result == null) {
        logMessage('Could not find dart. Skipping $currentTestCase!');
        return;
      }
      expect('[SUCCESS]'.allMatches(result.stdout).length, 1);
      checkFilesIdentical(libPath, 'toyapi.dart', 'expected_toyapi.dartt');
    });
  });

  group('rpc-generator-failing', () {
    test('wrong-api-file', () {
      var packagePath = setupPackage();
      var fileName =  join(packagePath, 'lib', 'toyapi.dart');
      var result = runGenerator(
          packagePath, ['discovery', '-i', fileName]);
      if (result == null) {
        logMessage('Could not find dart. Skipping $currentTestCase!');
        return;
      }
      expect(result.stdout.startsWith('Cannot find API file \'$fileName\''),
          isTrue);
    });

    test('no-pub-spec', () {
      var packagePath = setupPackage(addPubSpec: false);
      var libPath = join(packagePath, 'lib');
      var rpcExamplePath = join(rpcRootPath, 'example');
      copyFiles(rpcExamplePath, libPath, ['toyapi.dart']);
      var result = runGenerator(
          packagePath, ['client', '-i', join(libPath, 'toyapi.dart')]);
      if (result == null) {
        logMessage('Could not find dart. Skipping $currentTestCase!');
        return;
      }
      expect(result.stdout.contains('must be in a valid package.'), isTrue);
    });

    test('no-pub-get', () {
      var packagePath = setupPackage();
      var libPath = join(packagePath, 'lib');
      var rpcExamplePath = join(rpcRootPath, 'example');
      copyFiles(rpcExamplePath, libPath, ['toyapi.dart']);
      var result = runGenerator(
          packagePath, ['client', '-i', join(libPath, 'toyapi.dart')]);
      if (result == null) {
        logMessage('Could not find dart. Skipping $currentTestCase!');
        return;
      }
      expect(result.stdout.startsWith('Please run \'pub get\' in your API '
          'package before running the generator.'), isTrue);
    });

    test('no-default-constructor', () {
      var packagePath = setupPackage();
      var libPath = join(packagePath, 'lib');
      copyFiles(dataPath, libPath, ['noDefaultConstructorApi.dart']);
      var result = runPub(packagePath, ['get']);
      if (result == null) {
        logMessage('Could not find pub. Skipping $currentTestCase!');
        return;
      }
      expect(result.exitCode, 0);
      result = runGenerator(
          packagePath,
          ['client', '-i', join('lib', 'noDefaultConstructorApi.dart')]);
      if (result == null) {
        logMessage('Could not find dart. Skipping $currentTestCase!');
        return;
      }
      expect(result.stdout.startsWith('Failed to create an instance of the '
          'API class \'NoDefaultConstructorApi\'. For the generator to work '
          'the class must have a working default constructor taking no '
          'arguments.'), isTrue);
    });
  });
}
