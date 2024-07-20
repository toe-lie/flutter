import 'dart:io' as io;

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../android/android.dart' as android_common;
import '../android/android_workflow.dart';
import '../android/gradle_utils.dart' as gradle;
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/utils.dart';
import '../cache.dart';
import '../convert.dart';
import '../forge_project_metadata.dart';
import '../globals.dart' as globals;
import '../project.dart';
import '../runner/flutter_command.dart';
import '../template.dart';
import 'create_base.dart';
import 'forge_create_data_class.dart';
import 'forge_create_project.dart';

class ForgeCreateCommand extends FlutterCommand {
  ForgeCreateCommand({
    required Logger logger,
    required FileSystem fileSystem,
    bool verboseHelp = false,
  }) {
    _addSubcommand(ForgeCreateProjectCommand(
      logger: logger,
      verboseHelp: verboseHelp,
      fileSystem: fileSystem,
    ));
    _addSubcommand(ForgeCreateDataClassCommand(
      logger: logger,
      verboseHelp: verboseHelp,
      fileSystem: fileSystem,
    ));
  }

  void _addSubcommand(ForgeCreateSubCommand command) {
    if (command.supported) {
      addSubcommand(command);
    }
  }

  @override
  String get description =>
      'Create a new Flutter project or package or code snippet.';

  @override
  String get name => 'forge-create';

  @override
  Future<FlutterCommandResult> runCommand() async =>
      FlutterCommandResult.fail();
}

abstract class ForgeCreateSubCommand extends FlutterCommand {
  ForgeCreateSubCommand({
    required this.fileSystem,
    required this.logger,
    required bool verboseHelp,
  }) {
    usesFatalWarningsOption(verboseHelp: verboseHelp);
  }

  @protected
  final Logger logger;

  @protected
  final FileSystem fileSystem;

  @override
  bool get reportNullSafety => true;

  bool get supported => true;

  /// Whether [name] is a valid Pub package.
  @visibleForTesting
  bool isValidPackageName(String name) {
    final Match? match = _identifierRegExp.matchAsPrefix(name);
    return match != null &&
        match.end == name.length &&
        !_keywords.contains(name);
  }

  /// Returns a potential valid name from the given [name].
  ///
  /// If a valid name cannot be found, returns `null`.
  @visibleForTesting
  String? potentialValidPackageName(String name) {
    String newName = name.toLowerCase();
    if (newName.startsWith(RegExp(r'[0-9]'))) {
      newName = '_$newName';
    }
    newName = newName.replaceAll('-', '_');
    if (isValidPackageName(newName)) {
      return newName;
    } else {
      return null;
    }
  }

  late final Set<Uri> _templateManifest = _computeTemplateManifest();

  Set<Uri> _computeTemplateManifest() {
    final String flutterToolsAbsolutePath = globals.fs.path.join(
      Cache.flutterRoot!,
      'packages',
      'flutter_tools',
    );
    final String manifestPath = globals.fs.path.join(
      flutterToolsAbsolutePath,
      'templates',
      'forge_template_manifest.json',
    );
    final String manifestFileContents;
    try {
      manifestFileContents = globals.fs.file(manifestPath).readAsStringSync();
    } on FileSystemException catch (e) {
      throwToolExit(
        'Unable to read the template manifest at path "$manifestPath".\n'
        'Make sure that your user account has sufficient permissions to read this file.\n'
        'Exception details: $e',
      );
    }
    final Map<String, Object?> manifest = json.decode(
      manifestFileContents,
    ) as Map<String, Object?>;
    return Set<Uri>.from(
      (manifest['files']! as List<Object?>).cast<String>().map<Uri>(
          (String path) =>
              Uri.file(globals.fs.path.join(flutterToolsAbsolutePath, path))),
    );
  }

  /// Pattern for a Windows file system drive (e.g. "D:").
  ///
  /// `dart:io` does not recognize strings matching this pattern as absolute
  /// paths, as they have no top level back-slash; however, users often specify
  /// this
  @visibleForTesting
  static final RegExp kWindowsDrivePattern = RegExp(r'^[a-zA-Z]:$');

