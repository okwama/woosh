// Web implementation for file handling

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Abstract interface for file operations
abstract class FileDelegate {
  Future<http.MultipartFile> toMultipartFile(String fieldName);
  String get name;
}

/// Web-specific implementation for file operations
class WebFileDelegate implements FileDelegate {
  final html.File _file;

  WebFileDelegate(this._file);

  @override
  Future<http.MultipartFile> toMultipartFile(String fieldName) async {
    final reader = html.FileReader();
    final completer = Completer<List<int>>();

    reader.onLoad.listen((event) {
      final List<int> bytes = (reader.result as html.Blob).size > 0
          ? reader.result as List<int>
          : Uint8List(0).toList();
      completer.complete(bytes);
    });

    reader.readAsArrayBuffer(_file);
    final bytes = await completer.future;

    return http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: _file.name,
    );
  }

  @override
  String get name => _file.name;
}

/// Create platform-specific file delegate
FileDelegate createFileDelegate(dynamic file) {
  if (file is html.File) {
    return WebFileDelegate(file);
  }
  throw ArgumentError('Unsupported file type: ${file.runtimeType}');
}
