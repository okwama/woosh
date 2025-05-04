import 'package:get_storage/get_storage.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:woosh/pages/managers/checkin_page.dart';
import 'package:woosh/services/api_service.dart';
import 'dart:convert';


class OutletLocationService {
  static final _storage = GetStorage();
  static const _outletsCacheKey = 'cached_outlets';
  static const _cacheDuration = Duration(hours: 1); // Cache for 1 hour

  // Get outlets with caching
  static Future<List<dynamic>> getOutletsWithCache() async {
    // Check if cache is valid
    final lastFetchTime = _storage.read('last_outlet_fetch_time');
    final cachedOutlets = _storage.read(_outletsCacheKey);
    
    if (lastFetchTime != null && 
        cachedOutlets != null &&
        DateTime.now().difference(DateTime.parse(lastFetchTime)) < _cacheDuration) {
      return cachedOutlets;
    }

    // Fetch fresh data
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/outlets'),
        headers: {'Authorization': 'Bearer ${_storage.read('token')}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final outlets = json.decode(response.body);
        // Update cache
        await _storage.write(_outletsCacheKey, outlets);
        await _storage.write('last_outlet_fetch_time', DateTime.now().toIso8601String());
        return outlets;
      }
      throw Exception('Failed to fetch outlets');
    } catch (e) {
      // Return cached data even if stale when network fails
      if (cachedOutlets != null) return cachedOutlets;
      rethrow;
    }
  }

  // Track user location and find nearest outlet
  static Stream<Map<String, dynamic>?> trackNearestOutlet() {
    final controller = StreamController<Map<String, dynamic>?>();
    StreamSubscription<Position>? positionSub;
    List<dynamic> outlets = [];

    // Initialize
    () async {
      try {
        outlets = await getOutletsWithCache();
        if (outlets.isEmpty) {
          controller.add(null);
          return;
        }

        // Start location updates
        positionSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 50, // Update every 50 meters
          ),
        ).listen((position) {
          final nearest = _findNearestOutlet(position, outlets);
          controller.add(nearest);
        });
      } catch (e) {
        controller.addError(e);
      }
    }();

    controller.onCancel = () {
      positionSub?.cancel();
    };

    return controller.stream;
  }

  static Map<String, dynamic>? _findNearestOutlet(Position position, List<dynamic> outlets) {
    Map<String, dynamic>? nearest;
    double? minDistance;

    for (final outlet in outlets) {
      if (outlet['latitude'] == null || outlet['longitude'] == null) continue;

      final distance = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        outlet['latitude'],
        outlet['longitude'],
      );

      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        nearest = outlet;
      }
    }

    return nearest?..['distance'] = minDistance;
  }
}