  /// The output directory of the command.
  @protected
  @visibleForTesting
  Directory get projectDir {
    final String argProjectDir = argResults!.rest.first;
    if (globals.platform.isWindows &&
        kWindowsDrivePattern.hasMatch(argProjectDir)) {
      throwToolExit(
        'You attempted to create a flutter project at the path "$argProjectDir", which is the name of a drive. This '
        'is usually a mistake--you probably want to specify a containing directory, like "$argProjectDir\\app_name". '
        'If you really want it at the drive root, re-run the command with the root directory after the drive, like '
        '"$argProjectDir\\".',
      );
    }
    return globals.fs.directory(argResults!.rest.first);
  }

  /// The normalized absolute path of [projectDir].
  @protected
  String get projectDirPath {
    return globals.fs.path.normalize(projectDir.absolute.path);
  }

  /// Creates a template to use for [renderTemplate].
  @protected
  Map<String, Object?> createTemplateContext({
    required String organization,
    required String projectName,
    required String titleCaseProjectName,
    required String camelCaseProjectName,
    required String pascalCaseProjectName,
    required String concatenatedCaseProjectName,
    String? projectDescription,
    String? androidLanguage,
    String? iosDevelopmentTeam,
    String? iosLanguage,
    required String flutterRoot,
    required String dartSdkVersionBounds,
    String? agpVersion,
    String? kotlinVersion,
    String? gradleVersion,
    bool withPlatformChannelPluginHook = false,
    bool withSwiftPackageManager = false,
    bool withFfiPluginHook = false,
    bool withFfiPackage = false,
    bool withEmptyMain = false,
    bool ios = false,
    bool android = false,
    bool web = false,
    bool linux = false,
    bool macos = false,
    bool windows = false,
    bool implementationTests = false,
  }) {
    final String appleIdentifier = CreateBase.createUTIIdentifier(
        organization, concatenatedCase(projectName));
    final String androidIdentifier = CreateBase.createAndroidIdentifier(
        organization, concatenatedCase(projectName));
    final String windowsIdentifier = CreateBase.createWindowsIdentifier(
        organization, concatenatedCase(projectName));
    // Linux uses the same scheme as the Android identifier.
    // https://developer.gnome.org/gio/stable/GApplication.html#g-application-id-is-valid
    final String linuxIdentifier = androidIdentifier;

    return <String, Object?>{
      'organization': organization,
      'projectName': projectName,
      'titleCaseProjectName': titleCaseProjectName,
      'camelCaseProjectName': camelCaseProjectName,
      'pascalCaseProjectName': pascalCaseProjectName,
      'concatenatedCaseProjectName': concatenatedCaseProjectName,
      'androidIdentifier': androidIdentifier,
      'iosIdentifier': appleIdentifier,
      'macosIdentifier': appleIdentifier,
      'linuxIdentifier': linuxIdentifier,
      'windowsIdentifier': windowsIdentifier,
      'description': projectDescription,
      'dartSdk': '$flutterRoot/bin/cache/dart-sdk',
      'androidMinApiLevel': android_common.minApiLevel,
      'androidSdkVersion': kAndroidSdkMinVersion,
      'pluginClass': '',
      'pluginClassSnakeCase': '',
      'pluginClassLowerCamelCase': '',
      'pluginClassCapitalSnakeCase': '',
      'pluginDartClass': '',
      'pluginProjectUUID': const Uuid().v4().toUpperCase(),
      'withFfi': withFfiPluginHook || withFfiPackage,
      'withFfiPackage': withFfiPackage,
      'withFfiPluginHook': withFfiPluginHook,
      'withPlatformChannelPluginHook': withPlatformChannelPluginHook,
      'withSwiftPackageManager': withSwiftPackageManager,
      'withPluginHook':
          withFfiPluginHook || withFfiPackage || withPlatformChannelPluginHook,
      'withEmptyMain': withEmptyMain,
      'androidLanguage': androidLanguage,
      'iosLanguage': iosLanguage,
      'hasIosDevelopmentTeam':
          iosDevelopmentTeam != null && iosDevelopmentTeam.isNotEmpty,
      'iosDevelopmentTeam': iosDevelopmentTeam ?? '',
      'flutterRevision':
          escapeYamlString(globals.flutterVersion.frameworkRevision),
      'flutterChannel': escapeYamlString(
          globals.flutterVersion.getBranchName()), // may contain PII
      'ios': ios,
      'android': android,
      'web': web,
      'linux': linux,
      'macos': macos,
      'windows': windows,
      'year': DateTime.now().year,
      'dartSdkVersionBounds': dartSdkVersionBounds,
      'implementationTests': implementationTests,
      'agpVersion': agpVersion,
      'agpVersionForModule': gradle.templateAndroidGradlePluginVersionForModule,
      'kotlinVersion': kotlinVersion,
      'gradleVersion': gradleVersion,
      'compileSdkVersion': gradle.compileSdkVersion,
      'minSdkVersion': gradle.minSdkVersion,
      'ndkVersion': gradle.ndkVersion,
      'targetSdkVersion': gradle.targetSdkVersion,
    };
  }

