import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

/// Add a file to a multipart request on web platforms using dart:html.
///
/// @param request The HTTP request to add the file to
/// @param file The html.File object from dart:html or XFile from image_picker
/// @param fieldName The form field name to use
Future<void> addFileToMultipartRequest(
    http.MultipartRequest request, dynamic file, String fieldName) async {
  try {
    // Handle XFile (from image_picker) case
    if (file is XFile) {
      // Read the bytes from XFile
      final bytes = await file.readAsBytes();
      final fileName = file.name;

      // Determine MIME type from file name or default to jpeg
      String mimeType = 'image/jpeg';
      String subType = 'jpeg';

      if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
        subType = 'png';
      } else if (fileName.toLowerCase().endsWith('.gif')) {
        mimeType = 'image/gif';
        subType = 'gif';
      } else if (fileName.toLowerCase().endsWith('.pdf')) {
        mimeType = 'application/pdf';
        subType = 'pdf';
      }

      // Add the bytes to the request
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: fileName,
          contentType: MediaType(mimeType.split('/')[0], subType),
        ),
      );
      return;
    }

    // Handle html.File case
    else if (file is html.File) {
      // Extract the bytes from the HTML File object
      final reader = html.FileReader();
      final completer = Completer<List<int>>();

      reader.onLoad.listen((event) {
        final bytes = reader.result as Uint8List;
        completer.complete(bytes);
      });

      reader.readAsArrayBuffer(file);
      final bytes = await completer.future;

      // Determine MIME type from file name or default to jpeg
      String mimeType = 'image/jpeg';
      String subType = 'jpeg';

      if (file.name.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
        subType = 'png';
      } else if (file.name.toLowerCase().endsWith('.gif')) {
        mimeType = 'image/gif';
        subType = 'gif';
      } else if (file.name.toLowerCase().endsWith('.pdf')) {
        mimeType = 'application/pdf';
        subType = 'pdf';
      }

      // Add the bytes to the request
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: file.name,
          contentType: MediaType(mimeType.split('/')[0], subType),
        ),
      );
      return;
    }

    // Handle unexpected file type
    else {
      throw ArgumentError(
          'Invalid file type: ${file.runtimeType}. Expected html.File or XFile.');
    }
  } catch (e) {
    rethrow;
  }
}
