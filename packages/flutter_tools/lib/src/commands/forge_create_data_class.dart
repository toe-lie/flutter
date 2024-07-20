import 'dart:io' as io;

import 'package:meta/meta.dart';

import '../android/gradle_utils.dart' as gradle;
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/template.dart';
import '../base/utils.dart';
import '../cache.dart';
import '../flutter_project_metadata.dart';
import '../forge_project_metadata.dart';
import '../globals.dart' as globals;
import '../globals.dart';
import '../ios/code_signing.dart';
import '../runner/flutter_command.dart';
import 'forge_create.dart';

class ForgeCreateDataClassCommand extends ForgeCreateSubCommand {
  ForgeCreateDataClassCommand({
    required super.logger,
    required super.verboseHelp,
    required super.fileSystem,
    TemplateRenderer? templateRenderer,
  })  : _templateRenderer = templateRenderer ?? globals.templateRenderer;

  final TemplateRenderer _templateRenderer;
  final String dartSdk = globals.cache.dartSdkBuild;

  @override
  String get description => 'Create a data class file.';

  @override
  String get name => 'data-class';

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

    if (rest.length < 3) {
      throwToolExit(
        'Not enough arguments specified to generate a data class.'
        '\nflutter-me forge-create data-class . User id:int name:String',
        exitCode: 2,
      );
    }
  }

  /// Gets the flutter root directory.
  @protected
  String get flutterRoot => Cache.flutterRoot!;

  final List<String> primitiveTypes = <String>[
    'int', 'double', 'String', 'bool',
    'List', 'Set', 'Map', 'DateTime', 'dynamic'
  ];

  bool isPrimitive(String type) {
    if (primitiveTypes.contains(type)) {
      return true;
    }

    // Handle generic types like List<int>
    final RegExpMatch? listMatch = RegExp(r'List<(.+)>').firstMatch(type);
    if (listMatch != null) {
      return isPrimitive(listMatch.group(1)!);
    }

    final RegExpMatch? setMatch = RegExp(r'Set<(.+)>').firstMatch(type);
    if (setMatch != null) {
      return isPrimitive(setMatch.group(1)!);
    }

    final RegExpMatch? mapMatch = RegExp(r'Map<(.+), (.+)>').firstMatch(type);
    if (mapMatch != null) {
      return isPrimitive(mapMatch.group(1)!) && isPrimitive(mapMatch.group(2)!);
    }

    return false;
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    logger.printStatus('Creating a data class...');

    validateArgs();

    final List<String> rest = argResults?.rest ?? const <String>[];
    final String className = rest[1];
    final List<Map<String, String>> fields = rest.skip(2).map((String arg) {
      final List<String> parts = arg.split(':');
      return <String, String>{'name': parts[0], 'type': parts[1]};
    }).toList();

    final String flutterToolsAbsolutePath = globals.fs.path.join(
      Cache.flutterRoot!,
      'packages',
      'flutter_tools',
    );

    final String absoluteSourcePath=
      globals.fs.path.join(flutterToolsAbsolutePath, 'templates',
          'forge_templates', 'data_class.dart.tmpl');
    logger.printStatus('absoluteSourcePath: $absoluteSourcePath');

    final File sourceFile = fileSystem.file(absoluteSourcePath);
    final String templateContents = sourceFile.readAsStringSync();

    final bool hasNonPrimitive = fields.any((Map<String, String> field) => !isPrimitive(field['type']!));

    final String renderedContents =
        _templateRenderer.renderString(templateContents, <String, Object>{
          'className': className,
          'fields': fields,
          'hasNonPrimitive': hasNonPrimitive,
        });

    final String fileName = '${snakeCase(className)}.dart';
    final String finalDestinationPath = globals.fs.path.join(
        projectDirPath,
      fileName,
    );
    final File finalDestinationFile = fileSystem.file(finalDestinationPath);
    if (finalDestinationFile.existsSync()) {
      throwToolExit(
        'File $finalDestinationPath already exists.',
        exitCode: 2,
      );
    } else {
      finalDestinationFile.createSync(recursive: true);
    }
    finalDestinationFile.writeAsStringSync(renderedContents);
    logger.printStatus('Wrote $finalDestinationPath.');
    return FlutterCommandResult.success();
  }
}
