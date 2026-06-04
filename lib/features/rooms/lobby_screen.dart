import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/presence_config.dart';
import '../../config/polish_config.dart';
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
import '../../widgets/game_divider.dart';
import '../../widgets/game_screen_background.dart';
import '../../widgets/game_section_title.dart';
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
  bool _leaveInProgress = false;
  String? _error;
  DateTime? _lastAfkCheckAt;
  String? _lastAfkToastMessage;

  @override
  void initState() {
    super.initState();
    if (enableLifecyclePresenceSystem) {
      WidgetsBinding.instance.addObserver(this);
      _gameService.markCurrentPlayerOnline(widget.roomId);
    }
    AudioService.instance.playLobbyMusic();
  }

  @override
  void dispose() {
    AudioService.instance.stopLobbyMusic();
    if (enableLifecyclePresenceSystem) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enableLifecyclePresenceSystem) return;
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

  void _leaveRoom() {
    debugPrint('LEAVE_ROOM_PRESSED');
    if (_leaveInProgress || !mounted) return;
    setState(() => _leaveInProgress = true);
    _showSnackBar('You left the room.');
    unawaited(_leaveRoomInBackground());
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(username: widget.username)),
      (route) => false,
    );
  }

  Future<void> _leaveRoomInBackground() async {
    try {
      await _gameService.leaveRoom(widget.roomId);
      await _clearCurrentActiveRoom(exitReason: 'left');
    } catch (error, stackTrace) {
      debugPrint('LEAVE ROOM FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleReturnHome(String message) {
    if (_navigating || !mounted) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _clearCurrentActiveRoom(
        exitReason: message == 'Room has been closed.' ? 'game_closed' : null,
      );
      if (!mounted) return;
      safeNavigateReplacement(
        context,
        HomeScreen(username: widget.username, initialMessage: message),
        'room closed -> home',
        clearStack: true,
      );
    });
  }

  Future<void> _clearCurrentActiveRoom({String? exitReason}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _consistencyService.clearActiveRoom(
      uid,
      exitReason: exitReason,
      roomId: widget.roomId,
    );
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
    if (!enableReconnectSystem) return;
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
        type: GameScreenType.lobby,
        child: StreamBuilder<RoomModel?>(
          stream: _roomService.watchRoom(widget.roomId),
          builder: (context, roomSnapshot) {
            if (roomSnapshot.hasError) {
              return _LobbyShell(
                child: _CenteredMessage(
                  message: 'Could not load room. Check your connection',
                  onBack: _goHomeNow,
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
                  onBack: _goHomeNow,
                ),
              );
            }

            if (room.status == 'closed') {
              _scheduleReturnHome('Room has been closed.');
              return const _LobbyShell(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (room.status == 'round_active') {
              _navigateToGame();
            }

            return StreamBuilder<List<RoomPlayer>>(
              stream: _roomService.watchPlayers(widget.roomId),
              builder: (context, playersSnapshot) {
                if (playersSnapshot.hasError) {
                  return _LobbyShell(
                    child: _CenteredMessage(
                      message: 'Could not load players. Check your connection',
                      onBack: _goHomeNow,
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
                        const SizedBox(height: 16),
                        const GameDivider(),
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
                        const GameSectionTitle(
                          title: 'Players',
                          subtitle: 'The court waiting room',
                          icon: Icons.groups_rounded,
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
                        _LobbyActionPanel(
                          child: Column(
                            children: [
                              if (isHost) ...[
                                if (!canStart)
                                  Text(
                                    'Need at least 5 players to start',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                _HostStartAction(
                                  canStart:
                                      canStart && room.status == 'waiting',
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
                                    Flexible(
                                      child: Text(
                                        room.status != 'waiting'
                                            ? 'Game starting soon'
                                            : 'Waiting for host',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
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
                            onPressed: _leaveInProgress ? null : _leaveRoom,
                            icon: const Icon(Icons.exit_to_app_rounded),
                            label: Text(
                              _leaveInProgress ? 'Leaving...' : 'Leave Room',
                            ),
                          ),
                        const SizedBox(height: 14),
                        _LobbyChatFrame(roomId: widget.roomId),
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

  void _goHomeNow() {
    unawaited(
      _clearCurrentActiveRoom().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('CLEAR ACTIVE ROOM FAILED: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(username: widget.username)),
      (route) => false,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFAEC), Color(0xFFFFE6A0)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5B540), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55351A10),
            blurRadius: 0,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x33351A10),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const GameSectionTitle(
            title: 'Court Pass',
            subtitle: 'Share these credentials with players',
            icon: Icons.vpn_key_rounded,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              GameBadge(
                label: '${room.selectedRounds} rounds',
                icon: Icons.casino_rounded,
                color: const Color(0xFFB83A4B),
              ),
              GameBadge(
                label: '$playerCount/${room.maxPlayers}',
                icon: Icons.groups_rounded,
                color: const Color(0xFF233B7A),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.meeting_room_rounded,
            label: 'Room ID',
            value: room.roomId,
            canCopy: true,
          ),
          const SizedBox(height: 8),
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
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _copyValue,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _copied
                                ? const [Color(0xFF52C77C), Color(0xFF2F8F57)]
                                : const [Color(0xFFFFE6A0), Color(0xFFE5B540)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFFAEC)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44351A10),
                              blurRadius: 0,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          color: _copied
                              ? Colors.white
                              : const Color(0xFF4C2B20),
                          size: 19,
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
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isRemovedSection
                  ? const [Color(0xFFEFE4D0), Color(0xFFD8CAB5)]
                  : player.isHost
                  ? const [Color(0xFFFFFAEC), Color(0xFFFFDFA0)]
                  : const [Color(0xFFFFF4D9), Color(0xFFFFFAEC)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: player.isHost
                  ? const Color(0xFFE5B540)
                  : const Color(0xFFE7C879),
              width: player.isHost ? 2.5 : 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44351A10),
                blurRadius: 0,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x22351A10),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${player.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isRemovedSection
                            ? Colors.black54
                            : const Color(0xFF4C2B20),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      player.isHost ? 'Court host' : 'Waiting player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF76543C),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GameBadge(
                  label: player.isRemoved
                      ? player.removalReason ?? 'removed'
                      : player.isReconnecting
                      ? 'reconnecting'
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
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (disablePolishForDebug) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD86B), Color(0xFFD99A2B)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(0xFFFFFAEC), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55351A10),
              blurRadius: 0,
              offset: Offset(0, 3),
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
    }

    final controller = _controller!;
    return AnimatedBuilder(
      animation: controller,
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
                ).withValues(alpha: 0.25 + (controller.value * 0.35)),
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
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (disablePolishForDebug) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x44E5B540), Color(0x11233B7A)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x66E5B540)),
        ),
        child: RoyalButton(
          label: widget.alreadyStarted ? 'Game Started' : 'Start Game',
          icon: Icons.play_arrow_rounded,
          isLoading: widget.isLoading,
          onPressed: widget.canStart ? widget.onStart : null,
        ),
      );
    }

    final controller = _controller!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.canStart ? 1 + (controller.value * 0.025) : 1,
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

class _LobbyActionPanel extends StatelessWidget {
  const _LobbyActionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFAEC), Color(0xFFFFE6A0)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5B540), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55351A10),
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Color(0x22351A10),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          const GameSectionTitle(
            title: 'Ready Area',
            subtitle: 'Start when the court is full',
            icon: Icons.flag_rounded,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LobbyChatFrame extends StatelessWidget {
  const _LobbyChatFrame({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x22E5B540), Color(0x11B83A4B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x66E5B540)),
      ),
      child: Column(
        children: [
          const GameSectionTitle(
            title: 'Court Chat',
            subtitle: 'Coordinate before the match',
            icon: Icons.forum_rounded,
          ),
          const SizedBox(height: 10),
          RoomChatPanel(roomId: roomId),
        ],
      ),
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
