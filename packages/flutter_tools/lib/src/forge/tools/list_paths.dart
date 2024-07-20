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

  if (directory.existsSync()) {
    listFilesAndFolders(directory);
  }
}

void listFilesAndFolders(Directory dir) {
  try {
    // List all entities (files and folders) in the directory
    List<FileSystemEntity> entities = dir.listSync(recursive: true, followLinks: false);
    
    for (FileSystemEntity entity in entities) {
      // Print the full path of each entity
      print(entity.path);
    }
  } catch (e) {
    print("Error: $e");
  }
}