import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RoomChatMessage {
  const RoomChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderUsername,
    required this.message,
    required this.createdAt,
    required this.type,
  });

  final String id;
  final String senderUid;
  final String senderUsername;
  final String message;
  final DateTime? createdAt;
  final String type;

  bool get isSystem => type == 'system';

  factory RoomChatMessage.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final createdAt = data['createdAt'];

    return RoomChatMessage(
      id: snapshot.id,
      senderUid: data['senderUid'] as String? ?? '',
      senderUsername: data['senderUsername'] as String? ?? 'Player',
      message: data['message'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      type: data['type'] as String? ?? 'player',
    );
  }
}

class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static const maxMessageLength = 120;
  static const cooldown = Duration(seconds: 1);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  Stream<List<RoomChatMessage>> watchMessages(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
        .limitToLast(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(RoomChatMessage.fromSnapshot).toList(),
        );
  }

  Future<void> sendPlayerMessage({
    required String roomId,
    required String message,
  }) async {
    final user = _requireUser();
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw const ChatException('Enter a message first');
    }
    if (trimmed.length > maxMessageLength) {
      throw const ChatException('Messages can be 120 characters max');
    }

    final roomRef = _rooms.doc(roomId);
    final playerRef = roomRef.collection('players').doc(user.uid);
    final messageRef = roomRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final playerSnapshot = await transaction.get(playerRef);
      final player = playerSnapshot.data();
      if (player == null) {
        throw const ChatException('You are not in this room');
      }
      if (player['isRemoved'] as bool? ?? false) {
        throw const ChatException('Removed players cannot send messages');
      }

      transaction.set(messageRef, {
        'senderUid': user.uid,
        'senderUsername': player['username'] as String? ?? 'Player',
        'message': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'player',
      });
    });
  }

  User _requireUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ChatException('Please login again');
    }
    return user;
  }
}
