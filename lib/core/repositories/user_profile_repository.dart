import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  static const String _boxName = 'user_profiles';
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<UserProfile?> getProfile(String uid) async {
    final value = _box.get(uid);
    if (value is Map) {
      return UserProfile.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _box.put(profile.uid, profile.toJson());
  }

  Future<void> deleteProfile(String uid) async {
    await _box.delete(uid);
  }
}
