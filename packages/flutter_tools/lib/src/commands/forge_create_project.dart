
import 'package:meta/meta.dart';

import '../android/gradle_utils.dart' as gradle;
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/utils.dart';
import '../cache.dart';
import '../forge_project_metadata.dart';
import '../globals.dart' as globals;
import '../globals.dart';
import '../ios/code_signing.dart';
import '../runner/flutter_command.dart';
import 'forge_create.dart';

class ForgeCreateProjectCommand extends ForgeCreateSubCommand {
  ForgeCreateProjectCommand({
    required super.logger,
    required super.verboseHelp,
    required super.fileSystem,
  });

  final String dartSdk = globals.cache.dartSdkBuild;

  @override
  String get description => 'Create a new Flutter project.';

  @override
  String get name => 'project';

  /// Throw with exit code 2 if the output directory is invalid.
  @protected
  void validateOutputDirectoryArg() {
    final List<String>? rest = argResults?.rest;
    if (rest == null || rest.isEmpty) {
      throwToolExit(
        'No option specified for the output directory.\n$usage',
        exitCode: 2,
      );
    }

    if (rest.length > 1) {
      String message = 'Multiple output directories specified.';
      for (final String arg in rest) {
        if (arg.startsWith('-')) {
          message += '\nTry moving $arg to be immediately following $name';
          break;
        }
      }
      throwToolExit(message, exitCode: 2);
    }
  }

  /// Gets the flutter root directory.
  @protected
  String get flutterRoot => Cache.flutterRoot!;

  @override
  Future<FlutterCommandResult> runCommand() async {
    logger.printStatus('Creating a new Flutter project...');

    validateOutputDirectoryArg();

    String projectName = '';
    while (true) {
      projectName = askQuestion(
          'Enter the name of your project: (hello_world)',
          defaultValue: 'hello_world');
      final String? error = validateProjectName(projectName);
      if (error != null) {
        logger.printError(error);
      } else {
        break;
      }
    }

    final String orgName = askQuestion(
        'Enter the name of your organization: (com.example)',
        defaultValue: 'com.example');
    final String description = askQuestion(
        'Enter a description for your app: (A new Flutter project)',
        defaultValue: 'A new Flutter project');

    const bool includeIos = true;
    const bool includeAndroid = true;
    const bool includeWeb = true;
    const bool includeLinux = true;
    const bool includeMacos = true;
    const bool includeWindows = true;

    final String? developmentTeam = await getCodeSigningIdentityDevelopmentTeam(
      processManager: globals.processManager,
      platform: globals.platform,
      logger: globals.logger,
      config: globals.config,
      terminal: globals.terminal,
    );

    // The dart project_name is in snake_case, this variable is the Title Case of the Project Name.
    final String titleCaseProjectName = snakeCaseToTitleCase(projectName);
    final String camelCaseProjectName = camelCase(projectName);
    final String concatenatedCaseProjectName = concatenatedCase(projectName);
    final String pascalCaseProjectName = pascalCase(projectName);

    final Map<String, Object?> templateContext = createTemplateContext(
      organization: orgName,
      projectName: projectName,
      titleCaseProjectName: titleCaseProjectName,
      pascalCaseProjectName: pascalCaseProjectName,
      camelCaseProjectName: camelCaseProjectName,
      concatenatedCaseProjectName: concatenatedCaseProjectName,
      projectDescription: description,
      flutterRoot: flutterRoot,
      androidLanguage: 'kotlin',
      iosLanguage: 'swift',
      iosDevelopmentTeam: developmentTeam,
      ios: includeIos,
      android: includeAndroid,
      web: includeWeb,
      linux: includeLinux,
      macos: includeMacos,
      windows: includeWindows,
      dartSdkVersionBounds: "'>=3.4.3 <4.0.0'",
      agpVersion: gradle.templateAndroidGradlePluginVersion,
      kotlinVersion: gradle.templateKotlinGradlePluginVersion,
      gradleVersion: gradle.templateDefaultGradleVersion,
    );

    final String relativeDirPath = globals.fs.path.relative(projectDirPath);
    final bool creatingNewProject =
        !projectDir.existsSync() || projectDir
            .listSync()
            .isEmpty;
    if (creatingNewProject) {
      logger.printStatus('Creating project $relativeDirPath...');
    } else {
      throwToolExit(
          'The project directory is not empty. Please make sure the directory is empty before proceeding.');
    }

    final Directory relativeDir = globals.fs.directory(projectDirPath);
    int generatedFileCount = 0;
    generatedFileCount += await generateApp(
      <String>['forge', 'forge_shared'],
      relativeDir,
      templateContext,
      printStatusWhenWriting: !creatingNewProject,
      projectType: ForgeProjectType.app,
    );

    globals.printStatus('Wrote $generatedFileCount files.');
    globals.printStatus('\nAll done!');
    globals.printStatus(r'''
In order to run your application, type:

  $ dart run build_runner build --delete-conflicting-outputs
  $ melos bootstrap
  $ flutter run

''');

    return FlutterCommandResult.success();
  }
}