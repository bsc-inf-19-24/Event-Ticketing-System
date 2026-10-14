class ProfileRepository {
  // Simulates fetching user data from an API or local storage
  Future<Map<String, dynamic>> fetchUserProfile() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network lag
    // In a real app, this would be an http or dio call: e.g., await dio.get('/user/profile');
    return {
      'email': 'example@gmail.com',
      'avatarUrl': '',
    };
  }

  // Simulates logging out the user
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network request
    // TODO: Clear secure storage / token tokens here (e.g., FlutterSecureStorage or SharedPreferences)
  }
}