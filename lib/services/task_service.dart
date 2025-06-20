import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:woosh/models/task_model.dart';
import 'package:woosh/utils/config.dart';
import 'package:woosh/services/token_service.dart';

class TaskService {
  static const String baseUrl = '${Config.baseUrl}/api/tasks';

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = TokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Task>> getTasks() async {
    try {
      final box = GetStorage();
      final salesRep = box.read('salesRep');
      final salesRepId = salesRep?['id']?.toString();

      if (salesRepId == null) {
        throw Exception('User ID not found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/salesrep/$salesRepId'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load tasks: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading tasks: $e');
    }
  }

  Future<List<Task>> getTaskHistory() async {
    try {
      final box = GetStorage();
      final salesRep = box.read('salesRep');
      final salesRepId = salesRep?['id']?.toString();

      if (salesRepId == null) {
        throw Exception('User ID not found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/salesrep/$salesRepId/history'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load task history: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading task history: $e');
    }
  }

  Future<Task> createTask({
    required String title,
    required String description,
    required String priority,
    required int salesRepId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'title': title,
          'description': description,
          'priority': priority,
          'salesRepId': salesRepId,
        }),
      );

      if (response.statusCode == 201) {
        return Task.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<void> completeTask(int taskId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$taskId/complete'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to complete task: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error completing task: $e');
    }
  }

  Future<void> updateTaskStatus(int taskId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$taskId/status'),
        headers: await _getAuthHeaders(),
        body: json.encode({'status': status}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update task status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating task status: $e');
    }
  }

  Future<void> deleteTask(int taskId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete task: $e');
    }
  }
}
