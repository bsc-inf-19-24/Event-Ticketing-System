import 'package:flutter/foundation.dart';
import '../data/profile_repository.dart';
import '../models/user_model.dart';

class ProfileController extends ChangeNotifier {
  final ProfileRepository _repository = ProfileRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  UserModel? _user;
  UserModel? get user => _user;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Fetch profile data when the screen loads
  Future<void> loadProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.fetchUserProfile();
      _user = UserModel.fromJson(data);
    } catch (e) {
      _errorMessage = 'Failed to load profile data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Handle Log Out action
  Future<bool> handleLogout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _repository.logout();

      _isLoading = false;
      notifyListeners();
      return true; // Return true to indicate successful logout navigation
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Logout failed. Please try again.';
      notifyListeners();
      return false;
    }
  }
}