  /// Merges named templates into a single template, output to `directory`.
  ///
  /// `names` should match directory names under flutter_tools/template/.
  ///
  /// If `overwrite` is true, overwrites existing files, `overwrite` defaults to `false`.
  @protected
  Future<int> renderMerged(
    List<String> names,
    Directory directory,
    Map<String, Object?> context, {
    bool overwrite = false,
    bool printStatusWhenWriting = true,
  }) async {
    final Template template = await Template.merged(
      names,
      directory,
      fileSystem: globals.fs,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
      templateManifest: _templateManifest,
    );
    return template.render(
      directory,
      context,
      overwriteExisting: overwrite,
      printStatusWhenWriting: printStatusWhenWriting,
    );
  }

  /// Generate application project in the `directory` using `templateContext`.
  ///
  /// If `overwrite` is true, overwrites existing files, `overwrite` defaults to `false`.
  @protected
  Future<int> generateApp(
    List<String> templateNames,
    Directory directory,
    Map<String, Object?> templateContext, {
    bool overwrite = false,
    bool pluginExampleApp = false,
    bool printStatusWhenWriting = true,
    bool generateMetadata = true,
    ForgeProjectType? projectType,
  }) async {
    globals.logger.printStatus('Templates: $templateNames');
    int generatedCount = 0;
    generatedCount += await renderMerged(
      <String>[
        ...templateNames,
      ],
      directory,
      templateContext,
      overwrite: overwrite,
      printStatusWhenWriting: printStatusWhenWriting,
    );
    final FlutterProject project = FlutterProject.fromDirectory(directory);
    if (templateContext['android'] == true) {
      generatedCount += _injectGradleWrapper(project);
    }

    final bool androidPlatform = templateContext['android'] as bool? ?? false;
    final bool iosPlatform = templateContext['ios'] as bool? ?? false;
    final bool linuxPlatform = templateContext['linux'] as bool? ?? false;
    final bool macOSPlatform = templateContext['macos'] as bool? ?? false;
    final bool windowsPlatform = templateContext['windows'] as bool? ?? false;
    final bool webPlatform = templateContext['web'] as bool? ?? false;

    final List<SupportedPlatform> platformsForMigrateConfig =
        <SupportedPlatform>[SupportedPlatform.root];
    if (androidPlatform) {
      gradle.updateLocalProperties(project: project, requireAndroidSdk: false);
      platformsForMigrateConfig.add(SupportedPlatform.android);
    }
    if (iosPlatform) {
      platformsForMigrateConfig.add(SupportedPlatform.ios);
    }
    if (linuxPlatform) {
      platformsForMigrateConfig.add(SupportedPlatform.linux);
    }
    if (macOSPlatform) {
      platformsForMigrateConfig.add(SupportedPlatform.macos);
    }
    if (webPlatform) {
      platformsForMigrateConfig.add(SupportedPlatform.web);
    }
    if (windowsPlatform) {
      platformsForMigrateConfig.add(SupportedPlatform.windows);
    }
    if (templateContext['fuchsia'] == true) {
      platformsForMigrateConfig.add(SupportedPlatform.fuchsia);
    }
    globals.logger.printStatus('GenerateMeta: $generateMetadata');
    if (generateMetadata) {
      final File metadataFile = globals.fs
          .file(globals.fs.path.join(projectDir.absolute.path, '.metadata'));
      final ForgeProjectMetadata metadata = ForgeProjectMetadata.explicit(
        file: metadataFile,
        versionRevision: globals.flutterVersion.frameworkRevision,
        versionChannel: globals.flutterVersion.getBranchName(),
        // may contain PII
        projectType: projectType,
        migrateConfig: MigrateConfig(),
        logger: globals.logger,
      );
      metadata.populate(
        platforms: platformsForMigrateConfig,
        projectDirectory: directory,
        update: false,
        currentRevision: globals.flutterVersion.frameworkRevision,
        createRevision: globals.flutterVersion.frameworkRevision,
        logger: globals.logger,
      );
      metadata.writeFile();
    }

    return generatedCount;
  }

