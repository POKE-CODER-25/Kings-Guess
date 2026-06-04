import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/room_chat_panel.dart';
import '../game/game_screen.dart';
import '../game/game_service.dart';
import '../home/home_screen.dart';
import '../../services/audio_service.dart';
import '../../services/room_consistency_service.dart';
import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';
import '../../widgets/royal_nav.dart';
import '../../widgets/game_toast.dart';
import '../../widgets/game_badge.dart';
import '../../widgets/game_avatar.dart';
import '../../widgets/game_text_field.dart';
import '../../widgets/pressable_scale.dart';
import 'room_model.dart';
import 'room_service.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.roomId, required this.username});

  final String roomId;
  final String username;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with WidgetsBindingObserver {
  final _roomService = RoomService();
  final _gameService = GameService();
  final _consistencyService = RoomConsistencyService();

  bool _isStarting = false;
  bool _navigating = false;
  String? _error;
  DateTime? _lastAfkCheckAt;
  String? _lastAfkToastMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameService.markCurrentPlayerOnline(widget.roomId);
    AudioService.instance.playLobbyMusic();
  }

  @override
  void dispose() {
    AudioService.instance.stopLobbyMusic();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _gameService.markCurrentPlayerOnline(widget.roomId);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _gameService.markCurrentPlayerDisconnected(widget.roomId);
    }
  }

  Future<void> _startGame() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      await _gameService.startGame(widget.roomId);
      await AudioService.instance.stopLobbyMusic();

      if (!mounted) return;
      showGameEventToast(
        context,
        'Game starting',
        icon: Icons.play_arrow_rounded,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = _friendlyFirestoreError(error);
      setState(() => _error = message);
      showErrorToast(context, message);
    } on GameException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      showErrorToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() => _error = message);
      showErrorToast(context, message);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _checkAfkPlayers() async {
    try {
      await _gameService.checkAfkPlayers(widget.roomId);
    } catch (error) {
      if (mounted) {
        final message = error.toString();
        setState(() => _error = message);
        showErrorToast(context, message);
      }
    }
  }

  Future<void> _leaveRoom() async {
    try {
      await _gameService.leaveRoom(widget.roomId);
      if (!mounted) return;
      showSuccessToast(
        context,
        'You left the room.',
        icon: Icons.logout_rounded,
      );
      _navigateHome(
        HomeScreen(username: widget.username),
        'lobby leave room -> home',
      );
    } catch (error) {
      if (mounted) {
        final message = error.toString();
        setState(() => _error = message);
        showErrorToast(context, message);
      }
    }
  }

  void _scheduleReturnHome(String message) {
    if (_navigating || !mounted) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _consistencyService.clearActiveRoom(
          uid,
          exitReason: message == 'Room has been closed.' ? 'game_closed' : null,
          roomId: widget.roomId,
        );
      }
      if (!mounted) return;
      safeNavigateReplacement(
        context,
        HomeScreen(username: widget.username, initialMessage: message),
        'room closed -> home',
        clearStack: true,
      );
    });
  }

  void _navigateHome(Widget page, String reason) {
    if (_navigating || !mounted) return;
    _navigating = true;
    safeNavigateReplacement(context, page, reason, clearStack: true);
  }

  void _navigateToGame() {
    if (_navigating || !mounted) return;
    _navigating = true;
    safeNavigateReplacement(
      context,
      GameScreen(roomId: widget.roomId),
      'lobby -> game',
    );
  }

  void _showLobbyEventToasts(RoomModel room) {
    if (room.lastAfkActionMessage.isNotEmpty &&
        room.lastAfkActionMessage != _lastAfkToastMessage) {
      _lastAfkToastMessage = room.lastAfkActionMessage;
      final isLeaveMessage = room.lastAfkActionMessage.contains(
        'left the room',
      );
      _showToastAfterFrame(
        room.lastAfkActionMessage,
        icon: isLeaveMessage
            ? Icons.logout_rounded
            : Icons.person_remove_rounded,
      );
    }
  }

  void _showToastAfterFrame(String message, {required IconData icon}) {
    debugPrint('AUTO TOAST DISABLED: lobby route event: $message');
  }

  void _scheduleAfkCheck() {
    final now = DateTime.now();
    if (_lastAfkCheckAt != null &&
        now.difference(_lastAfkCheckAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastAfkCheckAt = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAfkPlayers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RoyalBackground(
        child: StreamBuilder<RoomModel?>(
          stream: _roomService.watchRoom(widget.roomId),
          builder: (context, roomSnapshot) {
            if (roomSnapshot.hasError) {
              return _LobbyShell(
                child: _CenteredMessage(
                  message: 'Could not load room. Check your connection',
                  onBack: () => Navigator.of(context).pop(),
                ),
              );
            }

            if (!roomSnapshot.hasData) {
              return const _LobbyShell(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final room = roomSnapshot.data;
            if (room == null) {
              _scheduleReturnHome('Room has been closed.');
              return _LobbyShell(
                child: _CenteredMessage(
                  message: 'Room not found',
                  onBack: () => Navigator.of(context).pop(),
                ),
              );
            }

            if (room.status == 'closed') {
              _scheduleReturnHome('Room has been closed.');
              return const _LobbyShell(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (room.status == 'round_active' ||
                room.status == 'round_complete' ||
                room.status == 'waiting_next_round' ||
                room.status == 'game_complete') {
              _navigateToGame();
            }

            return StreamBuilder<List<RoomPlayer>>(
              stream: _roomService.watchPlayers(widget.roomId),
              builder: (context, playersSnapshot) {
                if (playersSnapshot.hasError) {
                  return _LobbyShell(
                    child: _CenteredMessage(
                      message: 'Could not load players. Check your connection',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  );
                }

                final players = playersSnapshot.data ?? const <RoomPlayer>[];
                _scheduleAfkCheck();
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                final currentPlayer = players
                    .where((player) => player.uid == currentUid)
                    .firstOrNull;
                final isHost = currentUid == room.hostUid;
                final activePlayers = players
                    .where((player) => !player.isRemoved)
                    .toList();
                final playerCount = activePlayers.length;
                final canStart = playerCount >= 5 && playerCount <= 7;
                _showLobbyEventToasts(room);

                return _LobbyShell(
                  child: RoyalCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.castle_rounded,
                          size: 54,
                          color: Color(0xFFB83A4B),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "King's Guess",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 18),
                        _RoomDetails(room: room, playerCount: playerCount),
                        if (_hasOfflineActivePlayer(players)) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'A player disconnected. They have 2 minutes to reconnect.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (room.lastAfkActionMessage.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            room.lastAfkActionMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Players',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!playersSnapshot.hasData)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(),
                          )
                        else
                          _PlayersList(players: players),
                        const SizedBox(height: 18),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (isHost) ...[
                          if (!canStart)
                            Text(
                              'Need at least 5 players to start',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const SizedBox(height: 12),
                          _HostStartAction(
                            canStart: canStart && room.status == 'waiting',
                            isLoading: _isStarting,
                            onStart: _startGame,
                            alreadyStarted: room.status != 'waiting',
                          ),
                          const SizedBox(height: 10),
                          RoyalButton(
                            label: 'Check AFK Players',
                            icon: Icons.manage_search_rounded,
                            isSecondary: true,
                            onPressed: _checkAfkPlayers,
                          ),
                        ] else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                room.status != 'waiting'
                                    ? 'Game starting soon'
                                    : 'Waiting for host',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 8),
                              const WaitingDots(),
                            ],
                          ),
                        const SizedBox(height: 10),
                        Text(
                          room.status != 'waiting'
                              ? 'The room has started.'
                              : 'Waiting for players to join...',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        if (currentPlayer?.isRemoved == true &&
                            currentPlayer?.removalReason != 'left')
                          Text(
                            _removedPlayerMessage(currentPlayer?.removalReason),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: _leaveRoom,
                            icon: const Icon(Icons.exit_to_app_rounded),
                            label: const Text('Leave Room'),
                          ),
                        const SizedBox(height: 14),
                        RoomChatPanel(roomId: widget.roomId),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LobbyShell extends StatelessWidget {
  const _LobbyShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SingleChildScrollView(
      padding: EdgeInsets.all(width < 390 ? 14 : 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).vertical -
              44,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RoomDetails extends StatelessWidget {
  const _RoomDetails({required this.room, required this.playerCount});

  final RoomModel room;
  final int playerCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5B540), width: 2.5),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              GameBadge(
                label: '${room.selectedRounds} rounds',
                icon: Icons.casino_rounded,
              ),
              GameBadge(
                label: '$playerCount/${room.maxPlayers}',
                icon: Icons.groups_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.meeting_room_rounded,
            label: 'Room ID',
            value: room.roomId,
            canCopy: true,
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.lock_rounded,
            label: 'Password',
            value: room.password,
            canCopy: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatefulWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.canCopy = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool canCopy;

  @override
  State<_DetailRow> createState() => _DetailRowState();
}

class _DetailRowState extends State<_DetailRow> {
  bool _copied = false;

  void _copyValue() {
    Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7C879), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: const Color(0xFFB83A4B), size: 20),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        widget.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF7E4F2B),
                            ),
                      ),
                    ),
                  ),
                  if (widget.canCopy) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: IconButton.filledTonal(
                        onPressed: _copyValue,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(
                    width: 48,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: _copied ? 1 : 0,
                      child: const Text(
                        'Copied',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: Color(0xFF2F8F57),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayersList extends StatelessWidget {
  const _PlayersList({required this.players});

  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final activePlayers = players.where((player) => !player.isRemoved).toList();
    final removedPlayers = players.where((player) => player.isRemoved).toList();

    if (players.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No players yet'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final player in activePlayers) _LobbyPlayerTile(player: player),
        if (removedPlayers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Removed Players',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final player in removedPlayers)
            _LobbyPlayerTile(player: player, isRemovedSection: true),
        ],
      ],
    );
  }
}

class _LobbyPlayerTile extends StatelessWidget {
  const _LobbyPlayerTile({required this.player, this.isRemovedSection = false});

  final RoomPlayer player;
  final bool isRemovedSection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressableScale(
        enabled: !isRemovedSection,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7C879), width: 2),
          ),
          child: Row(
            children: [
              GameAvatar(
                label: player.username,
                isHost: player.isHost,
                isOnline: player.isOnline && !player.isRemoved,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '@${player.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isRemovedSection ? Colors.black54 : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GameBadge(
                label: player.isRemoved
                    ? player.removalReason ?? 'removed'
                    : player.isReconnecting
                    ? 'reconnecting...'
                    : player.isOnline
                    ? 'online'
                    : 'offline',
                icon: player.isReconnecting
                    ? Icons.sync_rounded
                    : player.isOnline
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                color: player.isReconnecting
                    ? const Color(0xFF7E4F2B)
                    : player.isOnline
                    ? const Color(0xFF2F8F57)
                    : const Color(0xFF7E4F2B),
              ),
              if (player.isHost) ...[
                const SizedBox(width: 8),
                const _GlowingHostBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowingHostBadge extends StatefulWidget {
  const _GlowingHostBadge();

  @override
  State<_GlowingHostBadge> createState() => _GlowingHostBadgeState();
}

class _GlowingHostBadgeState extends State<_GlowingHostBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE7B946),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFE7B946,
                ).withValues(alpha: 0.25 + (_controller.value * 0.35)),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Text(
            'Host',
            style: TextStyle(
              color: Color(0xFF4C2B20),
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}

class _HostStartAction extends StatefulWidget {
  const _HostStartAction({
    required this.canStart,
    required this.isLoading,
    required this.onStart,
    required this.alreadyStarted,
  });

  final bool canStart;
  final bool isLoading;
  final VoidCallback onStart;
  final bool alreadyStarted;

  @override
  State<_HostStartAction> createState() => _HostStartActionState();
}

class _HostStartActionState extends State<_HostStartAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.canStart ? 1 + (_controller.value * 0.025) : 1,
          child: RoyalButton(
            label: widget.alreadyStarted ? 'Game Started' : 'Start Game',
            icon: Icons.play_arrow_rounded,
            isLoading: widget.isLoading,
            onPressed: widget.canStart ? widget.onStart : null,
          ),
        );
      },
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return RoyalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          RoyalButton(
            label: 'Back Home',
            icon: Icons.home_rounded,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

String _friendlyFirestoreError(FirebaseException error) {
  return switch (error.code) {
    'permission-denied' => 'Room access denied. Check Firestore rules',
    'unavailable' => 'Network error. Check your connection',
    _ => error.message ?? 'Firestore error. Try again',
  };
}

bool _hasOfflineActivePlayer(List<RoomPlayer> players) {
  return players.any(
    (player) =>
        !player.isRemoved && (!player.isOnline || player.isReconnecting),
  );
}

String _removedPlayerMessage(String? reason) {
  return switch (reason) {
    'afk' => 'You were disconnected for being AFK.',
    'game_closed' => 'Room has been closed.',
    'left' => 'You left the room.',
    _ => 'You are no longer in this room.',
  };
}
