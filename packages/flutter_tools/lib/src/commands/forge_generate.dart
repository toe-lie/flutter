// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:meta/meta.dart';

import '../../src/macos/xcode.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../build_info.dart';
import '../globals.dart' as globals;
import '../ios/xcodeproj.dart';
import '../project.dart';
import '../runner/flutter_command.dart';

class ForgeGenerateCommand extends FlutterCommand {
  ForgeGenerateCommand({
    bool verbose = false,
  }) : _verbose = verbose;

  final bool _verbose;

  static const int optionNewProject = 1;
  static const int optionNewFeature = 2;
  static const int optionNewDomainModel = 3;
  static const int optionNewUseCase = 4;
  static const int optionNewRepository = 5;
  static const int optionNewUiLayer = 6;
  static const int optionNewScreen = 7;
  static const int optionNewBloc = 8;
  static const int optionNewTable = 9;
  static const int optionNewDao = 10;

  @override
  final String name = 'forge-generate';

  @override
  final String description = 'Generates code for a new project or feature.';

  @override
  String get category => FlutterCommandCategory.tools;

  final Logger _logger = globals.logger;
  @override
  Future<FlutterCommandResult> runCommand() async {
    _logger.printBox('Welcome to Forge Generator!');

    // Handle Ctrl+C to exit the program gracefully
    ProcessSignal.sigint.watch().listen((ProcessSignal signal) {
      _logger.printStatus('\nSetup interrupted. Exiting...');
      exit(0);
    });

    while (true) {
      _logger.printStatus('\nPlease select an option:');
      _logger.printStatus('$optionNewProject. Generate a new project');
      _logger.printStatus('$optionNewFeature. Generate a new feature');
      _logger.printStatus('$optionNewDomainModel. Generate a new domain model');
      _logger.printStatus('$optionNewUseCase. Generate a new use case');
      _logger.printStatus('$optionNewRepository. Generate a new repository');
      _logger.printStatus('$optionNewUiLayer. Generate a new UI layer');
      _logger.printStatus('$optionNewScreen. Generate a new screen');
      _logger.printStatus('$optionNewBloc. Generate a new BLoC');
      _logger.printStatus('$optionNewTable. Generate a new table');
      _logger.printStatus('$optionNewDao. Generate a new DAO');
      _logger.printStatus('Type "exit" to exit the setup');

      stdout.write('Enter your choice: ');
      final String? choice = stdin.readLineSync()?.trim().toLowerCase();
      final int? choiceInt = int.tryParse(choice ?? '');
      if (choiceInt == null) {
        _logger.printStatus('Exiting setup. Goodbye!');
        return const FlutterCommandResult(ExitStatus.success);
      }
      switch (choiceInt) {
        case optionNewProject:
          setupNewProject();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewFeature:
          setupNewFeature();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewDomainModel:
          setupNewDomainModel();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewUseCase:
          setupNewFeature();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewRepository:
          setupNewFeature();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewUiLayer:
          setupNewFeature();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewScreen:
          setupNewFeature();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewBloc:
          setupNewFeature();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewTable:
          setupNewFeature();
          return const FlutterCommandResult(ExitStatus.success);
        case optionNewDao:
          setupNewFeature();
          return const FlutterCommandResult(ExitStatus.success);
        default:
          _logger.printStatus(
              'Invalid choice. Please enter a number between 1 and 10, or "exit".');
          break;
      }
    }
  }

  //   final String appName = _askQuestion('Enter the name of your app:');
  //   final String packageName = _askQuestion('Enter the package name (e.g., com.example.app):');
  //   final String description = _askQuestion('Enter a short description of your app:');
  //   final String version = _askQuestion('Enter the app version (e.g., 1.0.0):', defaultValue: '1.0.0');
  //   final String sdkVersion = _askQuestion('Enter the Flutter SDK version (e.g., >=2.12.0 <3.0.0):', defaultValue: '>=2.12.0 <3.0.0');
  //   final bool useFirebase = _askYesNoQuestion('Do you want to use Firebase? (y/n):');
  //
  //   print('\nApp Information:');
  //   print('App Name: $appName');
  //   print('Package Name: $packageName');
  //   print('Description: $description');
  //   print('Version: $version');
  //   print('Flutter SDK Version: $sdkVersion');
  //   print('Use Firebase: ${useFirebase ? 'Yes' : 'No'}');
  //
  //   // Here you could proceed with creating the necessary files for the app
  //   return const FlutterCommandResult(ExitStatus.success);
  // //}

  String _askQuestion(String question, {String? defaultValue}) {
    stdout.write('$question ${defaultValue != null ? '($defaultValue) ' : ''}');
    final String? input = stdin.readLineSync();
    return input != null && input.isNotEmpty ? input : (defaultValue ?? '');
  }

  bool _askYesNoQuestion(String question) {
    while (true) {
      stdout.write(question);
      final String? input = stdin.readLineSync()?.toLowerCase();
      if (input == 'y' || input == 'yes') {
        return true;
      } else if (input == 'n' || input == 'no') {
        return false;
      } else {
        print('Invalid input, please enter "y" or "n".');
      }
    }
  }

  void setupNewProject() {}

  void setupNewFeature() {}

  void setupNewDomainModel() {
    print('Creating a new domain model...');
  }
}
