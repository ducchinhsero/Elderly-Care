import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

class UserProfileRepository {
  Isar? _isar;
  final List<UserProfile> _webMemoryDb = [];

  Future<void> init() async {
    if (kIsWeb) {
      // Isar v3 does not support web. Use in-memory for testing on Chrome.
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [UserProfileSchema],
      directory: dir.path,
    );
  }

  Future<UserProfile?> getProfile(String uid) async {
    if (kIsWeb) {
      try {
        return _webMemoryDb.firstWhere((p) => p.uid == uid);
      } catch (_) {
        return null;
      }
    }
    return await _isar!.userProfiles.where().uidEqualTo(uid).findFirst();
  }

  Future<void> saveProfile(UserProfile profile) async {
    if (kIsWeb) {
      _webMemoryDb.removeWhere((p) => p.uid == profile.uid);
      _webMemoryDb.add(profile);
      return;
    }
    await _isar!.writeTxn(() async {
      await _isar!.userProfiles.put(profile);
    });
  }

  Future<void> deleteProfile(String uid) async {
    if (kIsWeb) {
      _webMemoryDb.removeWhere((p) => p.uid == uid);
      return;
    }
    await _isar!.writeTxn(() async {
      await _isar!.userProfiles.where().uidEqualTo(uid).deleteAll();
    });
  }
}
