import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_storage/get_storage.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/user_model.dart';

class ProfileController extends GetxController {
  final storage = GetStorage();

  Rx<XFile?> selectedImage = Rx<XFile?>(null);
  RxBool isLoading = false.obs;
  RxString userName = ''.obs;
  RxString userEmail = ''.obs;
  RxString userPhone = ''.obs;
  RxString photoUrl = ''.obs;
  RxString userRole = ''.obs;
  RxString userRegion = ''.obs;
  RxString userDepartment = ''.obs;

  // Password update fields
  final RxBool isPasswordUpdating = false.obs;
  final RxString passwordError = ''.obs;
  final RxString passwordSuccess = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserData();
    fetchProfile();
  }

  void loadUserData() {
    final userData = storage.read('salesRep');
    if (userData != null) {
      userName.value = userData['name'] ?? '';
      userEmail.value = userData['email'] ?? '';
      userPhone.value = userData['phoneNumber'] ?? '';
      photoUrl.value = userData['photoUrl'] ?? '';
      userRole.value = userData['role'] ?? '';
      userRegion.value = userData['region'] ?? '';
      userDepartment.value = userData['department'] ?? '';
    }
  }

  Future<void> fetchProfile() async {
    try {
      print('🔄 Fetching profile data...');
      final response = await ApiService.getProfile();
      final userData = response['salesRep'];

      if (userData != null) {
        userName.value = userData['name'] ?? '';
        userEmail.value = userData['email'] ?? '';
        userPhone.value = userData['phoneNumber'] ?? '';
        photoUrl.value = userData['photoUrl'] ?? '';
        userRole.value = userData['role'] ?? '';
        userRegion.value = userData['region'] ?? '';
        userDepartment.value = userData['department'] ?? '';

        // Update storage with full user data
        storage.write('salesRep', userData);

        print('✅ Profile data loaded successfully: ${userData.toString()}');
      } else {
        print('❌ No user data in response - using cached data');
        // Don't throw exception, just use cached data
        loadUserData();
      }
    } catch (e) {
      print('❌ Error fetching profile: $e');

      // Only show snackbar for specific errors, not network issues
      if (e.toString().contains('Session expired') ||
          e.toString().contains('Authentication failed')) {
        Get.snackbar(
          'Authentication Error',
          'Please log in again',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.error.withOpacity(0.1),
          colorText: Get.theme.colorScheme.error,
        );
      }

      // Always fall back to cached data
      print('🔄 Falling back to cached profile data...');
      loadUserData();
    }
  }

  Future<void> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        selectedImage.value = image;
        await updateProfilePhoto();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> updateProfilePhoto() async {
    if (selectedImage.value == null) return;

    try {
      isLoading.value = true;

      // Pass XFile directly to handle both web and mobile platforms
      final photoUrl =
          await ApiService.updateProfilePhoto(selectedImage.value!);
      this.photoUrl.value = photoUrl;

      // Update storage
      final storedUser =
          storage.read('salesRep') as Map<String, dynamic>? ?? {};
      storedUser['photoUrl'] = photoUrl;
      storage.write('salesRep', storedUser);

      Get.snackbar(
        'Success',
        'Profile photo updated successfully',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error.withOpacity(0.1),
        colorText: Get.theme.colorScheme.error,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      // Reset status messages
      passwordError.value = '';
      passwordSuccess.value = '';
      isPasswordUpdating.value = true;

      print('PROFILE CONTROLLER: Starting password update process');

      // Validate passwords
      if (currentPassword.isEmpty ||
          newPassword.isEmpty ||
          confirmPassword.isEmpty) {
        passwordError.value = 'All fields are required';
        print('PROFILE CONTROLLER: Validation failed - Empty fields');
        return;
      }

      if (newPassword != confirmPassword) {
        passwordError.value = 'New passwords do not match';
        print('PROFILE CONTROLLER: Validation failed - Passwords do not match');
        return;
      }

      if (newPassword.length < 8) {
        passwordError.value = 'Password must be at least 8 characters long';
        print('PROFILE CONTROLLER: Validation failed - Password too short');
        return;
      }

      print('PROFILE CONTROLLER: Validation passed, calling API service');

      // Call API to update password
      final result = await ApiService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      print('PROFILE CONTROLLER: API response received: $result');

      if (result['success']) {
        passwordSuccess.value = result['message'];
        print('PROFILE CONTROLLER: Password update successful');
      } else {
        passwordError.value = result['message'];
        print(
            'PROFILE CONTROLLER: Password update failed: ${result['message']}');
      }
    } catch (e) {
      print('PROFILE CONTROLLER: Exception during password update: $e');
      passwordError.value = 'An error occurred: ${e.toString()}';
    } finally {
      isPasswordUpdating.value = false;
      print('PROFILE CONTROLLER: Password update process completed');
    }
  }
}
