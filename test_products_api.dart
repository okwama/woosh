import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Testing Products API...');

  try {
    // Test the products endpoint
    final response = await http.get(
      Uri.parse('http://localhost:3000/api/products'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwaG9uZU51bWJlciI6IjA3MjE5MDExMDAiLCJzdWIiOjIsInJvbGUiOiJTQUxFU19SRVAiLCJjb3VudHJ5SWQiOjEsInJlZ2lvbklkIjoxLCJyb3V0ZUlkIjoxLCJpYXQiOjE3NTQxMzI2MzUsImV4cCI6MTc1NDE2NTAzNX0.yArQKYu9n2QR63tHXRgwxtEXR62NjDlpG2IN5sPpPLY',
      },
    );

    print('📦 Response Status: ${response.statusCode}');
    print('📦 Response Headers: ${response.headers}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('📦 Response Type: ${data.runtimeType}');

      if (data is List) {
        print('📦 Array Response with ${data.length} items');
        if (data.isNotEmpty) {
          print('📦 First Product: ${data[0]}');

          // Test parsing the first product
          final firstProduct = data[0];
          print(
              '📦 Product ID: ${firstProduct['id']} (${firstProduct['id'].runtimeType})');
          print(
              '📦 Product Name: ${firstProduct['productName']} (${firstProduct['productName'].runtimeType})');
          print(
              '📦 Cost Price: ${firstProduct['costPrice']} (${firstProduct['costPrice'].runtimeType})');
          print(
              '📦 Selling Price: ${firstProduct['sellingPrice']} (${firstProduct['sellingPrice'].runtimeType})');
          print(
              '📦 Current Stock: ${firstProduct['currentStock']} (${firstProduct['currentStock'].runtimeType})');
          print(
              '📦 Is Active: ${firstProduct['isActive']} (${firstProduct['isActive'].runtimeType})');
        }
      } else {
        print('📦 Unexpected response format: $data');
      }
    } else {
      print('❌ Error: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
