import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'room_model.dart';

class RoomException implements Exception {
  const RoomException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CreatedRoom {
  const CreatedRoom({required this.roomId, required this.password});

  final String roomId;
  final String password;
}

class RoomService {
  RoomService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    Random? random,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _random = random ?? Random.secure();

  static const int maxPlayers = 7;
  static const _roomIdChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final Random _random;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<RoomModel?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return RoomModel.fromSnapshot(snapshot);
    });
  }

  Stream<List<RoomPlayer>> watchPlayers(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('players')
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(RoomPlayer.fromSnapshot).toList());
  }

  Future<CreatedRoom> createRoom({
    required String username,
    required int selectedRounds,
  }) async {
    final user = _requireUser();
    final publicUsername = await _publicUsernameFor(user.uid, username);
    final roomId = await _generateUniqueRoomId();
    final password = _generatePassword();
    final now = FieldValue.serverTimestamp();
    final roomRef = _rooms.doc(roomId);

    final batch = _firestore.batch();
    batch.set(roomRef, {
      'roomId': roomId,
      'password': password,
      'hostUid': user.uid,
      'hostUsername': publicUsername,
      'status': 'waiting',
      'maxPlayers': maxPlayers,
      'selectedRounds': selectedRounds,
      'activePlayerCount': 1,
      'removedPlayerCount': 0,
      'afkCheckRequired': false,
      'currentRoundStatus': 'active',
      'lastAfkActionMessage': null,
      'gameEndedReason': null,
      'endGameVoteActive': false,
      'endGameRequestedByUid': null,
      'endGameRequestedByUsername': null,
      'endGameVoteStartedAt': null,
      'endGameVoteStatus': null,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(roomRef.collection('players').doc(user.uid), {
      'uid': user.uid,
      'username': publicUsername,
      'isHost': true,
      'isOnline': true,
      'isReconnecting': false,
      'disconnectedAt': null,
      'reconnectDeadlineAt': null,
      'lastSeenAt': now,
      'lastReconnectAt': now,
      'lastDisconnectMessageAt': null,
      'lastReconnectMessageAt': null,
      'lastAfkMessageAt': null,
      'isRemoved': false,
      'removedAt': null,
      'removalReason': null,
      'joinedAt': now,
      'score': 0,
      'roundScoreSnapshot': null,
    });
    batch.set(_users.doc(user.uid), {
      'activeRoomId': roomId,
      'activeRoomStatus': 'lobby',
      'lastSeenAt': now,
      'lastReconnectAt': now,
      'lastRoomExitReason': null,
      'lastRoomExitRoomId': null,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
    return CreatedRoom(roomId: roomId, password: password);
  }

  Future<void> joinRoom({
    required String roomId,
    required String password,
    required String username,
  }) async {
    final user = _requireUser();
    final publicUsername = await _publicUsernameFor(user.uid, username);
    final normalizedRoomId = roomId.trim().toUpperCase();
    final normalizedPassword = password.trim();
    final roomRef = _rooms.doc(normalizedRoomId);

    final roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists) {
      throw const RoomException('Room not found');
    }

    final room = RoomModel.fromSnapshot(roomSnapshot);
    if (room.password != normalizedPassword) {
      throw const RoomException('Wrong password');
    }
    if (room.status != 'waiting') {
      throw const RoomException('Room already started');
    }

    final playerRef = roomRef.collection('players').doc(user.uid);
    final playerSnapshot = await playerRef.get();
    if (!playerSnapshot.exists) {
      final playersSnapshot = await roomRef.collection('players').get();
      if (playersSnapshot.docs.length >= room.maxPlayers) {
        throw const RoomException('Room full');
      }
    }

    await playerRef.set({
      'uid': user.uid,
      'username': publicUsername,
      'isHost': user.uid == room.hostUid,
      'isOnline': true,
      'isReconnecting': false,
      'disconnectedAt': null,
      'reconnectDeadlineAt': null,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'lastReconnectAt': FieldValue.serverTimestamp(),
      'lastDisconnectMessageAt': null,
      'lastReconnectMessageAt': null,
      'lastAfkMessageAt': null,
      'isRemoved': false,
      'removedAt': null,
      'removalReason': null,
      'joinedAt': FieldValue.serverTimestamp(),
      'score': 0,
      'roundScoreSnapshot': null,
    }, SetOptions(merge: true));

    final activePlayersSnapshot = await roomRef
        .collection('players')
        .where('isRemoved', isEqualTo: false)
        .get();
    await roomRef.update({
      'activePlayerCount': activePlayersSnapshot.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _users.doc(user.uid).set({
      'activeRoomId': normalizedRoomId,
      'activeRoomStatus': 'lobby',
      'lastSeenAt': FieldValue.serverTimestamp(),
      'lastReconnectAt': FieldValue.serverTimestamp(),
      'lastRoomExitReason': null,
      'lastRoomExitRoomId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> startGame(String roomId) {
    return _rooms.doc(roomId).update({
      'status': 'started',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  User _requireUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const RoomException('Please login again');
    }
    return user;
  }

  Future<String> _generateUniqueRoomId() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final roomId = _generateRoomId();
      final snapshot = await _rooms.doc(roomId).get();
      if (!snapshot.exists) return roomId;
    }

    throw const RoomException('Could not create a room. Try again');
  }

  String _generateRoomId() {
    return List.generate(
      6,
      (_) => _roomIdChars[_random.nextInt(_roomIdChars.length)],
    ).join();
  }

  String _generatePassword() {
    return List.generate(4, (_) => _random.nextInt(10).toString()).join();
  }

  Future<String> _publicUsernameFor(String uid, String fallback) async {
    final profile = await _users.doc(uid).get();
    final username = profile.data()?['username'] as String?;
    if (_isPublicUsername(username)) return username!;
    if (_isPublicUsername(fallback)) return fallback;
    return 'Player';
  }

  bool _isPublicUsername(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return !value.contains('@');
  }
}
