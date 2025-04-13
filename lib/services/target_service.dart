import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:woosh/models/target_model.dart';
import 'package:woosh/models/order_model.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/utils/config.dart';

class TargetService {
  static const String baseUrl = '${Config.baseUrl}/api';

  // Get auth token for API requests
  static String? _getAuthToken() {
    final box = GetStorage();
    return box.read<String>('token');
  }

  // Get headers for API requests
  static Future<Map<String, String>> _headers() async {
    final token = _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get all targets for the current user
  static Future<List<Target>> getTargets() async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/targets'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => Target.fromJson(json)).toList();
        }
        // If the server returns 404, it means the endpoint doesn't exist yet
        else if (response.statusCode == 404) {
          print('Targets API endpoint not found, returning mock data');
          return _getMockTargets();
        } else {
          throw Exception('Failed to load targets: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // If timeout or connection error, return mock data
        print(
            'Connection error or timeout, returning mock data: $timeoutError');
        return _getMockTargets();
      }
    } catch (e) {
      print('Error fetching targets: $e');
      // Return mock data for development until backend is ready
      return _getMockTargets();
    }
  }

  // Create a new target
  static Future<Target> createTarget(Target target) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/targets'),
              headers: await _headers(),
              body: jsonEncode(target.toJson()),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          return Target.fromJson(data);
        } else {
          throw Exception('Failed to create target: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // Return mock response for development
        print(
            'Connection error or timeout, returning mock response: $timeoutError');
        return target.copyWith(id: DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      print('Error creating target: $e');
      // Return mock response for development
      return target.copyWith(id: DateTime.now().millisecondsSinceEpoch);
    }
  }

  // Update an existing target
  static Future<Target> updateTarget(Target target) async {
    try {
      if (target.id == null) {
        throw Exception('Target ID is required for update');
      }

      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .put(
              Uri.parse('$baseUrl/targets/${target.id}'),
              headers: await _headers(),
              body: jsonEncode(target.toJson()),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return Target.fromJson(data);
        } else {
          throw Exception('Failed to update target: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // Return mock response for development
        print(
            'Connection error or timeout, returning mock response: $timeoutError');
        return target;
      }
    } catch (e) {
      print('Error updating target: $e');
      // For development, return the target instead of throwing
      return target;
    }
  }

  // Delete a target
  static Future<bool> deleteTarget(int targetId) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .delete(
              Uri.parse('$baseUrl/targets/$targetId'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return true;
        } else {
          throw Exception('Failed to delete target: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // Return mock success for development
        print(
            'Connection error or timeout, returning mock success: $timeoutError');
        return true;
      }
    } catch (e) {
      print('Error deleting target: $e');
      // For development, return success instead of throwing
      return true;
    }
  }

  // Update target progress
  static Future<Target> updateTargetProgress(int targetId, int newValue) async {
    try {
      final token = _getAuthToken();
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      try {
        final response = await http
            .patch(
              Uri.parse('$baseUrl/targets/$targetId/progress'),
              headers: await _headers(),
              body: jsonEncode({'currentValue': newValue}),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return Target.fromJson(data);
        } else {
          throw Exception(
              'Failed to update target progress: ${response.statusCode}');
        }
      } catch (timeoutError) {
        // Mock updating a target's progress
        print(
            'Connection error or timeout, returning mock data: $timeoutError');
        // For development, create a mock updated target
        final mockTargets = _getMockTargets();
        final targetIndex = mockTargets.indexWhere((t) => t.id == targetId);
        if (targetIndex != -1) {
          final updatedTarget =
              mockTargets[targetIndex].copyWith(currentValue: newValue);
          return updatedTarget;
        } else {
          // If target not found in mock data, create a new one with the updated progress
          return Target(
            id: targetId,
            title: 'Mock Target',
            description: 'Mock target created for development',
            type: TargetType.SALES,
            userId: int.tryParse(GetStorage().read('userId') ?? '1') ?? 1,
            targetValue: newValue * 2, // Just a simple mock value
            currentValue: newValue,
            startDate: DateTime.now().subtract(const Duration(days: 10)),
            endDate: DateTime.now().add(const Duration(days: 20)),
            isCompleted: false,
          );
        }
      }
    } catch (e) {
      print('Error updating target progress: $e');
      // For development, create a mock updated target
      return Target(
        id: targetId,
        title: 'Mock Target',
        description: 'Mock target created from error handling',
        type: TargetType.SALES,
        userId: int.tryParse(GetStorage().read('userId') ?? '1') ?? 1,
        targetValue: newValue * 2, // Just a simple mock value
        currentValue: newValue,
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        isCompleted: false,
      );
    }
  }

  // Get user's sales data from the last two weeks
  static Future<Map<String, dynamic>> getSalesData() async {
    try {
      // Get current user ID
      final box = GetStorage();
      final userId = box.read('userId');
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Calculate two weeks ago date
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));

      // Get all orders for the user
      final response = await ApiService.getOrders(limit: 100);
      final orders = response.data;

      // Calculate total items sold and total orders in the last two weeks
      int totalItemsSold = 0;
      final recentOrders = <Order>[];

      for (var order in orders) {
        if (order.createdAt.isAfter(twoWeeksAgo)) {
          recentOrders.add(order);
          for (var item in order.orderItems) {
            totalItemsSold += item.quantity;
          }
        }
      }

      return {
        'totalItemsSold': totalItemsSold,
        'orderCount': recentOrders.length,
        'recentOrders': recentOrders,
      };
    } catch (e) {
      print('Error getting sales data: $e');
      return {
        'totalItemsSold': 0,
        'orderCount': 0,
        'recentOrders': <Order>[],
      };
    }
  }

  // Mock data for targets - for development until backend is ready
  static List<Target> _getMockTargets() {
    final now = DateTime.now();
    final userId = int.tryParse(GetStorage().read('userId') ?? '1') ?? 1;

    return [
      Target(
        id: 1,
        title: 'Monthly Products Sold',
        description: 'Achieve monthly sales quota for Q2',
        type: TargetType.SALES,
        userId: userId,
        targetValue: 50,
        currentValue: 32,
        startDate: now.subtract(const Duration(days: 15)),
        endDate: now.add(const Duration(days: 15)),
        isCompleted: false,
      ),
      Target(
        id: 2,
        title: 'Weekly Products Sold',
        description: 'This week\'s product sales target',
        type: TargetType.SALES,
        userId: userId,
        targetValue: 20,
        currentValue: 8,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 7)),
        isCompleted: false,
      ),
      Target(
        id: 3,
        title: 'Last Month Products Sold',
        description: 'Previous month sales results',
        type: TargetType.SALES,
        userId: userId,
        targetValue: 100,
        currentValue: 100,
        startDate: now.subtract(const Duration(days: 45)),
        endDate: now.subtract(const Duration(days: 15)),
        isCompleted: true,
      ),
    ];
  }
}
