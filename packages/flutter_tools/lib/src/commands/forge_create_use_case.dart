import 'dart:io' as io;

import 'package:built_value/json_object.dart';
import 'package:meta/meta.dart';
import 'package:shelf/shelf_io.dart';
import 'package:vm_snapshot_analysis/v8_profile.dart';

import '../android/gradle_utils.dart' as gradle;
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/template.dart';
import '../base/utils.dart';
import '../cache.dart';
import '../flutter_project_metadata.dart';
import '../forge/pluralize/pluralize.dart';
import '../forge_project_metadata.dart';
import '../globals.dart' as globals;
import '../globals.dart';
import '../ios/code_signing.dart';
import '../runner/flutter_command.dart';
import 'forge_create.dart';

class ForgeCreateUseCaseCommand extends ForgeCreateSubCommand {
  ForgeCreateUseCaseCommand({
    required super.logger,
    required super.verboseHelp,
    required super.fileSystem,
    TemplateRenderer? templateRenderer,
  }) : _templateRenderer = templateRenderer ?? globals.templateRenderer;

  final TemplateRenderer _templateRenderer;
  final String dartSdk = globals.cache.dartSdkBuild;

  @override
  String get description => 'Create use case.';

  @override
  String get name => 'use-case';

  /// Throw with exit code 2 if the output directory is invalid.
  @protected
  void validateArgs() {
    final List<String>? rest = argResults?.rest;
    if (rest == null || rest.isEmpty) {
      throwToolExit(
        'No option specified for the output directory.\n$usage',
        exitCode: 2,
      );
    }

    // if (rest.length < 3) {
    //   throwToolExit(
    //     'Not enough arguments specified to generate a data class.'
    //     '\nflutter-me forge-create data-class . User id:int name:String',
    //     exitCode: 2,
    //   );
    // }
  }

  /// Gets the flutter root directory.
  @protected
  String get flutterRoot => Cache.flutterRoot!;

  List<String> listSubdirectories(Directory dir, [String prefix = '']) {
    final directories = <String>[];
    final entities = dir.listSync(recursive: false, followLinks: false);

    for (var entity in entities) {
      if (entity is Directory) {
        final relativePath = prefix.isEmpty
            ? entity.path
            : '$prefix/${entity.path.split('/').last}';
        directories.add(relativePath);
        directories.addAll(listSubdirectories(entity, relativePath));
      }
    }
    return directories;
  }

  String askDirectory(List<String> directories) {
    while (true) {
      logger.printStatus('Enter the directory number or name:');
      final input = io.stdin.readLineSync();
      if (input == 'Q' || input == 'q') {
        throwToolExit('Exiting... askDirectory', exitCode: 0);
      }

      if (input == 'N' || input == 'n') {
        print('Enter the directory name:');
        return io.stdin.readLineSync() ?? '';
      } else if (input != null && int.tryParse(input) != null) {
        final index = int.parse(input);
        if (index == 1) {
          return '';
        } else if (index > 1 && index <= directories.length + 1) {
          return directories[index - 2];
        }
      } else {
        return input ?? '';
      }
    }
  }

  String askUseCaseDirectory() {
    final useCaseDirectoryPath = fs.path.join(
      projectDirPath,
      'packages',
      'core',
      'domain',
      'lib',
      'src',
      'use_case',
    );
    final useCaseDirectory = fs.directory(useCaseDirectoryPath);
    final useCaseSubdirectories = listSubdirectories(useCaseDirectory);

    logger.printStatus('Choose a directory to generate the use case:');
    logger.printStatus('1. . [Default use case directory]');
    for (var i = 0; i < useCaseSubdirectories.length; i++) {
      logger.printStatus(
          '${i + 2}. ${useCaseSubdirectories[i].substring(useCaseDirectoryPath.length + 1)}');
    }
    logger.printStatus('Q. *Quit');
    return askDirectory(useCaseSubdirectories);
  }

