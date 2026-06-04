import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../config/presence_config.dart';
import '../../services/room_consistency_service.dart';
import 'game_rules.dart';

class GameException implements Exception {
  const GameException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GameRoom {
  const GameRoom({
    required this.roomId,
    required this.hostUid,
    required this.status,
    required this.currentRound,
    required this.selectedRounds,
    required this.activePlayerCount,
    required this.removedPlayerCount,
    required this.afkCheckRequired,
    required this.currentRoundStatus,
    required this.currentGuesserUid,
    required this.currentTargetRole,
    required this.currentRoleIndex,
    required this.turnEndsAt,
    required this.lastActionMessage,
    required this.lastAfkActionMessage,
    required this.gameEndedReason,
    required this.endGameVoteActive,
    required this.endGameRequestedByUid,
    required this.endGameRequestedByUsername,
    required this.endGameVoteStatus,
  });

  final String roomId;
  final String hostUid;
  final String status;
  final int currentRound;
  final int selectedRounds;
  final int activePlayerCount;
  final int removedPlayerCount;
  final bool afkCheckRequired;
  final String currentRoundStatus;
  final String currentGuesserUid;
  final String currentTargetRole;
  final int currentRoleIndex;
  final DateTime? turnEndsAt;
  final String lastActionMessage;
  final String lastAfkActionMessage;
  final String gameEndedReason;
  final bool endGameVoteActive;
  final String endGameRequestedByUid;
  final String endGameRequestedByUsername;
  final String? endGameVoteStatus;

  factory GameRoom.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final turnEndsAt = data['turnEndsAt'];

    return GameRoom(
      roomId: data['roomId'] as String? ?? snapshot.id,
      hostUid: data['hostUid'] as String? ?? '',
      status: data['status'] as String? ?? 'waiting',
      currentRound: data['currentRound'] as int? ?? 0,
      selectedRounds: data['selectedRounds'] as int? ?? 6,
      activePlayerCount: data['activePlayerCount'] as int? ?? 0,
      removedPlayerCount: data['removedPlayerCount'] as int? ?? 0,
      afkCheckRequired: data['afkCheckRequired'] as bool? ?? false,
      currentRoundStatus: data['currentRoundStatus'] as String? ?? 'active',
      currentGuesserUid: data['currentGuesserUid'] as String? ?? '',
      currentTargetRole: data['currentTargetRole'] as String? ?? '',
      currentRoleIndex: data['currentRoleIndex'] as int? ?? 0,
      turnEndsAt: turnEndsAt is Timestamp ? turnEndsAt.toDate() : null,
      lastActionMessage: data['lastActionMessage'] as String? ?? '',
      lastAfkActionMessage: data['lastAfkActionMessage'] as String? ?? '',
      gameEndedReason: data['gameEndedReason'] as String? ?? '',
      endGameVoteActive: data['endGameVoteActive'] as bool? ?? false,
      endGameRequestedByUid: data['endGameRequestedByUid'] as String? ?? '',
      endGameRequestedByUsername:
          data['endGameRequestedByUsername'] as String? ?? '',
      endGameVoteStatus: data['endGameVoteStatus'] as String?,
    );
  }
}

class EndGameVote {
  const EndGameVote({
    required this.uid,
    required this.username,
    required this.vote,
  });

  final String uid;
  final String username;
  final String vote;

  factory EndGameVote.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return EndGameVote(
      uid: data['uid'] as String? ?? snapshot.id,
      username: data['username'] as String? ?? 'unknown_player',
      vote: data['vote'] as String? ?? '',
    );
  }
}

class GamePlayer {
  const GamePlayer({
    required this.uid,
    required this.username,
    required this.isHost,
    required this.isOnline,
    required this.isReconnecting,
    required this.isRemoved,
    required this.score,
    required this.currentRole,
    required this.isRoundComplete,
    required this.completedRole,
    required this.removalReason,
  });

  final String uid;
  final String username;
  final bool isHost;
  final bool isOnline;
  final bool isReconnecting;
  final bool isRemoved;
  final int score;
  final String currentRole;
  final bool isRoundComplete;
  final String? completedRole;
  final String? removalReason;

