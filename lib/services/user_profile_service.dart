import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UsernameTakenException implements Exception {}

class InvalidUsernameException implements Exception {}

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final _usernameRegex = RegExp(r'^[a-z_]{1,15}$');

  final FirebaseFirestore _firestore;

  Future<DocumentSnapshot<Map<String, dynamic>>> profileFor(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> reloadProfileFor(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
  }

  Future<String?> usernameFor(String uid) async {
    final profile = await profileFor(uid);
    return profile.data()?['username'] as String?;
  }

  Future<String> createProfileWithUsername({
    required User user,
    required String username,
  }) async {
    final cleanUsername = username.trim();
    if (!_usernameRegex.hasMatch(cleanUsername)) {
      throw InvalidUsernameException();
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final usernameRef = _firestore.collection('usernames').doc(cleanUsername);

    debugPrint('username transaction started');
    final savedUsername = await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final existingUserUsername = userSnapshot.data()?['username'] as String?;

      if (existingUserUsername != null && existingUserUsername.isNotEmpty) {
        return existingUserUsername;
      }

      final usernameSnapshot = await transaction.get(usernameRef);
      if (usernameSnapshot.exists) {
        final ownerUid = usernameSnapshot.data()?['uid'] as String?;
        if (ownerUid != user.uid) {
          throw UsernameTakenException();
        }
      }

      final createdAt = FieldValue.serverTimestamp();
      transaction.set(usernameRef, {
        'uid': user.uid,
        'createdAt': createdAt,
      }, SetOptions(merge: true));
      debugPrint('username document created');

      transaction.set(userRef, {
        'uid': user.uid,
        'email': user.email,
        'username': cleanUsername,
        'activeRoomId': null,
        'activeRoomStatus': null,
        'lastSeenAt': createdAt,
        'lastReconnectAt': null,
        'lastRoomExitReason': null,
        'createdAt': createdAt,
      }, SetOptions(merge: true));
      debugPrint('user profile created');

      return cleanUsername;
    });

    debugPrint('username setup complete');
    return savedUsername;
  }
}