  String askUseCaseType() {
    logger.printStatus('Choose the type of use case:');
    logger.printStatus('1. observe');
    logger.printStatus('2. get');
    logger.printStatus('3. create');
    logger.printStatus('4. update');
    logger.printStatus('5. delete');
    logger.printStatus('6. other');
    logger.printStatus('Q: *Quit');

    String? useCaseType;
    while (useCaseType == null) {
      final input = io.stdin.readLineSync();
      if (input == 'Q' || input == 'q') {
        throwToolExit('Exiting... askUseCaseType', exitCode: 0);
      }
      if (input != null && int.tryParse(input) != null) {
        final index = int.parse(input);
        switch (index) {
          case 1:
            useCaseType = 'observe';
            break;
          case 2:
            useCaseType = 'get';
            break;
          case 3:
            useCaseType = 'create';
            break;
          case 4:
            useCaseType = 'update';
            break;
          case 5:
            useCaseType = 'delete';
            break;
          case 6:
            print('Enter the use case type:');
            useCaseType = io.stdin.readLineSync();
            break;
          default:
            break;
        }
      } else {
        useCaseType = input;
      }
    }
    return useCaseType;
  }

  String _parseModelName(String input) {
    return input.split(' ').first;
  }

  List<Map<String, String>> _parseModelFields(String input) {
    final fieldsString = input.split(' ').skip(1);
    final List<Map<String, String>> fields = fieldsString.map((String arg) {
      final List<String> parts = arg.split(':');
      return <String, String>{'name': parts[0], 'type': parts[1]};
    }).toList();
    return fields;
  }

  ({
    String? modelName,
    List<Map<String, String>> modelFields,
    File? modelFile,
  }) askModel() {
    final modelDirectoryPath = fs.path.join(
      projectDirPath,
      'packages',
      'core',
      'domain',
      'lib',
      'src',
      'models',
    );
    final modelDirectory = fs.directory(modelDirectoryPath);
    final modelFiles = modelDirectory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.uri.pathSegments.last != 'models.dart')
        // .map((file) => (file.uri.pathSegments.last.split('.dart').first, file))
        .toList();

    logger.printStatus('Choose an existing model or create a new one:');
    for (var i = 0; i < modelFiles.length; i++) {
      // TODO(toe): read the model file and parse the class name
      final file = modelFiles[i];
      final fileName = file.uri.pathSegments.last.split('.dart').first;
      logger.printStatus('${i + 1}. ${pascalCase(fileName)}');
    }
    logger.printStatus('N. Create a new model');
    logger.printStatus('Q. *Quit');

    String? modelName;
    File? modelFile;
    List<Map<String, String>> modelFields = [];
    while (modelName == null) {
      final input = io.stdin.readLineSync();
      if (input == 'Q' || input == 'q') {
        throwToolExit('Exiting...askModel', exitCode: 0);
      }

      if (input == 'N' || input == 'n') {
        logger.printStatus('Enter the model name and fields:');
        final modelInput = io.stdin.readLineSync();
        if (modelInput == 'Q' || modelInput == 'q') {
          throwToolExit('Exiting... askModel', exitCode: 0);
        }
        if (modelInput == null) {
          throwToolExit('Invalid input. Please try again.', exitCode: 2);
        }
        modelName = _parseModelName(modelInput);
        modelFields = _parseModelFields(modelInput);
        final newModelDirectoryInput = askModelDirectory();
        final newModelDirectoryPath = fileSystem.path.join(
          modelDirectoryPath,
          newModelDirectoryInput,
          snakeCase('$modelName.dart'),
        );
        modelFile = fileSystem.file(newModelDirectoryPath);
      } else if (input != null && int.tryParse(input) != null) {
        final index = int.parse(input);
        if (index > 0 && index <= modelFiles.length) {
          modelName = pascalCase(
              modelFiles[index - 1].uri.pathSegments.last.split('.dart').first);
          modelFile = modelFiles[index - 1];
          break;
        } else {
          throwToolExit('Invalid input. Please try again.', exitCode: 2);
        }
      } else {
        if (input == null) {
          throwToolExit('Invalid input. Please try again.', exitCode: 2);
        }
        modelName = _parseModelName(input);
        modelFields = _parseModelFields(input);
        final newModelDirectoryInput = askModelDirectory();
        final newModelDirectoryPath = fileSystem.path.join(
          modelDirectoryPath,
          newModelDirectoryInput,
          snakeCase('$modelName.dart'),
        );
        modelFile = fileSystem.file(newModelDirectoryPath);
      }
    }

