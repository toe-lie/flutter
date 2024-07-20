import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Please provide a directory path as an argument.');
    return;
  }

  final directoryPath = arguments[0];
  final directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    print('The provided directory does not exist.');
    return;
  }

  print('Processing directory: ${directory.path}');

  final entities = await collectEntities(directory);

  // Sort entities by path length in descending order to handle deeper directories first
  entities.sort((a, b) => b.path.length.compareTo(a.path.length));

  await renameEntities(entities);

  print('All files and directories have been processed.');
}


Future<List<FileSystemEntity>> collectEntities(Directory directory) async {
  final List<FileSystemEntity> entities = [];
  await for (FileSystemEntity entity in directory.list(recursive: true, followLinks: false)) {
    final oldPath = entity.path;
    final fileName = oldPath.split(Platform.pathSeparator).last;

    if (fileName == 'rename.dart' || fileName.endsWith('.tmpl')) {
      // Skip 'rename.dart' and files or directories that already end with '.tmpl'
      continue;
    }

    entities.add(entity);
  }
  return entities;
}

Future<void> renameEntities(List<FileSystemEntity> entities) async {
  for (FileSystemEntity entity in entities) {
    final oldPath = entity.path;
    final fileName = oldPath.split(Platform.pathSeparator).last;

    // Check if the file is a media file (png, jpg, etc.)
    final isMediaFile = fileName.endsWith('.png') || fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.gif') || fileName.endsWith('.bmp') || fileName.endsWith('.mp4') || fileName.endsWith('.mov');

    final newPath = isMediaFile ? oldPath + '.copy.tmpl' : oldPath + '.tmpl';
    
    if (entity is File || entity is Directory) {
      await entity.rename(newPath);
      print('Renamed: $oldPath -> $newPath');
    }
  }
}