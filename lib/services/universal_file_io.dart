// IO implementation for file handling (mobile, desktop)

import 'dart:io';
import 'package:http/http.dart' as http;

/// Abstract interface for file operations
abstract class FileDelegate {
  Future<http.MultipartFile> toMultipartFile(String fieldName);
  String get name;
}

/// IO-specific implementation for file operations
class IOFileDelegate implements FileDelegate {
  final File _file;

  IOFileDelegate(this._file);

  @override
  Future<http.MultipartFile> toMultipartFile(String fieldName) async {
    return await http.MultipartFile.fromPath(
      fieldName,
      _file.path,
      filename: _file.path.split('/').last,
    );
  }

  @override
  String get name => _file.path.split('/').last;
}

/// Create platform-specific file delegate
FileDelegate createFileDelegate(dynamic file) {
  if (file is File) {
    return IOFileDelegate(file);
  }
  throw ArgumentError('Unsupported file type: ${file.runtimeType}');
}
