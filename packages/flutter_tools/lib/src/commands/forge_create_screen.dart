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
import '../forge/tools/list_paths.dart';
import '../forge_project_metadata.dart';
import '../globals.dart' as globals;
import '../globals.dart';
import '../ios/code_signing.dart';
import '../runner/flutter_command.dart';
import 'forge_create.dart';

class ForgeCreateScreenCommand extends ForgeCreateSubCommand {
  ForgeCreateScreenCommand({
    required super.logger,
    required super.verboseHelp,
    required super.fileSystem,
    TemplateRenderer? templateRenderer,
  }) : _templateRenderer = templateRenderer ?? globals.templateRenderer;

  final TemplateRenderer _templateRenderer;
  final String dartSdk = globals.cache.dartSdkBuild;

  @override
  String get description => 'Create .';

  @override
  String get name => 'screen';

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

    if (rest.length < 2) {
      throwToolExit(
        'Not enough arguments specified to generate screen.'
        '\nflutter-me forge-create screen . [screen_name]',
        exitCode: 2,
      );
    }
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

  String askFeatures() {
    final featuresDirectoryPath =
        fs.path.join(projectDirPath, 'packages', 'features');
    final featureDirectory = fs.directory(featuresDirectoryPath);
    final featurePaths =
        featureDirectory.listSync(recursive: false, followLinks: false);

    while (true) {
      logger.printStatus('Choose a features to generate the screen:');
      for (var i = 0; i < featurePaths.length; i++) {
        logger.printStatus(
            '${i + 1}. ${featurePaths[i].path.substring(featuresDirectoryPath.length + 1)}');
      }
      logger.printStatus('Q. *Quit');
      final input = io.stdin.readLineSync();
      if (input == 'q' || input == 'Q') {
        throwToolExit('Exiting...');
      }

      final featureIndex = int.tryParse(input ?? '');
      if (featureIndex == null ||
          featureIndex < 1 ||
          featureIndex > featurePaths.length) {
        continue;
      }

      final featurePath = featurePaths[featureIndex - 1].path;
      return featurePath;
    }
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    logger.printStatus('Creating screen...');

    validateArgs();

    final projectType = getProjectType(projectDir);
    if (projectType == ForgeProjectType.unknown) {
      throwToolExit(
        'The project type is unknown. Please run this command in the root of a Flutter Forge project.',
        exitCode: 2,
      );
    }
    logger.printStatus('projectType: $projectType');

    final directory = argResults!.rest[0];
    final screenName = argResults!.rest[1];

    final featureAbsolutePath = askFeatures();

    final String absoluteSourcePath = globals.fs.path.join(
      flutterToolsAbsolutePath,
      'templates',
      'forge_templates',
      'screen',
    );
    final absoluteSourceDirectory = fileSystem.directory(absoluteSourcePath);
    final templateFiles = absoluteSourceDirectory
        .listSync(recursive: true, followLinks: false)
        .where((file) => file is File)
        .where((file) => file.uri.pathSegments.last.endsWith('.tmpl'));

    final destinationAbsolutePath = globals.fs.path.join(
      featureAbsolutePath,
      'lib',
      'src',
      screenName,
    );

    final destinationDirectory = fileSystem.directory(destinationAbsolutePath);
    if (!destinationDirectory.existsSync()) {
      destinationDirectory.createSync(recursive: true);
    }

    // check directory empty
    final destinationFiles = destinationDirectory.listSync();
    if (destinationFiles.isNotEmpty) {
      throwToolExit(
        'The destination directory is not empty. Please provide an empty directory.',
        exitCode: 2,
      );
    }

    final pascalCaseScreenName = pascalCase(screenName);
    final snakeCaseScreenName = snakeCase(screenName);
    final titleCaseScreenName = snakeCaseToTitleCase(snakeCaseScreenName);

    final context = <String, dynamic>{
      'screen_name': screenName,
      'featureName': featureAbsolutePath.split('/').last,
      'bloc_class': '${pascalCaseScreenName}Bloc',
      'event_base_class': '${pascalCaseScreenName}Event',
      'event_fetched_class': '${pascalCaseScreenName}Fetched',
      'state_class': '${pascalCaseScreenName}State',
      'screen_class': '${pascalCaseScreenName}Screen',
      'screen_entry_class': '${pascalCaseScreenName}ScreenEntry',
      'sample_id': 'sampleId',
      'event_file': '${snakeCaseScreenName}_event.dart',
      'state_file': '${snakeCaseScreenName}_state.dart',
      'bloc_file': '${snakeCaseScreenName}_bloc.dart',
      'screen_title': titleCaseScreenName,
      'screen_file': '${snakeCaseScreenName}_screen.dart',
    };

    int generatedFiles = 0;
    for (final FileSystemEntity entity in templateFiles) {
      final templateFile = fileSystem.file(entity.path);
      final templateFileRelativePath =
      entity.path.substring(absoluteSourcePath.length + 1);

      if (templateFileRelativePath.endsWith('.copy.tmpl')) {
        String finalDestinationPath = fileSystem.path.join(
          destinationAbsolutePath,
          templateFileRelativePath.replaceAll('.copy.tmpl', ''),
        );
        finalDestinationPath =
            _templateRenderer.renderString(finalDestinationPath, context);
        final File finalDestinationFile = fileSystem.file(finalDestinationPath);
        if (!finalDestinationFile.existsSync()) {
          finalDestinationFile.createSync(recursive: true);
        }
        templateFile.copySync(finalDestinationPath);
        generatedFiles++;
      } else {
        String finalDestinationPath = fileSystem.path.join(
          destinationAbsolutePath,
          templateFileRelativePath.replaceAll('.tmpl', ''),
        );
        finalDestinationPath =
            _templateRenderer.renderString(finalDestinationPath, context);
        final templateContents = templateFile.readAsStringSync();
        final File finalDestinationFile = fileSystem.file(finalDestinationPath);
        if (!finalDestinationFile.existsSync()) {
          finalDestinationFile.createSync(recursive: true);
        }
        final String renderedContents =
        _templateRenderer.renderString(templateContents, context);
        finalDestinationFile.writeAsStringSync(renderedContents);
        generatedFiles++;
      }
    }

    logger.printStatus('Screen created successfully.');
    logger.printStatus('Generated $generatedFiles files.');

    return FlutterCommandResult.success();
  }
}