  factory GamePlayer.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return GamePlayer(
      uid: data['uid'] as String? ?? snapshot.id,
      username: data['username'] as String? ?? 'unknown_player',
      isHost: data['isHost'] as bool? ?? false,
      isOnline: data['isOnline'] as bool? ?? false,
      isReconnecting: data['isReconnecting'] as bool? ?? false,
      isRemoved: data['isRemoved'] as bool? ?? false,
      score: data['score'] as int? ?? 0,
      currentRole: data['currentRole'] as String? ?? '',
      isRoundComplete: data['isRoundComplete'] as bool? ?? false,
      completedRole: data['completedRole'] as String?,
      removalReason: data['removalReason'] as String?,
    );
  }
}

class GameService {
  GameService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    Random? random,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _random = random ?? Random.secure();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final Random _random;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<GameRoom?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return GameRoom.fromSnapshot(snapshot);
    });
  }

  Stream<List<GamePlayer>> watchPlayers(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('players')
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(GamePlayer.fromSnapshot).toList());
  }

  Stream<List<EndGameVote>> watchEndGameVotes(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('endGameVotes')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(EndGameVote.fromSnapshot).toList(),
        );
  }

  Future<void> markCurrentPlayerOnline(String roomId) async {
    await RoomConsistencyService(
      firestore: _firestore,
      firebaseAuth: _firebaseAuth,
    ).markUserOnline(roomId);
  }

  Future<void> markCurrentPlayerDisconnected(String roomId) async {
    if (kIsWeb && relaxedWebPresenceForTesting) return;
    await RoomConsistencyService(
      firestore: _firestore,
      firebaseAuth: _firebaseAuth,
    ).markUserReconnecting(roomId);
  }

  Future<void> leaveRoom(String roomId) async {
    final user = _requireUser();
    final playerSnapshot = await _rooms
        .doc(roomId)
        .collection('players')
        .doc(user.uid)
        .get();
    final username =
        playerSnapshot.data()?['username'] as String? ??
        await _profileUsernameFor(user.uid) ??
        'Player';
    await _removePlayers(
      roomId: roomId,
      removedUids: [user.uid],
      reason: 'left',
      message: '$username left the room.',
    );
  }

  Future<void> checkAfkPlayers(String roomId) async {
    final roomRef = _rooms.doc(roomId);
    final playersSnapshot = await roomRef.collection('players').get();
    final afkUids = <String>[];

    for (final player in playersSnapshot.docs) {
      final data = player.data();
      final deadline = data['reconnectDeadlineAt'];
      final isOffline = (data['isOnline'] as bool? ?? true) == false;
      final isReconnecting = data['isReconnecting'] as bool? ?? false;
      final isRemoved = data['isRemoved'] as bool? ?? false;
      if (isOffline &&
          isReconnecting &&
          !isRemoved &&
          deadline is Timestamp &&
          !deadline.toDate().isAfter(DateTime.now())) {
        afkUids.add(player.id);
      }
    }

    if (afkUids.isEmpty) return;

    await _removePlayers(
      roomId: roomId,
      removedUids: afkUids,
      reason: 'afk',
      message: '${afkUids.length} player(s) disconnected for being AFK.',
    );
  }

  Future<void> requestEndGameVote(String roomId) async {
    final user = _requireUser();
    final roomRef = _rooms.doc(roomId);
    final playerRef = roomRef.collection('players').doc(user.uid);
    final voteRef = roomRef.collection('endGameVotes').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final playerSnapshot = await transaction.get(playerRef);
      final room = roomSnapshot.data();
      final player = playerSnapshot.data();

      if (room == null || player == null) {
        throw const GameException('Game not found');
      }
      if (room['endGameVoteActive'] as bool? ?? false) {
        throw const GameException('An end game vote is already active');
      }
      if (room['status'] == 'game_complete') {
        throw const GameException('Game is already complete');
      }
      if (player['isRemoved'] as bool? ?? false) {
        throw GameException(
          _removedMessage(player['removalReason'] as String?),
        );
      }

      transaction.set(voteRef, {
        'uid': user.uid,
        'username': player['username'] as String? ?? 'Player',
        'vote': 'accept',
        'votedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(roomRef, {
        'endGameVoteActive': true,
        'endGameRequestedByUid': user.uid,
        'endGameRequestedByUsername': player['username'] as String? ?? 'Player',
        'endGameVoteStartedAt': FieldValue.serverTimestamp(),
        'endGameVoteStatus': 'active',
        'lastActionMessage': 'A player requested to end the game.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _setSystemMessage(
        transaction: transaction,
        roomRef: roomRef,
        message: 'End game vote started',
      );
    });

    await evaluateEndGameVote(roomId);
  }

  Future<void> submitEndGameVote({
    required String roomId,
    required String vote,
  }) async {
    if (vote != 'accept' && vote != 'decline') {
      throw const GameException('Invalid vote');
    }

    final user = _requireUser();
    final roomRef = _rooms.doc(roomId);
    final playerRef = roomRef.collection('players').doc(user.uid);
    final voteRef = roomRef.collection('endGameVotes').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final playerSnapshot = await transaction.get(playerRef);
      final room = roomSnapshot.data();
      final player = playerSnapshot.data();

      if (room == null || player == null) {
        throw const GameException('Game not found');
      }
      if ((room['endGameVoteActive'] as bool? ?? false) == false) {
        throw const GameException('No active end game vote');
      }
      if (player['isRemoved'] as bool? ?? false) {
        throw GameException(
          _removedMessage(player['removalReason'] as String?),
        );
      }

      transaction.set(voteRef, {
        'uid': user.uid,
        'username': player['username'] as String? ?? 'Player',
        'vote': vote,
        'votedAt': FieldValue.serverTimestamp(),
      });
    });

    await evaluateEndGameVote(roomId);
  }

  Future<void> evaluateEndGameVote(String roomId) async {
    final roomRef = _rooms.doc(roomId);
    final playersSnapshot = await roomRef.collection('players').get();
    final votesSnapshot = await roomRef.collection('endGameVotes').get();

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final room = roomSnapshot.data();
      if (room == null ||
          (room['endGameVoteActive'] as bool? ?? false) == false) {
        return;
      }

      final activePlayers = playersSnapshot.docs
          .where(
            (player) => (player.data()['isRemoved'] as bool? ?? false) == false,
          )
          .toList();
      final activeUids = activePlayers.map((player) => player.id).toSet();
      final votesByUid = <String, String>{};
      for (final voteDoc in votesSnapshot.docs) {
        if (activeUids.contains(voteDoc.id)) {
          votesByUid[voteDoc.id] = voteDoc.data()['vote'] as String? ?? '';
        }
      }

      if (votesByUid.values.contains('decline')) {
        transaction.update(roomRef, {
          'endGameVoteActive': false,
          'endGameVoteStatus': 'declined',
          'lastActionMessage': 'End game vote declined.',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _setSystemMessage(
          transaction: transaction,
          roomRef: roomRef,
          message: 'End game vote declined',
        );
        return;
      }

      final acceptedCount = votesByUid.values
          .where((vote) => vote == 'accept')
          .length;
      if (activePlayers.isNotEmpty && acceptedCount >= activePlayers.length) {
        _cancelRoundAndEndGameInTransaction(
          transaction: transaction,
          roomRef: roomRef,
          playerSnapshots: playersSnapshot.docs,
          reason: 'Players voted to end the game early.',
        );
      }
    });
  }

  Future<void> startGame(String roomId) async {
    final user = _requireUser();
    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final room = roomSnapshot.data();

    if (room == null) {
      throw const GameException('Room not found');
    }
    if (room['hostUid'] != user.uid) {
      throw const GameException('Only host can start the game');
    }

    final playersSnapshot = await roomRef.collection('players').get();
    final players = playersSnapshot.docs
        .where(
          (player) => (player.data()['isRemoved'] as bool? ?? false) == false,
        )
        .toList();
    if (players.length < 5 || players.length > 7) {
      throw const GameException('Need 5 to 7 players to start');
    }

    final roles = GameRules.rolesForCount(
      players.length,
    ).map((role) => role.name).toList()..shuffle(_random);
    final now = DateTime.now();
    final kingIndex = roles.indexOf('King');
    final kingUid = players[kingIndex].id;
    final usernamesByUid = await _usernamesForPlayers(players);
    final batch = _firestore.batch();

    for (var index = 0; index < players.length; index++) {
      final data = players[index].data();
      final username =
          usernamesByUid[players[index].id] ??
          _publicUsername(data['username'] as String?) ??
          'Player';
      batch.set(players[index].reference, {
        'uid': data['uid'] as String? ?? players[index].id,
        'username': username,
        'isHost': data['isHost'] as bool? ?? false,
        'isOnline': data['isOnline'] as bool? ?? true,
        'isReconnecting': false,
        'disconnectedAt': null,
        'reconnectDeadlineAt': null,
        'lastDisconnectMessageAt': data['lastDisconnectMessageAt'],
        'lastReconnectMessageAt': data['lastReconnectMessageAt'],
        'lastAfkMessageAt': data['lastAfkMessageAt'],
        'isRemoved': false,
        'removedAt': null,
        'removalReason': null,
        'score': data['score'] as int? ?? 0,
        'roundScoreSnapshot': data['score'] as int? ?? 0,
        'currentRole': roles[index],
        'isRoundComplete': false,
        'completedRole': null,
      }, SetOptions(merge: true));
    }

    batch.update(roomRef, {
      'status': 'round_active',
      'currentRound': 1,
      'activePlayerCount': players.length,
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
      'currentGuesserUid': kingUid,
      'currentTargetRole': GameRules.firstTargetRole(players.length),
      'currentRoleIndex': 0,
      'turnStartedAt': Timestamp.fromDate(now),
      'turnEndsAt': Timestamp.fromDate(
        now.add(const Duration(seconds: GameRules.turnSeconds)),
      ),
      'lastActionMessage': 'Round 1 started. King guesses Queen.',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final player in players) {
      batch.set(_users.doc(player.id), {
        'activeRoomId': roomId,
        'activeRoomStatus': 'game',
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _setSystemMessageInBatch(
      batch: batch,
      roomRef: roomRef,
      message: 'Round 1 started',
    );

    await batch.commit();
  }

  Future<void> startNextRound(String roomId) async {
    final user = _requireUser();
    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final room = roomSnapshot.data();

    if (room == null) {
      throw const GameException('Room not found');
    }
    if (room['hostUid'] != user.uid) {
      throw const GameException('Only host can start the next round');
    }
    if (room['status'] != 'round_complete' &&
        room['status'] != 'waiting_next_round') {
      throw const GameException('Round is not complete yet');
    }

    final currentRound = room['currentRound'] as int? ?? 1;
    final selectedRounds = room['selectedRounds'] as int? ?? 6;
    final wasCancelled = room['currentRoundStatus'] == 'cancelled';
    if (!wasCancelled && currentRound >= selectedRounds) {
      final batch = _firestore.batch();
      batch.update(roomRef, {
        'status': 'game_complete',
        'lastActionMessage': 'Game complete.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _setSystemMessageInBatch(
        batch: batch,
        roomRef: roomRef,
        message: 'Game complete',
      );
      await batch.commit();
      return;
    }

    final playersSnapshot = await roomRef.collection('players').get();
    final players = playersSnapshot.docs
        .where(
          (player) => (player.data()['isRemoved'] as bool? ?? false) == false,
        )
        .toList();
    final playerCount = players.length;
    if (playerCount < 5) {
      final batch = _firestore.batch();
      batch.update(roomRef, {
        'status': 'game_complete',
        'gameEndedReason': 'Game ended because fewer than 5 players remained.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _setSystemMessageInBatch(
        batch: batch,
        roomRef: roomRef,
        message: 'Game ended because fewer than 5 players remained',
      );
      await batch.commit();
      return;
    }
    final roles = GameRules.rolesForCount(
      playerCount,
    ).map((role) => role.name).toList()..shuffle(_random);
    final now = DateTime.now();
    final kingIndex = roles.indexOf('King');
    final kingUid = players[kingIndex].id;
    final nextRound = wasCancelled ? currentRound : currentRound + 1;
    final batch = _firestore.batch();

    for (var index = 0; index < players.length; index++) {
      batch.update(players[index].reference, {
        'currentRole': roles[index],
        'roundScoreSnapshot': players[index].data()['score'] as int? ?? 0,
        'isRoundComplete': false,
        'completedRole': null,
      });
    }

    batch.update(roomRef, {
      'status': 'round_active',
      'currentRound': nextRound,
      'activePlayerCount': players.length,
      'currentRoundStatus': 'active',
      'currentGuesserUid': kingUid,
      'currentTargetRole': GameRules.firstTargetRole(playerCount),
      'currentRoleIndex': 0,
      'turnStartedAt': Timestamp.fromDate(now),
      'turnEndsAt': Timestamp.fromDate(
        now.add(const Duration(seconds: GameRules.turnSeconds)),
      ),
      'lastActionMessage': 'Round $nextRound started. King guesses Queen.',
      'endGameVoteActive': false,
      'endGameRequestedByUid': null,
      'endGameRequestedByUsername': null,
      'endGameVoteStartedAt': null,
      'endGameVoteStatus': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _setSystemMessageInBatch(
      batch: batch,
      roomRef: roomRef,
      message: 'Round $nextRound started',
    );

    await batch.commit();
  }

  Future<void> makeGuess({
    required String roomId,
    required String guessedUid,
  }) async {
    final user = _requireUser();
    if (user.uid == guessedUid) {
      throw const GameException('You cannot guess yourself');
    }

    await _applyGuess(
      roomId: roomId,
      guesserUid: user.uid,
      guessedUid: guessedUid,
    );
  }

  Future<void> makeRandomGuessIfTurnExpired(String roomId) async {
    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final room = roomSnapshot.data();
    if (room == null || room['status'] != 'round_active') return;

    final turnEndsAt = room['turnEndsAt'];
    if (turnEndsAt is! Timestamp ||
        turnEndsAt.toDate().isAfter(DateTime.now())) {
      return;
    }

    final currentGuesserUid = room['currentGuesserUid'] as String?;
    if (currentGuesserUid == null || currentGuesserUid.isEmpty) return;

    final playersSnapshot = await roomRef.collection('players').get();
    final validTargets = playersSnapshot.docs
        .where((player) {
          final data = player.data();
          return player.id != currentGuesserUid &&
              (data['isRemoved'] as bool? ?? false) == false &&
              (data['isRoundComplete'] as bool? ?? false) == false;
        })
        .map((player) => player.id)
        .toList();
    if (validTargets.isEmpty) return;

    await _applyGuess(
      roomId: roomId,
      guesserUid: currentGuesserUid,
      guessedUid: validTargets[_random.nextInt(validTargets.length)],
      requireExpiredTurn: true,
    );
  }

  Future<void> _applyGuess({
    required String roomId,
    required String guesserUid,
    required String guessedUid,
    bool requireExpiredTurn = false,
  }) async {
    final roomRef = _rooms.doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final room = roomSnapshot.data();
      if (room == null) {
        throw const GameException('Room not found');
      }
      if (room['status'] != 'round_active') {
        throw const GameException('Round is not active');
      }
      if (room['currentGuesserUid'] != guesserUid) {
        throw const GameException('It is not your turn');
      }

      final turnEndsAt = room['turnEndsAt'];
      if (requireExpiredTurn &&
          (turnEndsAt is! Timestamp ||
              turnEndsAt.toDate().isAfter(DateTime.now()))) {
        return;
      }

      final guesserRef = roomRef.collection('players').doc(guesserUid);
      final guessedRef = roomRef.collection('players').doc(guessedUid);
      final guesserSnapshot = await transaction.get(guesserRef);
      final guessedSnapshot = await transaction.get(guessedRef);
      final guesser = guesserSnapshot.data();
      final guessed = guessedSnapshot.data();
      if (guesser == null || guessed == null) {
        throw const GameException('Player not found');
      }
      if (guessedUid == guesserUid) {
        throw const GameException('You cannot guess yourself');
      }
      if (guesser['isRemoved'] as bool? ?? false) {
        throw GameException(
          _removedMessage(guesser['removalReason'] as String?),
        );
      }
      if (guessed['isRemoved'] as bool? ?? false) {
        throw const GameException('That player was removed');
      }
      if (guesser['isRoundComplete'] as bool? ?? false) {
        throw const GameException('You already completed this round');
      }
      if (guessed['isRoundComplete'] as bool? ?? false) {
        throw const GameException('That player completed this round');
      }

      final playerCount = room['activePlayerCount'] as int? ?? 5;
      final targetRole = room['currentTargetRole'] as String? ?? '';
      final currentRoleIndex = room['currentRoleIndex'] as int? ?? 0;
      final guesserRole = guesser['currentRole'] as String? ?? '';
      final guessedRole = guessed['currentRole'] as String? ?? '';
      final guesserName = guesser['username'] as String? ?? 'Player';
      final guessedName = guessed['username'] as String? ?? 'Player';
      final now = DateTime.now();

      if (guessedRole == targetRole) {
        final earnedScore = GameRules.scoreForRole(guesserRole, playerCount);
        final currentScore = guesser['score'] as int? ?? 0;
        transaction.update(guesserRef, {
          'score': currentScore + earnedScore,
          'isRoundComplete': true,
          'completedRole': guesserRole,
        });

        if (GameRules.isFinalRole(targetRole, playerCount)) {
          final currentRound = room['currentRound'] as int? ?? 1;
          final selectedRounds = room['selectedRounds'] as int? ?? 1;
          transaction.update(roomRef, {
            'status': currentRound >= selectedRounds
                ? 'game_complete'
                : 'round_complete',
            'currentRoundStatus': currentRound >= selectedRounds
                ? 'complete'
                : 'complete',
            'currentGuesserUid': guessedUid,
            'lastActionMessage':
                '$guesserName found $targetRole. Round complete.',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _setSystemMessage(
            transaction: transaction,
            roomRef: roomRef,
            message: 'King guessed correctly',
          );
        } else {
          final nextRoleIndex = currentRoleIndex + 1;
          transaction.update(roomRef, {
            'currentGuesserUid': guessedUid,
            'currentTargetRole': GameRules.nextTargetRole(
              playerCount: playerCount,
              currentRoleIndex: currentRoleIndex,
            ),
            'currentRoleIndex': nextRoleIndex,
            'turnStartedAt': Timestamp.fromDate(now),
            'turnEndsAt': Timestamp.fromDate(
              now.add(const Duration(seconds: GameRules.turnSeconds)),
            ),
            'lastActionMessage': '$guesserName correctly guessed $guessedName.',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _setSystemMessage(
            transaction: transaction,
            roomRef: roomRef,
            message: '$guesserName guessed correctly',
          );
        }
      } else {
        transaction.update(guesserRef, {'currentRole': guessedRole});
        transaction.update(guessedRef, {'currentRole': guesserRole});
        transaction.update(roomRef, {
          'currentGuesserUid': guessedUid,
          'turnStartedAt': Timestamp.fromDate(now),
          'turnEndsAt': Timestamp.fromDate(
            now.add(const Duration(seconds: GameRules.turnSeconds)),
          ),
          'lastActionMessage': '$guesserName guessed wrong. Roles swapped.',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> _removePlayers({
    required String roomId,
    required List<String> removedUids,
    required String reason,
    required String message,
  }) async {
    if (removedUids.isEmpty) return;

    final roomRef = _rooms.doc(roomId);
    final playerRefs = (await roomRef.collection('players').get()).docs
        .map((player) => player.reference)
        .toList();
    final removedUidSet = removedUids.toSet();

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final room = roomSnapshot.data();
      if (room == null) {
        throw const GameException('Room not found');
      }

      final playerSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final playerRef in playerRefs) {
        playerSnapshots.add(await transaction.get(playerRef));
      }

      final now = FieldValue.serverTimestamp();
      for (final playerSnapshot in playerSnapshots) {
        if (!removedUidSet.contains(playerSnapshot.id)) continue;
        final data = playerSnapshot.data();
        if (data == null || (data['isRemoved'] as bool? ?? false)) continue;

        transaction.update(playerSnapshot.reference, {
          'isOnline': false,
          'disconnectedAt': data['disconnectedAt'] ?? now,
          'isReconnecting': false,
          'reconnectDeadlineAt': null,
          'isRemoved': true,
          'removedAt': now,
          'removalReason': reason,
          'isRoundComplete': false,
          'completedRole': null,
        });
      }

      final activeAfterRemoval = playerSnapshots.where((snapshot) {
        final data = snapshot.data();
        if (data == null) return false;
        final wasAlreadyRemoved = data['isRemoved'] as bool? ?? false;
        final removedNow = removedUidSet.contains(snapshot.id);
        return !wasAlreadyRemoved && !removedNow;
      }).toList();
      final removedAfterRemoval =
          playerSnapshots.length - activeAfterRemoval.length;
      final currentStatus = room['status'] as String? ?? 'waiting';
      final isRoundActive = currentStatus == 'round_active';
      final roomUpdates = <String, Object?>{
        'activePlayerCount': activeAfterRemoval.length,
        'removedPlayerCount': removedAfterRemoval,
        'afkCheckRequired': false,
        'lastAfkActionMessage': message,
        'updatedAt': now,
      };

      if (isRoundActive) {
        for (final playerSnapshot in playerSnapshots) {
          final data = playerSnapshot.data();
          if (data == null) continue;
          final snapshotScore = data['roundScoreSnapshot'] as int?;
          if (snapshotScore != null) {
            transaction.update(playerSnapshot.reference, {
              'score': snapshotScore,
              'currentRole': null,
              'isRoundComplete': false,
              'completedRole': null,
            });
          } else {
            transaction.update(playerSnapshot.reference, {
              'currentRole': null,
              'isRoundComplete': false,
              'completedRole': null,
            });
          }
        }

        roomUpdates.addAll({
          'currentRoundStatus': 'cancelled',
          'currentGuesserUid': null,
          'currentTargetRole': null,
          'currentRoleIndex': 0,
          'turnStartedAt': null,
          'turnEndsAt': null,
        });

        if (activeAfterRemoval.length < 5) {
          roomUpdates.addAll(
            _gameCompleteFields(
              'Game ended because fewer than 5 players remained.',
            ),
          );
        } else {
          roomUpdates['status'] = 'waiting_next_round';
        }
      } else if (activeAfterRemoval.length < 5 &&
          (currentStatus == 'round_complete' ||
              currentStatus == 'waiting_next_round')) {
        roomUpdates.addAll({
          'status': 'game_complete',
          'gameEndedReason':
              'Game ended because fewer than 5 players remained.',
          'endGameVoteActive': false,
        });
      }

      for (final uid in removedUidSet) {
        transaction.set(_users.doc(uid), {
          'activeRoomId': null,
          'activeRoomStatus': null,
          'lastRoomExitReason': reason,
          'lastRoomExitRoomId': roomId,
          'lastSeenAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }

      transaction.update(roomRef, roomUpdates);
      _setSystemMessage(
        transaction: transaction,
        roomRef: roomRef,
        message: message,
      );
    });

    await evaluateEndGameVote(roomId);
  }

  void _cancelRoundAndEndGameInTransaction({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> roomRef,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> playerSnapshots,
    required String reason,
  }) {
    for (final playerSnapshot in playerSnapshots) {
      final data = playerSnapshot.data();
      final snapshotScore = data['roundScoreSnapshot'] as int?;
      final playerUpdates = <String, Object?>{
        'currentRole': null,
        'isRoundComplete': false,
        'completedRole': null,
      };
      if (snapshotScore != null) {
        playerUpdates['score'] = snapshotScore;
      }
      transaction.update(playerSnapshot.reference, playerUpdates);
    }

    transaction.update(roomRef, {
      'currentRoundStatus': 'cancelled',
      'currentGuesserUid': null,
      'currentTargetRole': null,
      'currentRoleIndex': 0,
      'turnStartedAt': null,
      'turnEndsAt': null,
      ..._gameCompleteFields(reason, voteAccepted: true),
    });
    _setSystemMessage(
      transaction: transaction,
      roomRef: roomRef,
      message: 'End game vote accepted',
    );
  }

  Map<String, Object?> _gameCompleteFields(
    String reason, {
    bool voteAccepted = false,
  }) {
    return {
      'status': 'game_complete',
      'gameEndedReason': reason,
      'endGameVoteActive': false,
      'endGameVoteStatus': voteAccepted ? 'accepted' : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  User _requireUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const GameException('Please login again');
    }
    return user;
  }

  String _removedMessage(String? reason) {
    return switch (reason) {
      'left' => 'You left the room.',
      'afk' => 'You were disconnected for being AFK.',
      'game_closed' => 'Room has been closed.',
      _ => 'You are no longer in this game.',
    };
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

  void _setSystemMessageInBatch({
    required WriteBatch batch,
    required DocumentReference<Map<String, dynamic>> roomRef,
    required String message,
  }) {
    batch.set(roomRef.collection('messages').doc(), {
      'senderUid': 'system',
      'senderUsername': "King's Guess",
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'system',
    });
  }

  Future<Map<String, String>> _usernamesForPlayers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> players,
  ) async {
    final result = <String, String>{};
    for (final player in players) {
      final profile = await _users.doc(player.id).get();
      final username = _publicUsername(profile.data()?['username'] as String?);
      if (username != null) result[player.id] = username;
    }
    return result;
  }

  String? _publicUsername(String? value) {
    if (value == null || value.trim().isEmpty || value.contains('@')) {
      return null;
    }
    return value;
  }

  Future<String?> _profileUsernameFor(String uid) async {
    final profile = await _users.doc(uid).get();
    return _publicUsername(profile.data()?['username'] as String?);
  }
}
