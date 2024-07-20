import 'package:meta/meta.dart';

import '../android/android_sdk.dart';
import '../artifacts.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/os.dart';
import '../base/process.dart';
import '../build_info.dart';
import '../build_system/build_system.dart';
import '../cache.dart';
import '../commands/build_linux.dart';
import '../commands/build_macos.dart';
import '../commands/build_windows.dart';
import '../runner/flutter_command.dart';
import 'build_aar.dart';
import 'build_apk.dart';
import 'build_appbundle.dart';
import 'build_bundle.dart';
import 'build_ios.dart';
import 'build_ios_framework.dart';
import 'build_macos_framework.dart';
import 'build_preview.dart';
import 'build_web.dart';
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
}
