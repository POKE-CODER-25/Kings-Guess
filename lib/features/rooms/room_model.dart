import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  const RoomModel({
    required this.roomId,
    required this.password,
    required this.hostUid,
    required this.hostUsername,
    required this.status,
    required this.maxPlayers,
    required this.selectedRounds,
    required this.activePlayerCount,
    required this.removedPlayerCount,
    required this.lastAfkActionMessage,
  });

  final String roomId;
  final String password;
  final String hostUid;
  final String hostUsername;
  final String status;
  final int maxPlayers;
  final int selectedRounds;
  final int activePlayerCount;
  final int removedPlayerCount;
  final String lastAfkActionMessage;

  factory RoomModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return RoomModel(
      roomId: data['roomId'] as String? ?? snapshot.id,
      password: data['password'] as String? ?? '',
      hostUid: data['hostUid'] as String? ?? '',
      hostUsername: data['hostUsername'] as String? ?? '',
      status: data['status'] as String? ?? 'waiting',
      maxPlayers: data['maxPlayers'] as int? ?? 7,
      selectedRounds: data['selectedRounds'] as int? ?? 6,
      activePlayerCount: data['activePlayerCount'] as int? ?? 0,
      removedPlayerCount: data['removedPlayerCount'] as int? ?? 0,
      lastAfkActionMessage: data['lastAfkActionMessage'] as String? ?? '',
    );
  }
}

class RoomPlayer {
  const RoomPlayer({
    required this.uid,
    required this.username,
    required this.isHost,
    required this.isOnline,
    required this.isReconnecting,
    required this.isRemoved,
    required this.score,
    required this.removalReason,
  });

  final String uid;
  final String username;
  final bool isHost;
  final bool isOnline;
  final bool isReconnecting;
  final bool isRemoved;
  final int score;
  final String? removalReason;

  factory RoomPlayer.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return RoomPlayer(
      uid: data['uid'] as String? ?? snapshot.id,
      username: data['username'] as String? ?? 'unknown_player',
      isHost: data['isHost'] as bool? ?? false,
      isOnline: data['isOnline'] as bool? ?? false,
      isReconnecting: data['isReconnecting'] as bool? ?? false,
      isRemoved: data['isRemoved'] as bool? ?? false,
      score: data['score'] as int? ?? 0,
      removalReason: data['removalReason'] as String?,
    );
  }
}
