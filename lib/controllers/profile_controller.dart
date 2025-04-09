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

  @override
  void onInit() {
    super.onInit();
    loadUserData();
    fetchProfile();
  }

  void loadUserData() {
    final userData = storage.read('user');
    if (userData != null) {
      userName.value = userData['name'] ?? '';
      userEmail.value = userData['email'] ?? '';
      userPhone.value = userData['phoneNumber'] ?? '';
      photoUrl.value = userData['photoUrl'] ?? '';
    }
  }

  Future<void> fetchProfile() async {
    try {
      final response = await ApiService.getProfile();
      final userData = response['user'];
      
      if (userData != null) {
        userName.value = userData['name'] ?? '';
        userEmail.value = userData['email'] ?? '';
        userPhone.value = userData['phoneNumber'] ?? '';
        photoUrl.value = userData['photoUrl'] ?? '';

        // Update storage with full user data
        storage.write('user', userData);
        
        print('Profile data loaded: ${userData.toString()}'); // Debug log
      } else {
        throw Exception('Invalid user data received');
      }
    } catch (e) {
      print('Error fetching profile: $e'); // Debug log
      Get.snackbar(
        'Error',
        'Failed to fetch profile data: ${e.toString().replaceAll('Exception: ', '')}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.error.withOpacity(0.1),
        colorText: Get.theme.colorScheme.error,
      );
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
      final photoUrl = await ApiService.updateProfilePhoto(selectedImage.value!);
      this.photoUrl.value = photoUrl;
      
      // Update storage
      final storedUser = storage.read('user') as Map<String, dynamic>? ?? {};
      storedUser['photoUrl'] = photoUrl;
      storage.write('user', storedUser);
      
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
}
