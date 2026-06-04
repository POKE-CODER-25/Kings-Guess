import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/presence_config.dart';

enum ActiveRoomTarget { none, lobby, game, closed, afkRemoved }

class ActiveRoomResolution {
  const ActiveRoomResolution({required this.target, this.roomId, this.message});

  final ActiveRoomTarget target;
  final String? roomId;
  final String? message;
}

class RoomConsistencyService {
  RoomConsistencyService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const reconnectWindow = Duration(minutes: 2);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<ActiveRoomResolution> reconnectToActiveRoomIfAny() async {
    if (!enableReconnectRouting) {
      return const ActiveRoomResolution(target: ActiveRoomTarget.none);
    }

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return const ActiveRoomResolution(target: ActiveRoomTarget.none);
    }

    final userRef = _users.doc(user.uid);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data() ?? const <String, dynamic>{};
    final roomId = userData['activeRoomId'] as String?;
    final lastExitReason = userData['lastRoomExitReason'] as String?;

    if (roomId == null || roomId.isEmpty) {
      if (lastExitReason != null && lastExitReason.isNotEmpty) {
        await userRef.set({
          'lastRoomExitReason': null,
          'lastRoomExitRoomId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return ActiveRoomResolution(
        target: ActiveRoomTarget.none,
        message: _messageForExitReason(lastExitReason),
      );
    }

    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final room = roomSnapshot.data();
    if (room == null) {
      await clearActiveRoom(
        user.uid,
        exitReason: 'game_closed',
        roomId: roomId,
      );
      return const ActiveRoomResolution(
        target: ActiveRoomTarget.closed,
        message: 'Room has been closed.',
      );
    }

    final playerSnapshot = await roomRef
        .collection('players')
        .doc(user.uid)
        .get();
    final player = playerSnapshot.data();
    if (player == null) {
      await clearActiveRoom(
        user.uid,
        exitReason: 'game_closed',
        roomId: roomId,
      );
      return const ActiveRoomResolution(
        target: ActiveRoomTarget.closed,
        message: 'Room has been closed.',
      );
    }

    if (player['isRemoved'] as bool? ?? false) {
      final reason = player['removalReason'] as String?;
      await clearActiveRoom(user.uid, exitReason: reason, roomId: roomId);
      return ActiveRoomResolution(
        target: reason == 'afk'
            ? ActiveRoomTarget.afkRemoved
            : ActiveRoomTarget.closed,
        message: _messageForExitReason(reason),
      );
    }

    final status = room['status'] as String? ?? 'waiting';
    if (status == 'closed') {
      await clearActiveRoom(
        user.uid,
        exitReason: 'game_closed',
        roomId: roomId,
      );
      return const ActiveRoomResolution(
        target: ActiveRoomTarget.closed,
        message: 'Room has been closed.',
      );
    }

    if (status == 'game_complete') {
      await markUserOnline(roomId);
      return ActiveRoomResolution(
        target: ActiveRoomTarget.game,
        roomId: roomId,
      );
    }

    await markUserOnline(roomId);
    if (_isLobbyStatus(status)) {
      return ActiveRoomResolution(
        target: ActiveRoomTarget.lobby,
        roomId: roomId,
      );
    }

    return ActiveRoomResolution(target: ActiveRoomTarget.game, roomId: roomId);
  }

  Future<void> syncCurrentUserPresence(String roomId) => markUserOnline(roomId);

  Future<void> markUserOnline(String roomId) async {
    if (!enableLifecyclePresenceSystem) return;
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final roomRef = _rooms.doc(roomId);
    final playerRef = roomRef.collection('players').doc(user.uid);
    final userRef = _users.doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final playerSnapshot = await transaction.get(playerRef);
      final userSnapshot = await transaction.get(userRef);
      final room = roomSnapshot.data();
      final player = playerSnapshot.data();
      final userData = userSnapshot.data();
      if (room == null || player == null) return;
      if (player['isRemoved'] as bool? ?? false) return;

      final wasReconnecting = player['isReconnecting'] as bool? ?? false;
      final canonicalUsername = _publicUsername(
        userData?['username'] as String?,
        player['username'] as String?,
      );
      final now = FieldValue.serverTimestamp();
      final playerUpdates = <String, Object?>{
        'isOnline': true,
        'isReconnecting': false,
        'disconnectedAt': null,
        'reconnectDeadlineAt': null,
        'lastSeenAt': now,
        'lastReconnectAt': now,
        'updatedAt': now,
      };
      if (canonicalUsername != null) {
        playerUpdates['username'] = canonicalUsername;
      }
      transaction.update(playerRef, playerUpdates);
      transaction.set(userRef, {
        'activeRoomId': roomId,
        'activeRoomStatus':
            _isLobbyStatus(room['status'] as String? ?? 'waiting')
            ? 'lobby'
            : 'game',
        'lastSeenAt': now,
        'lastReconnectAt': now,
        'lastRoomExitReason': null,
        'lastRoomExitRoomId': null,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (wasReconnecting &&
          _shouldSendPresenceMessage(player['lastReconnectMessageAt'])) {
        transaction.update(playerRef, {'lastReconnectMessageAt': now});
        _setSystemMessage(
          transaction: transaction,
          roomRef: roomRef,
          message:
              '${canonicalUsername ?? player['username'] as String? ?? 'Player'} reconnected.',
        );
      }
    });
  }

  Future<void> markUserReconnecting(String roomId) async {
    if (!enableLifecyclePresenceSystem) return;
    if (kIsWeb && relaxedWebPresenceForTesting) return;

    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final roomRef = _rooms.doc(roomId);
    final playerRef = roomRef.collection('players').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final playerSnapshot = await transaction.get(playerRef);
      final player = playerSnapshot.data();
      if (player == null || (player['isRemoved'] as bool? ?? false)) return;
      if (player['isReconnecting'] as bool? ?? false) return;

      final now = FieldValue.serverTimestamp();
      transaction.update(playerRef, {
        'isOnline': false,
        'isReconnecting': true,
        'disconnectedAt': now,
        'reconnectDeadlineAt': Timestamp.fromDate(
          DateTime.now().add(reconnectWindow),
        ),
        'lastSeenAt': now,
        'updatedAt': now,
      });

      if (_shouldSendPresenceMessage(player['lastDisconnectMessageAt'])) {
        transaction.update(playerRef, {'lastDisconnectMessageAt': now});
        final username = _publicUsername(null, player['username'] as String?);
        _setSystemMessage(
          transaction: transaction,
          roomRef: roomRef,
          message: '${username ?? 'Player'} is reconnecting...',
        );
      }
    });
  }

  Future<void> handleVoluntaryLeave(String roomId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    await clearActiveRoom(user.uid, exitReason: 'left', roomId: roomId);
  }

  Future<void> cleanupExpiredReconnects(String roomId) async {
    if (!enableReconnectSystem) return;
    final roomRef = _rooms.doc(roomId);
    final playersSnapshot = await roomRef.collection('players').get();
    final expiredUids = <String>[];
    final now = DateTime.now();

    for (final player in playersSnapshot.docs) {
      final data = player.data();
      final deadline = data['reconnectDeadlineAt'];
      if ((data['isRemoved'] as bool? ?? false) ||
          (data['isOnline'] as bool? ?? true) ||
          (data['isReconnecting'] as bool? ?? false) == false) {
        continue;
      }
      if (deadline is Timestamp && !deadline.toDate().isAfter(now)) {
        expiredUids.add(player.id);
      }
    }

    if (expiredUids.isNotEmpty) {
      // GameService owns downgrade/end-game rules; this method is a consistency hook.
    }
  }

  Future<void> clearActiveRoom(
    String uid, {
    String? exitReason,
    String? roomId,
  }) {
    return _users.doc(uid).set({
      'activeRoomId': null,
      'activeRoomStatus': null,
      'lastRoomExitReason': exitReason,
      'lastRoomExitRoomId': roomId,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> validateRoomStillExists(String roomId) async {
    final snapshot = await _rooms.doc(roomId).get();
    final data = snapshot.data();
    if (data == null) return false;
    return (data['status'] as String?) != 'closed';
  }

  static bool isLobbyStatus(String status) => _isLobbyStatus(status);

  static bool _isLobbyStatus(String status) {
    return status == 'waiting' || status == 'waiting_next_round';
  }

  static String? _messageForExitReason(String? reason) {
    return switch (reason) {
      'left' => 'You left the room.',
      'afk' => 'You were disconnected for being AFK.',
      'game_closed' => 'Room has been closed.',
      _ => null,
    };
  }

  static bool _shouldSendPresenceMessage(Object? lastMessageAt) {
    if (lastMessageAt is! Timestamp) return true;
    return DateTime.now().difference(lastMessageAt.toDate()) >
        const Duration(seconds: 20);
  }

  static String? _publicUsername(String? preferred, String? fallback) {
    if (preferred != null &&
        preferred.trim().isNotEmpty &&
        !preferred.contains('@')) {
      return preferred;
    }
    if (fallback != null &&
        fallback.trim().isNotEmpty &&
        !fallback.contains('@')) {
      return fallback;
    }
    return null;
  }

  void _setSystemMessage({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> roomRef,
    required String message,
  }) {
    transaction.set(roomRef.collection('messages').doc(), {
      'senderUid': 'system',
      'senderUsername': "King's Guess",
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'system',
    });
  }
}