    return (
      modelName: modelName,
      modelFile: modelFile,
      modelFields: modelFields
    );
  }

  String askModelDirectory() {
    final modelDirectoryPath = fs.path.join(
      projectDirPath,
      'packages',
      'core',
      'domain',
      'lib',
      'src',
      'models',
    );
    final modelDirectory = fs.directory(modelDirectoryPath);
    final modelSubdirectories = listSubdirectories(modelDirectory);

    logger.printStatus('Choose a directory to generate the model:');
    logger.printStatus('1. . [Default model directory]');
    for (var i = 0; i < modelSubdirectories.length; i++) {
      logger.printStatus(
          '${i + 2}. ${modelSubdirectories[i].substring(modelDirectoryPath.length + 1)}');
    }
    logger.printStatus('N. New directory');
    logger.printStatus('Q. *Quit');
    return askDirectory(modelSubdirectories);
  }

  ({String? repoFileName, File? repoFile}) askRepository(String modelFileName) {
    logger.printStatus('askRepository: modelName: $modelFileName');

    final repositoryFileName = '${modelFileName}_repository.dart';
    final directoryPath = fs.path.join(
      projectDirPath,
      'packages',
      'core',
      'domain',
      'lib',
      'src',
      'repositories',
    );

    final directory = fs.directory(directoryPath);
    File? repositoryFile = directory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.uri.pathSegments.last == repositoryFileName)
        .firstOrNull;

    if (repositoryFile == null) {
      final newRepositoryDirectory = askRepositoryDirectory();
      final newRepositoryDirectoryPath = fs.path.join(
        directoryPath,
        newRepositoryDirectory,
        repositoryFileName,
      );
      repositoryFile = fs.file(newRepositoryDirectoryPath);
    }
    return (repoFileName: repositoryFileName, repoFile: repositoryFile);
  }

  String askRepositoryDirectory() {
    final repoDirectoryPath = fs.path.join(
      projectDirPath,
      'packages',
      'core',
      'domain',
      'lib',
      'src',
      'repositories',
    );
    final directory = fs.directory(repoDirectoryPath);
    final subdirectories = listSubdirectories(directory);

    logger.printStatus('Choose a directory to generate the repository:');
    logger.printStatus('1. . [Default repository directory]');
    for (var i = 0; i < subdirectories.length; i++) {
      logger.printStatus(
          '${i + 2}. ${subdirectories[i].substring(repoDirectoryPath.length + 1)}');
    }
    logger.printStatus('N. New directory');
    logger.printStatus('Q. *Quit');
    return askDirectory(subdirectories);
  }

  bool askIsList() {
    while (true) {
      print('Is the return type a single instance or a list? (single/list)');
      final returnTypeInput = io.stdin.readLineSync()?.toLowerCase();
      if (returnTypeInput == 'q' || returnTypeInput == 'quit') {
        throwToolExit('Exiting... askReturnType', exitCode: 0);
      }

      if (returnTypeInput == null ||
          !(returnTypeInput == 'single' ||
              returnTypeInput == 's' ||
              returnTypeInput == 'list' ||
              returnTypeInput == 'l')) {
        continue;
      }

      return returnTypeInput == 'list' || returnTypeInput == 'l';
    }
  }

  bool askEnclosedWithResult() {
    while (true) {
      logger.printStatus(
          'Should the result be enclosed in Result model? (yes/no)');
      final input = io.stdin.readLineSync()?.toLowerCase();
      if (input == 'q' || input == 'quit') {
        throwToolExit('Exiting... askEnclosedWithResult', exitCode: 0);
      }

      if (input == null ||
          !(input == 'y' || input == 'yes' || input == 'n' || input == 'no')) {
        continue;
      }

      return input == 'y' || input == 'yes';
    }
  }

  String _buildReturnType({
    required String useCaseType,
    required bool enclosedWithResult,
    required bool isList,
    required String modelName,
  }) {
    if (useCaseType == 'observe') {
      if (enclosedWithResult) {
        if (isList) {
          return 'Stream<Result<List<$modelName>>>';
        } else {
          return 'Stream<Result<$modelName>>';
        }
      } else {
        return 'Stream<$modelName>';
      }
    } else {
      if (enclosedWithResult) {
        if (isList) {
          return 'Future<Result<List<$modelName>>>';
        } else {
          return 'Future<Result<$modelName>>';
        }
      } else {
        return 'Future<$modelName>';
      }
    }
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    logger.printStatus('Creating use case ...');

    validateArgs();

    final projectType = getProjectType(projectDir);
    if (projectType == ForgeProjectType.unknown) {
      throwToolExit(
        'The project type is unknown. Please run this command in the root of a Flutter Forge project.',
        exitCode: 2,
      );
    }
    logger.printStatus('projectType: $projectType');

    validateArgs();

    final useCaseDirectoryPath = fs.path.join(
      projectDirPath,
      'packages',
      'core',
      'domain',
      'lib',
      'src',
      'use_case',
    );

    final repoDirectoryPath = fs.path.join(
      projectDirPath,
      'packages',
      'core',
      'domain',
      'lib',
      'src',
      'repositories',
    );
    final modelDirectoryPath = fs.path.join(
      projectDirPath,
      'packages',
      'core',
      'domain',
      'lib',
      'src',
      'models',
    );

    final String useCaseDirectory = askUseCaseDirectory();
    final String useCaseType = askUseCaseType();
    final (:modelName, :modelFile, :modelFields) = askModel();
    final isList = askYesNoQuestion('Is the return type a list?(y/n)');
    final resultEnclosed = askEnclosedWithResult();
    final (:repoFileName, :repoFile) = askRepository(
        modelFile?.uri.pathSegments.last.split('.dart').first ?? '');

    if (modelName == null ||
        modelFile == null ||
        repoFileName == null ||
        repoFile == null) {
      throwToolExit(
          'Exiting... ModelName;$modelName, '
          'ModelFile:$modelFile, '
          'RepoFileName:$repoFileName, '
          'RepoFile:$repoFile',
          exitCode: 0);
    }

    final pluralizedModelName =
        isList ? Pluralize().plural(modelName) : modelName;
    final returnType = _buildReturnType(
      useCaseType: useCaseType,
      enclosedWithResult: resultEnclosed,
      isList: isList,
      modelName: modelName,
    );
    final File useCaseFile = fs.file(fs.path.join(
      useCaseDirectoryPath,
      useCaseDirectory,
      '${useCaseType}_${snakeCase(pluralizedModelName)}_use_case.dart',
    ));

    // create or append content to the repository file
    if (!repoFile.existsSync()) {
      final String absoluteSourcePath = globals.fs.path.join(
        flutterToolsAbsolutePath,
        'templates',
        'forge_templates',
        'domain',
        'repositories',
        'repository.dart.tmpl',
      );

      final String templateContents = readTemplateContent(absoluteSourcePath);
      final String renderedContents =
          _templateRenderer.renderString(templateContents, <String, Object>{
        'modelName': modelName,
        'returnType': returnType,
        'methodName': '$useCaseType$pluralizedModelName',
      });
      repoFile.createSync(recursive: true);
      repoFile.writeAsStringSync(renderedContents);

      // append export to barrel file
      final repositoriesBarrelFile = fs.file(fs.path.join(
        repoDirectoryPath,
        'repositories.dart',
      ));
      final repoExportPath = repoFile.path
          .substring(repoDirectoryPath.length + 1)
          .replaceAll('\\', '/');
      appendTextToFile(repositoriesBarrelFile, "\nexport '$repoExportPath';");
    } else {
      final String absoluteSourcePath = globals.fs.path.join(
        flutterToolsAbsolutePath,
        'templates',
        'forge_templates',
        'domain',
        'repositories',
        'repository_method.dart.tmpl',
      );

      final String templateContents = readTemplateContent(absoluteSourcePath);
      final String renderedContents =
          _templateRenderer.renderString(templateContents, <String, Object>{
        'returnType': returnType,
        'methodName': '$useCaseType$pluralizedModelName',
      });
      final existingRepositoryContent = repoFile.readAsStringSync();
      final updatedRepositoryContent = existingRepositoryContent.replaceFirst(
          RegExp(r'}\s*$'), '$renderedContents\n}');
      repoFile.writeAsStringSync(updatedRepositoryContent);
    }

    // create and render model file
    if (!modelFile.existsSync()) {
      final String absoluteSourcePath = globals.fs.path.join(
        flutterToolsAbsolutePath,
        'templates',
        'forge_templates',
        'domain',
        'models',
        'model.dart.tmpl',
      );

      final bool hasNonPrimitive = modelFields.any((Map<String, String> field) => !isPrimitive(field['type']!));

      final String templateContents = readTemplateContent(absoluteSourcePath);
      final String renderedContents =
      _templateRenderer.renderString(templateContents, <String, Object>{
        'className': modelName,
        'fields': modelFields,
        'hasNonPrimitive': hasNonPrimitive,
      });

      modelFile.createSync(recursive: true);
      modelFile.writeAsStringSync(renderedContents);

      // append export to barrel file
      final modelsBarrelFile = fs.file(fs.path.join(
        modelDirectoryPath,
        'models.dart',
      ));
      final modelExportPath = modelFile.path
          .substring(modelDirectoryPath.length + 1)
          .replaceAll(r'\', '/');
      appendTextToFile(modelsBarrelFile, "\nexport '$modelExportPath';");
    }

    if (useCaseFile.existsSync()) {
      throwToolExit(
        'File ${useCaseFile.path} already exists.',
        exitCode: 2,
      );
    }

    // create and render use case file
    final String absoluteSourcePath = globals.fs.path.join(
      flutterToolsAbsolutePath,
      'templates',
      'forge_templates',
      'domain',
      'use_case',
      'use_case.dart.tmpl',
    );

    final String templateContents = readTemplateContent(absoluteSourcePath);
    final String renderedContents =
    _templateRenderer.renderString(templateContents, <String, Object>{
      'useCaseClass': '${pascalCase(useCaseType)}${pascalCase(pluralizedModelName)}UseCase',
      'modelRepository': '${pascalCase(modelName)}Repository',
      'repositoryInstance': '${snakeCase(modelName)}Repository',
      'returnType': returnType,
      'useCaseMethod': '$useCaseType$pluralizedModelName',
    });

    useCaseFile.writeAsStringSync(renderedContents);
    // append export to barrel file
    final useCasesBarrelFile = fs.file(fs.path.join(
      useCaseDirectoryPath,
      'use_case.dart',
    ));
    final useCasesExportPath = useCaseFile.path
        .substring(useCaseDirectoryPath.length + 1)
        .replaceAll(r'\', '/');
    appendTextToFile(useCasesBarrelFile, "\nexport '$useCasesExportPath';");

    logger.printStatus('Use case created successfully.');
    logger.printStatus('Files created or updated:');
    logger.printStatus('Model: ${modelFile.path.substring(projectDirPath.length + 1)}');
    logger.printStatus('Repository: ${repoFile.path.substring(projectDirPath.length + 1)}');
    logger.printStatus('Use case: ${useCaseFile.path.substring(projectDirPath.length + 1)}');

    return FlutterCommandResult.success();
  }
}