  int _injectGradleWrapper(FlutterProject project) {
    int filesCreated = 0;
    copyDirectory(
      globals.cache.getArtifactDirectory('gradle_wrapper'),
      project.android.hostAppGradleRoot,
      onFileCopied: (File sourceFile, File destinationFile) {
        filesCreated++;
        final String modes = sourceFile.statSync().modeString();
        if (modes.contains('x')) {
          globals.os.makeExecutable(destinationFile);
        }
      },
    );
    return filesCreated;
  }

  String askQuestion(String question, {String? defaultValue}) {
    const String dimColor = '\x1B[2m';
    const String resetColor = '\x1B[0m';
    io.stdout.write(
        '$question ${defaultValue != null ? '($dimColor$defaultValue$resetColor) ' : ''}');
    final String? input = io.stdin.readLineSync();
    return input != null && input.isNotEmpty ? input : (defaultValue ?? '');
  }

  bool askYesNoQuestion(String question) {
    while (true) {
      io.stdout.write(question);
      final String? input = io.stdin.readLineSync()?.toLowerCase();
      if (input == 'y' || input == 'yes') {
        return true;
      } else if (input == 'n' || input == 'no') {
        return false;
      } else {
        logger.printStatus('Invalid input, please enter "y" or "n".');
      }
    }
  }
}

// A valid Dart identifier that can be used for a package, i.e. no
// capital letters.
// https://dart.dev/language#important-concepts
final RegExp _identifierRegExp = RegExp('[a-z_][a-z0-9_]*');

// non-contextual dart keywords.
// https://dart.dev/language/keywords
const Set<String> _keywords = <String>{
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'inout',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'native',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'out',
  'part',
  'patch',
  'required',
  'rethrow',
  'return',
  'set',
  'show',
  'source',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

const Set<String> _packageDependencies = <String>{
  'collection',
  'flutter',
  'flutter_test',
  'meta',
};

/// Whether [name] is a valid Pub package.
@visibleForTesting
bool isValidPackageName(String name) {
  final Match? match = _identifierRegExp.matchAsPrefix(name);
  return match != null && match.end == name.length && !_keywords.contains(name);
}

/// Returns a potential valid name from the given [name].
///
/// If a valid name cannot be found, returns `null`.
@visibleForTesting
String? potentialValidPackageName(String name) {
  String newName = name.toLowerCase();
  if (newName.startsWith(RegExp(r'[0-9]'))) {
    newName = '_$newName';
  }
  newName = newName.replaceAll('-', '_');
  if (isValidPackageName(newName)) {
    return newName;
  } else {
    return null;
  }
}

// Return null if the project name is legal. Return a validation message if
// we should disallow the project name.
String? validateProjectName(String projectName) {
  if (!isValidPackageName(projectName)) {
    final String? potentialValidName = potentialValidPackageName(projectName);

    return <String>[
      '"$projectName" is not a valid Dart package name.',
      '\n\n',
      'The name should be all lowercase, with underscores to separate words, "just_like_this".',
      'Use only basic Latin letters and Arabic digits: [a-z0-9_].',
      "Also, make sure the name is a valid Dart identifier—that it doesn't start with digits and isn't a reserved word.\n",
      'See https://dart.dev/tools/pub/pubspec#name for more information.',
      if (potentialValidName != null) '\nTry "$potentialValidName" instead.',
    ].join();
  }
  if (_packageDependencies.contains(projectName)) {
    return "Invalid project name: '$projectName' - this will conflict with Flutter "
        'package dependencies.';
  }
  return null;
}
