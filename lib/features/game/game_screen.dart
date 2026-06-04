import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/polish_config.dart';
import '../../config/presence_config.dart';
import '../chat/room_chat_panel.dart';
import '../home/home_screen.dart';
import '../../services/audio_service.dart';
import '../../services/room_consistency_service.dart';
import '../../widgets/game_button.dart';
import '../../widgets/game_particle_overlay.dart';
import '../../widgets/game_panel.dart';
import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';
import '../../widgets/royal_nav.dart';
import '../../widgets/game_toast.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/role_visuals.dart';
import 'data/role_data.dart';
import 'game_service.dart';
import 'widgets/role_character_card.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final _gameService = GameService();
  final _consistencyService = RoomConsistencyService();

  Timer? _timer;
  DateTime? _turnEndsAt;
  DateTime? _lastAutoGuessForTurn;
  DateTime? _lastAfkCheckAt;
  bool _isGuessing = false;
  bool _navigating = false;
  bool _leaveInProgress = false;
  bool _endGameRequestInProgress = false;
  String? _error;
  String? _lastActionToastMessage;
  String? _lastAfkToastMessage;
  String? _lastVoteToastStatus;
  bool? _lastVoteActive;
  DateTime? _lastTimerWarningForTurn;
  String? _lastRoomStatus;
  String? _lastGuesserUid;
  int _effectNonce = 0;
  _GameEffectKind? _effectKind;
  String? _scorePopupText;
  String? _dismissedRoleRevealKey;
  GameMood _currentMood = GameMood.normal;
  DateTime? _effectStartedAt;
  final Map<String, int> _scoreByUid = {};

  @override
  void initState() {
    super.initState();
    if (enableLifecyclePresenceSystem) {
      WidgetsBinding.instance.addObserver(this);
      _gameService.markCurrentPlayerOnline(widget.roomId);
    }
    AudioService.instance.stopLobbyMusic();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _playTimerWarningIfNeeded();
      _autoGuessIfExpired();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  Future<void> _guess(String guessedUid) async {
    final guesserUid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('GUESS ATTEMPT: $guesserUid -> $guessedUid');
    setState(() {
      _isGuessing = true;
      _error = null;
    });

    try {
      await _gameService.makeGuess(
        roomId: widget.roomId,
        guessedUid: guessedUid,
      );
      debugPrint('GUESS SUCCESS');
    } on GameException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      _showGuessFailure(error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = _friendlyFirebaseError(error);
      setState(() => _error = message);
      _showGuessFailure(message);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() => _error = message);
      _showGuessFailure(message);
    } finally {
      if (mounted) setState(() => _isGuessing = false);
    }
  }

  Future<void> _confirmGuess(GameRoom room, GamePlayer player) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final blockReason = _guessBlockReason(room, player, currentUid);
    if (blockReason != null) {
      _showGuessFailure(blockReason);
      return;
    }

    if (disablePolishForDebug) {
      await _guess(player.uid);
      return;
    }

    final targetRole = room.currentTargetRole.isEmpty
        ? 'the target'
        : room.currentTargetRole;
    final shouldAccuse = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) =>
          _AccusationDramaDialog(player: player, targetRole: targetRole),
    );
    if (!mounted) return;
    if (shouldAccuse != true) return;

    _triggerGameEffect(_GameEffectKind.suspense);
    await Future<void>.delayed(const Duration(milliseconds: 460));
    if (!mounted) return;
    await _guess(player.uid);
  }

  void _showGuessFailure(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _guessBlockReason(GameRoom room, GamePlayer player, String? uid) {
    if (room.status != 'round_active') return 'Round is not active';
    if (uid == null || uid != room.currentGuesserUid) {
      return 'It is not your turn';
    }
    if (player.uid == uid) return 'You cannot guess yourself';
    if (player.isRemoved) return 'That player was removed';
    if (player.isRoundComplete) return 'That player completed this round';
    return null;
  }

  Future<void> _startNextRound() async {
    setState(() {
      _isGuessing = true;
      _error = null;
    });

    try {
      await _gameService.startNextRound(widget.roomId);
    } on GameException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      showErrorToast(context, error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = _friendlyFirebaseError(error);
      setState(() => _error = message);
      showErrorToast(context, message);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() => _error = message);
      showErrorToast(context, message);
    } finally {
      if (mounted) setState(() => _isGuessing = false);
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

  void _leaveRoom(String? username) {
    debugPrint('LEAVE_ROOM_PRESSED');
    if (_leaveInProgress || !mounted) return;
    setState(() => _leaveInProgress = true);
    _showActionSnackBar('You left the room.');
    unawaited(_leaveRoomInBackground());
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(username: username ?? 'player'),
      ),
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

  void _scheduleReturnHome(String message, String? username) {
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
        HomeScreen(username: username ?? 'player', initialMessage: message),
        'game room closed -> home',
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

  Future<void> _requestEndGameVote() async {
    debugPrint('END GAME REQUEST CLICKED');
    if (_endGameRequestInProgress || _leaveInProgress || !mounted) return;
    setState(() {
      _endGameRequestInProgress = true;
      _error = null;
    });
    try {
      debugPrint('END GAME REQUEST STARTED');
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      await _gameService.requestEndGameVote(widget.roomId);
      debugPrint('END GAME REQUEST FINISHED');
      if (!mounted) return;
      _showActionSnackBar('End game vote requested.');
    } on GameException catch (error, stackTrace) {
      debugPrint('END GAME REQUEST FAILED: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _error = error.message);
      _showActionSnackBar(error.message);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('END GAME REQUEST FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final message = _friendlyFirebaseError(error);
      setState(() => _error = message);
      _showActionSnackBar(message);
    } catch (error, stackTrace) {
      debugPrint('END GAME REQUEST FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final message = error.toString();
      setState(() => _error = message);
      _showActionSnackBar(message);
    } finally {
      if (mounted) {
        setState(() => _endGameRequestInProgress = false);
      } else {
        _endGameRequestInProgress = false;
      }
    }
  }

  void _showActionSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitEndGameVote(String vote) async {
    setState(() => _error = null);
    try {
      await _gameService.submitEndGameVote(roomId: widget.roomId, vote: vote);
    } on GameException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      showErrorToast(context, error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = _friendlyFirebaseError(error);
      setState(() => _error = message);
      showErrorToast(context, message);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() => _error = message);
      showErrorToast(context, message);
    }
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

  Future<void> _autoGuessIfExpired() async {
    final turnEndsAt = _turnEndsAt;
    if (turnEndsAt == null || turnEndsAt.isAfter(DateTime.now())) return;
    if (_lastAutoGuessForTurn == turnEndsAt) return;

    _lastAutoGuessForTurn = turnEndsAt;
    try {
      await _gameService.makeRandomGuessIfTurnExpired(widget.roomId);
    } catch (_) {
      // Another client may have already advanced the turn.
    }
  }

  void _playTimerWarningIfNeeded() {
    final turnEndsAt = _turnEndsAt;
    if (turnEndsAt == null || _lastTimerWarningForTurn == turnEndsAt) return;

    final secondsLeft = _secondsLeft(turnEndsAt);
    if (secondsLeft > 0 && secondsLeft <= 10) {
      _lastTimerWarningForTurn = turnEndsAt;
      AudioService.instance.playTimerWarning();
    }
  }

  void _showGameEventToasts(GameRoom room, List<GamePlayer> players) {
    if (_lastRoomStatus == null) {
      _lastRoomStatus = room.status;
      if (room.status == 'game_complete') {
        AudioService.instance.playVictory();
      }
    } else if (room.status != _lastRoomStatus) {
      _lastRoomStatus = room.status;
      if (room.status == 'game_complete') {
        AudioService.instance.playVictory();
      }
    }

    final actionMessage = room.lastActionMessage;
    if (_lastActionToastMessage == null) {
      _lastActionToastMessage = actionMessage;
      if (actionMessage.contains('Round') &&
          actionMessage.contains('started')) {
        _playActionSound(actionMessage);
        _triggerActionEffect(actionMessage);
        _showToastAfterFrame(
          _friendlyActionToast(actionMessage),
          icon: _actionToastIcon(actionMessage),
        );
      }
    } else if (actionMessage.isNotEmpty &&
        actionMessage != _lastActionToastMessage) {
      _lastActionToastMessage = actionMessage;
      _playActionSound(actionMessage);
      _triggerActionEffect(actionMessage);
      _showToastAfterFrame(
        _friendlyActionToast(actionMessage),
        icon: _actionToastIcon(actionMessage),
        success:
            actionMessage.contains('correctly') ||
            actionMessage.contains('found'),
      );
    }

    if (_lastGuesserUid == null) {
      _lastGuesserUid = room.currentGuesserUid;
    } else if (room.currentGuesserUid.isNotEmpty &&
        room.currentGuesserUid != _lastGuesserUid) {
      _lastGuesserUid = room.currentGuesserUid;
    }

    if (_lastAfkToastMessage == null) {
      _lastAfkToastMessage = room.lastAfkActionMessage;
    } else if (room.lastAfkActionMessage.isNotEmpty &&
        room.lastAfkActionMessage != _lastAfkToastMessage) {
      _lastAfkToastMessage = room.lastAfkActionMessage;
      final isLeaveMessage = room.lastAfkActionMessage.contains(
        'left the room',
      );
      if (!isLeaveMessage) {
        AudioService.instance.playWrong();
        _triggerGameEffect(_GameEffectKind.suspense);
      }
      _showToastAfterFrame(
        room.lastAfkActionMessage,
        icon: isLeaveMessage
            ? Icons.logout_rounded
            : Icons.person_remove_rounded,
      );
    }

    if (_lastVoteActive == null) {
      _lastVoteActive = room.endGameVoteActive;
    } else if (!_lastVoteActive! && room.endGameVoteActive) {
      _lastVoteActive = true;
      AudioService.instance.playClick();
      _showToastAfterFrame(
        'End game vote started',
        icon: Icons.how_to_vote_rounded,
      );
    } else if (_lastVoteActive! && !room.endGameVoteActive) {
      _lastVoteActive = false;
    }

    final voteStatus = room.endGameVoteStatus;
    if (_lastVoteToastStatus == null) {
      _lastVoteToastStatus = voteStatus;
    } else if (voteStatus != null &&
        voteStatus != _lastVoteToastStatus &&
        voteStatus != 'active') {
      _lastVoteToastStatus = voteStatus;
      if (voteStatus == 'accepted') {
        AudioService.instance.playCorrect();
      } else {
        AudioService.instance.playWrong();
      }
      _showToastAfterFrame(
        voteStatus == 'accepted'
            ? 'End game vote accepted'
            : 'End game vote declined',
        icon: voteStatus == 'accepted'
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded,
        success: voteStatus == 'accepted',
      );
    }

    for (final player in players.where((player) => !player.isRemoved)) {
      final previousScore = _scoreByUid[player.uid];
      if (previousScore != null && player.score > previousScore) {
        _triggerGameEffect(
          _GameEffectKind.success,
          scorePopupText: '+${player.score - previousScore}',
        );
      }
      _scoreByUid[player.uid] = player.score;
    }
  }

  void _triggerActionEffect(String message) {
    if (message.contains('Round complete')) {
      _triggerGameEffect(_GameEffectKind.roundComplete);
      return;
    }
    if (message.contains('guessed wrong')) {
      _triggerGameEffect(_GameEffectKind.wrong);
      return;
    }
    if (message.contains('correctly') || message.contains('found')) {
      _triggerGameEffect(_GameEffectKind.success);
      return;
    }
    if (message.contains('Round') && message.contains('started')) {
      _triggerGameEffect(_GameEffectKind.roundStart);
    }
  }

  void _triggerGameEffect(_GameEffectKind kind, {String? scorePopupText}) {
    if (disablePolishForDebug) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _effectKind = kind;
        _scorePopupText = scorePopupText;
        _effectStartedAt = DateTime.now();
        _effectNonce++;
      });
    });
  }

  void _showToastAfterFrame(
    String message, {
    required IconData icon,
    bool success = false,
  }) {
    debugPrint('AUTO TOAST DISABLED: game route event: $message');
  }

  String? _roleRevealKey(GameRoom room, GamePlayer? player) {
    if (player == null || player.currentRole.isEmpty) return null;
    if (room.status == 'game_complete') return null;
    return '${room.roomId}-${room.currentRound}-${player.uid}';
  }

  bool _shouldShowRoleReveal(GameRoom room, GamePlayer? player) {
    if (disablePolishForDebug) return false;
    final key = _roleRevealKey(room, player);
    if (key == null) return false;
    return key != _dismissedRoleRevealKey;
  }

  GameMood _moodFor(GameRoom room, bool isCurrentGuesser) {
    if (room.endGameVoteActive) return GameMood.endGameVote;
    final effectStartedAt = _effectStartedAt;
    final effectFresh =
        effectStartedAt != null &&
        DateTime.now().difference(effectStartedAt) <
            const Duration(milliseconds: 1500);
    if (effectFresh && _effectKind == _GameEffectKind.success) {
      return GameMood.correct;
    }
    if (effectFresh && _effectKind == _GameEffectKind.wrong) {
      return GameMood.wrong;
    }
    if (_secondsLeft(room.turnEndsAt) <= 20 &&
        room.status != 'round_complete' &&
        room.status != 'waiting_next_round') {
      return GameMood.lowTimer;
    }
    if (isCurrentGuesser) return GameMood.myTurn;
    return GameMood.normal;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: RoyalBackground(
        child: Stack(
          children: [
            StreamBuilder<GameRoom?>(
              stream: _gameService.watchRoom(widget.roomId),
              builder: (context, roomSnapshot) {
                if (roomSnapshot.hasError) {
                  return const _GameShell(
                    child: _MessageCard(message: 'Could not load game'),
                  );
                }

                final room = roomSnapshot.data;
                if (room == null) {
                  _scheduleReturnHome('Room has been closed.', null);
                  return const _GameShell(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (room.status == 'closed') {
                  _scheduleReturnHome('Room has been closed.', null);
                  return const _GameShell(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                _turnEndsAt = room.turnEndsAt;

                return StreamBuilder<List<GamePlayer>>(
                  stream: _gameService.watchPlayers(widget.roomId),
                  builder: (context, playersSnapshot) {
                    if (playersSnapshot.hasError) {
                      return const _GameShell(
                        child: _MessageCard(message: 'Could not load players'),
                      );
                    }

                    final players =
                        playersSnapshot.data ?? const <GamePlayer>[];
                    _scheduleAfkCheck();
                    final me = _playerByUid(players, currentUid);
                    final guesser = _playerByUid(
                      players,
                      room.currentGuesserUid,
                    );
                    final isHost = currentUid == room.hostUid;
                    final isCurrentGuesser =
                        currentUid == room.currentGuesserUid;
                    _currentMood = _moodFor(room, isCurrentGuesser);
                    _showGameEventToasts(room, players);

                    if (me?.isRemoved == true) {
                      final message = _removedPlayerMessage(me?.removalReason);
                      _scheduleReturnHome(message, me?.username);
                      return const _GameShell(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return StreamBuilder<List<EndGameVote>>(
                      stream: _gameService.watchEndGameVotes(widget.roomId),
                      builder: (context, votesSnapshot) {
                        final votes =
                            votesSnapshot.data ?? const <EndGameVote>[];

                        if (room.status == 'game_complete') {
                          return _GameShell(
                            transitionKey: const ValueKey('final-results'),
                            child: _FinalResultsCard(
                              room: room,
                              players: players,
                              error: _error,
                            ),
                          );
                        }

                        final revealKey = _roleRevealKey(room, me);
                        return Stack(
                          children: [
                            _GameShell(
                              transitionKey: ValueKey(
                                '${room.status}-${room.currentGuesserUid}',
                              ),
                              child: _CinematicGameView(
                                room: room,
                                players: players,
                                votes: votes,
                                currentUid: currentUid,
                                me: me,
                                guesser: guesser,
                                isHost: isHost,
                                isCurrentGuesser: isCurrentGuesser,
                                isLoading: _isGuessing,
                                error: _error,
                                turnEndsAt: room.turnEndsAt,
                                onGuessPlayer: (player) =>
                                    _confirmGuess(room, player),
                                onStartNextRound: _startNextRound,
                                onCheckAfkPlayers: _checkAfkPlayers,
                                isLeaving: _leaveInProgress,
                                isEndGameRequesting: _endGameRequestInProgress,
                                onRequestEndGameVote:
                                    me != null &&
                                        !me.isRemoved &&
                                        !room.endGameVoteActive &&
                                        !_endGameRequestInProgress &&
                                        !_leaveInProgress
                                    ? _requestEndGameVote
                                    : null,
                                onAcceptVote: () =>
                                    _submitEndGameVote('accept'),
                                onDeclineVote: () =>
                                    _submitEndGameVote('decline'),
                                onLeaveRoom: () => _leaveRoom(me?.username),
                              ),
                            ),
                            if (_shouldShowRoleReveal(room, me) &&
                                revealKey != null)
                              Positioned.fill(
                                child: _RoleRevealOverlay(
                                  player: me!,
                                  onContinue: () {
                                    setState(
                                      () => _dismissedRoleRevealKey = revealKey,
                                    );
                                    AudioService.instance.playRoundStart();
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
            RepaintBoundary(
              child: _GameEffectOverlay(
                key: ValueKey(_effectNonce),
                kind: _effectKind,
                scoreText: _scorePopupText,
              ),
            ),
            GameMoodOverlay(mood: _currentMood),
            Positioned(
              right: 14,
              bottom: 14 + MediaQuery.paddingOf(context).bottom,
              child: RepaintBoundary(
                child: RoomChatPanel(roomId: widget.roomId, isFloating: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _GameEffectKind { success, wrong, suspense, roundStart, roundComplete }

class _AccusationDramaDialog extends StatefulWidget {
  const _AccusationDramaDialog({
    required this.player,
    required this.targetRole,
  });

  final GamePlayer player;
  final String targetRole;

  @override
  State<_AccusationDramaDialog> createState() => _AccusationDramaDialogState();
}

class _AccusationDramaDialogState extends State<_AccusationDramaDialog>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (disablePolishForDebug) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black54,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AccusedSpotlightCard(
                  player: widget.player,
                  targetRole: widget.targetRole,
                ),
                const SizedBox(height: 18),
                _AccusationActionBar(
                  player: widget.player,
                  targetRole: widget.targetRole,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller!;
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(controller.value);
          return BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 4 * t, sigmaY: 4 * t),
            child: Stack(
              children: [
                Container(color: Colors.black.withValues(alpha: 0.54 * t)),
                Opacity(
                  opacity: t,
                  child: const GameParticleOverlay(
                    style: GameParticleStyle.fog,
                    intensity: 1.05,
                    duration: Duration(seconds: 8),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.58,
                        colors: [
                          const Color(0xFFFFE6A0).withValues(alpha: 0.26 * t),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Transform.translate(
                                  offset: Offset(0, 24 * (1 - t)),
                                  child: Transform.scale(
                                    scale: 0.92 + (0.08 * t),
                                    child: _AccusedSpotlightCard(
                                      player: widget.player,
                                      targetRole: widget.targetRole,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _AccusationActionBar(
                                  player: widget.player,
                                  targetRole: widget.targetRole,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccusedSpotlightCard extends StatelessWidget {
  const _AccusedSpotlightCard({required this.player, required this.targetRole});

  final GamePlayer player;
  final String targetRole;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE6A0), Color(0xFFB83A4B)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99E5B540),
              blurRadius: 36,
              spreadRadius: 3,
            ),
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF4D9), Color(0xFFFFDFA0)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.gavel_rounded,
                color: Color(0xFFB83A4B),
                size: 46,
              ),
              const SizedBox(height: 10),
              Text(
                'The court goes silent.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF351A10),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 118,
                height: 138,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF23325F),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFFFE6A0), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x77365D91), blurRadius: 22),
                  ],
                ),
                child: const Text('?', style: TextStyle(fontSize: 54)),
              ),
              const SizedBox(height: 14),
              Text(
                '@${player.username}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFB83A4B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Accused of being the $targetRole',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4C2B20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccusationActionBar extends StatelessWidget {
  const _AccusationActionBar({required this.player, required this.targetRole});

  final GamePlayer player;
  final String targetRole;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xDD261B32),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFFFE6A0), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lock in this accusation?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFF4D9),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: 'Cancel',
                    icon: Icons.close_rounded,
                    style: GameButtonStyle.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    label: 'Accuse',
                    icon: Icons.gavel_rounded,
                    style: GameButtonStyle.danger,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleRevealOverlay extends StatefulWidget {
  const _RoleRevealOverlay({required this.player, required this.onContinue});

  final GamePlayer player;
  final VoidCallback onContinue;

  @override
  State<_RoleRevealOverlay> createState() => _RoleRevealOverlayState();
}

class _RoleRevealOverlayState extends State<_RoleRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleCatalog.byName(widget.player.currentRole);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onContinue,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_controller.value);
            return Stack(
              children: [
                Container(color: Colors.black.withValues(alpha: 0.68 * t)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _RevealParticlesPainter(
                        progress: _controller.value,
                        color: role.glowColor,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 460,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Opacity(
                                      opacity: t,
                                      child: Transform.translate(
                                        offset: Offset(0, 18 * (1 - t)),
                                        child: Text(
                                          'Your Court Role',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: const Color(0xFFFFF4D9),
                                                fontWeight: FontWeight.w900,
                                                shadows: const [
                                                  Shadow(
                                                    color: Color(0xAA000000),
                                                    blurRadius: 12,
                                                  ),
                                                ],
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    RoleCharacterCard(
                                      role: role,
                                      playerUsername: widget.player.username,
                                      size: RoleCharacterCardSize.hero,
                                      showLore: true,
                                    ),
                                    const SizedBox(height: 18),
                                    Opacity(
                                      opacity: t,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xE6FFF4D9),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: role.glowColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Text(
                                          'Tap to continue',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF351A10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RevealParticlesPainter extends CustomPainter {
  const _RevealParticlesPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final seed = i * 37.0;
      final x = (math.sin(seed) * 0.5 + 0.5) * size.width;
      final drift = math.sin(progress * math.pi * 2 + i) * 18;
      final y = ((1 - progress) * size.height + seed) % size.height;
      final alpha = (math.sin(progress * math.pi) * 0.55).clamp(0.0, 1.0);
      paint.color = (i.isEven ? color : const Color(0xFFFFF4D9)).withValues(
        alpha: alpha,
      );
      canvas.drawCircle(Offset(x + drift, y), 2.5 + (i % 3), paint);
    }

    final spotlight = Paint()
      ..shader =
          RadialGradient(
            colors: [color.withValues(alpha: 0.28), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height * 0.42),
              radius: size.shortestSide * 0.52,
            ),
          );
    canvas.drawRect(Offset.zero & size, spotlight);
  }

  @override
  bool shouldRepaint(covariant _RevealParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _CinematicGameView extends StatefulWidget {
  const _CinematicGameView({
    required this.room,
    required this.players,
    required this.votes,
    required this.currentUid,
    required this.me,
    required this.guesser,
    required this.isHost,
    required this.isCurrentGuesser,
    required this.isLoading,
    required this.error,
    required this.turnEndsAt,
    required this.onGuessPlayer,
    required this.onStartNextRound,
    required this.onCheckAfkPlayers,
    required this.isLeaving,
    required this.isEndGameRequesting,
    required this.onRequestEndGameVote,
    required this.onAcceptVote,
    required this.onDeclineVote,
    required this.onLeaveRoom,
  });

  final GameRoom room;
  final List<GamePlayer> players;
  final List<EndGameVote> votes;
  final String? currentUid;
  final GamePlayer? me;
  final GamePlayer? guesser;
  final bool isHost;
  final bool isCurrentGuesser;
  final bool isLoading;
  final String? error;
  final DateTime? turnEndsAt;
  final ValueChanged<GamePlayer> onGuessPlayer;
  final VoidCallback onStartNextRound;
  final VoidCallback onCheckAfkPlayers;
  final bool isLeaving;
  final bool isEndGameRequesting;
  final VoidCallback? onRequestEndGameVote;
  final VoidCallback onAcceptVote;
  final VoidCallback onDeclineVote;
  final VoidCallback onLeaveRoom;

  @override
  State<_CinematicGameView> createState() => _CinematicGameViewState();
}

class _CinematicGameViewState extends State<_CinematicGameView> {
  bool _scoreboardOpen = false;
  bool _menuOpen = false;
  bool _royalCourtOpen = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final players = widget.players;
    final activePlayers = players.where((player) => !player.isRemoved).length;
    final roundComplete =
        room.status == 'round_complete' || room.status == 'waiting_next_round';
    final hasOffline = _hasOfflineActivePlayer(players);

    return Stack(
      children: [
        const Positioned.fill(child: _CourtEnvironmentBackdrop()),
        Column(
          children: [
            _GameTopHud(
              room: room,
              activePlayerCount: activePlayers,
              isScoreboardOpen: _scoreboardOpen,
              isMenuOpen: _menuOpen,
              onToggleScoreboard: () =>
                  setState(() => _scoreboardOpen = !_scoreboardOpen),
              onToggleMenu: () => setState(() => _menuOpen = !_menuOpen),
            ),
            const SizedBox(height: 12),
            _SlideDrawer(
              open: _scoreboardOpen,
              child: RepaintBoundary(
                child: _ScoreboardDrawer(players: players),
              ),
            ),
            _SlideDrawer(
              open: _menuOpen,
              child: _GameMenuDrawer(
                room: room,
                isHost: widget.isHost,
                canRequestEndGame: widget.onRequestEndGameVote != null,
                isEndGameRequesting: widget.isEndGameRequesting,
                isLeaving: widget.isLeaving,
                onRequestEndGameVote: widget.onRequestEndGameVote,
                onCheckAfkPlayers: widget.onCheckAfkPlayers,
                onLeaveRoom: widget.onLeaveRoom,
              ),
            ),
            if (room.endGameVoteActive) ...[
              const SizedBox(height: 12),
              _EndGameVoteCard(
                room: room,
                players: players,
                votes: widget.votes,
                currentUid: widget.currentUid,
                onAccept: widget.onAcceptVote,
                onDecline: widget.onDeclineVote,
              ),
            ] else if (room.endGameVoteStatus == 'declined') ...[
              const SizedBox(height: 10),
              _EventStrip(
                icon: Icons.cancel_rounded,
                message: 'End game vote declined.',
                danger: true,
              ),
            ],
            if (hasOffline) ...[
              const SizedBox(height: 10),
              const _EventStrip(
                icon: Icons.wifi_off_rounded,
                message: 'A player disconnected. Reconnect window is active.',
              ),
            ],
            if (room.lastAfkActionMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              _EventStrip(
                icon: Icons.hourglass_bottom_rounded,
                message: room.lastAfkActionMessage,
                danger: true,
              ),
            ],
            const SizedBox(height: 12),
            _CourtArena(
              room: room,
              players: players,
              me: widget.me,
              guesser: widget.guesser,
              isCurrentGuesser: widget.isCurrentGuesser,
              isLoading: widget.isLoading,
              turnEndsAt: widget.turnEndsAt,
              onGuessPlayer: widget.onGuessPlayer,
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              _EventStrip(
                icon: Icons.error_rounded,
                message: widget.error!,
                danger: true,
              ),
            ],
            if (roundComplete) ...[
              const SizedBox(height: 14),
              _RoundCompleteControls(
                isHost: widget.isHost,
                canStartNext: room.currentRound <= room.selectedRounds,
                isLoading: widget.isLoading,
                onStartNextRound: widget.onStartNextRound,
              ),
            ],
            const SizedBox(height: 14),
            _RoyalCourtDrawer(
              players: players,
              open: _royalCourtOpen,
              onToggle: () =>
                  setState(() => _royalCourtOpen = !_royalCourtOpen),
            ),
          ],
        ),
      ],
    );
  }
}

class _CourtEnvironmentBackdrop extends StatelessWidget {
  const _CourtEnvironmentBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 82,
            left: 20,
            right: 20,
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                gradient: const RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    Color(0x33FFE6A0),
                    Color(0x22000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -44,
            top: 210,
            child: _CourtPillar(color: const Color(0x4423325F)),
          ),
          Positioned(
            right: -44,
            top: 210,
            child: _CourtPillar(color: const Color(0x4423325F)),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 14,
            child: Container(
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: const RadialGradient(
                  colors: [Color(0x337E4F2B), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtPillar extends StatelessWidget {
  const _CourtPillar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 310,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0x22FFE6A0), width: 2),
      ),
    );
  }
}

class _GameTopHud extends StatelessWidget {
  const _GameTopHud({
    required this.room,
    required this.activePlayerCount,
    required this.isScoreboardOpen,
    required this.isMenuOpen,
    required this.onToggleScoreboard,
    required this.onToggleMenu,
  });

  final GameRoom room;
  final int activePlayerCount;
  final bool isScoreboardOpen;
  final bool isMenuOpen;
  final VoidCallback onToggleScoreboard;
  final VoidCallback onToggleMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HudPill(
            icon: Icons.flag_rounded,
            label: 'Round ${room.currentRound}/${room.selectedRounds}',
          ),
        ),
        const SizedBox(width: 8),
        _HudPill(icon: Icons.groups_rounded, label: '$activePlayerCount'),
        const SizedBox(width: 8),
        _HudIconButton(
          icon: Icons.leaderboard_rounded,
          selected: isScoreboardOpen,
          onPressed: onToggleScoreboard,
        ),
        const SizedBox(width: 8),
        _HudIconButton(
          icon: Icons.menu_rounded,
          selected: isMenuOpen,
          onPressed: onToggleMenu,
        ),
      ],
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: const Color(0xE6261B32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5B540), width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFFE6A0), size: 19),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFF4D9),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onPressed: onPressed,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE5B540) : const Color(0xE6261B32),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFE6A0), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: selected ? const Color(0xFF351A10) : const Color(0xFFFFE6A0),
        ),
      ),
    );
  }
}

class _SlideDrawer extends StatelessWidget {
  const _SlideDrawer({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return open
          ? Padding(padding: const EdgeInsets.only(bottom: 12), child: child)
          : const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: open
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: Offset.zero,
                child: FadeTransition(
                  opacity: const AlwaysStoppedAnimation(1),
                  child: child,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _CourtArena extends StatelessWidget {
  const _CourtArena({
    required this.room,
    required this.players,
    required this.me,
    required this.guesser,
    required this.isCurrentGuesser,
    required this.isLoading,
    required this.turnEndsAt,
    required this.onGuessPlayer,
  });

  final GameRoom room;
  final List<GamePlayer> players;
  final GamePlayer? me;
  final GamePlayer? guesser;
  final bool isCurrentGuesser;
  final bool isLoading;
  final DateTime? turnEndsAt;
  final ValueChanged<GamePlayer> onGuessPlayer;

  @override
  Widget build(BuildContext context) {
    final isRoundComplete =
        room.status == 'round_complete' || room.status == 'waiting_next_round';
    final activeTargets = players
        .where(
          (player) =>
              player.uid != me?.uid &&
              !player.isRemoved &&
              !player.isRoundComplete,
        )
        .toList();

    return GamePanel(
      variant: GamePanelVariant.compact,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.15,
                    colors: [
                      Color(0x55FFE6A0),
                      Color(0x2299453E),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              _TurnSpotlightBanner(
                room: room,
                guesser: guesser,
                isCurrentGuesser: isCurrentGuesser,
                isRoundComplete: isRoundComplete,
              ),
              const SizedBox(height: 14),
              RepaintBoundary(child: _PressureTimer(turnEndsAt: turnEndsAt)),
              const SizedBox(height: 16),
              RepaintBoundary(child: _MyRoleCard(player: me)),
              const SizedBox(height: 16),
              if (room.lastActionMessage.isNotEmpty)
                _EventStrip(
                  icon: _actionToastIcon(room.lastActionMessage),
                  message: _friendlyActionToast(room.lastActionMessage),
                  danger: room.lastActionMessage.contains('wrong'),
                ),
              const SizedBox(height: 16),
              if (isRoundComplete)
                _RoundCompleteBanner(room: room)
              else
                _SuspectStage(
                  players: activeTargets,
                  isCurrentGuesser: isCurrentGuesser,
                  isLoading: isLoading,
                  targetRole: room.currentTargetRole,
                  onGuessPlayer: onGuessPlayer,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurnSpotlightBanner extends StatelessWidget {
  const _TurnSpotlightBanner({
    required this.room,
    required this.guesser,
    required this.isCurrentGuesser,
    required this.isRoundComplete,
  });

  final GameRoom room;
  final GamePlayer? guesser;
  final bool isCurrentGuesser;
  final bool isRoundComplete;

  @override
  Widget build(BuildContext context) {
    final target = room.currentTargetRole.isEmpty
        ? 'the truth'
        : room.currentTargetRole;
    final text = isRoundComplete
        ? 'Round complete'
        : isCurrentGuesser
        ? 'Your Turn: Find the $target'
        : '@${guesser?.username ?? 'the court'} is searching for the $target...';

    final banner = Container(
      key: ValueKey(text),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentGuesser
              ? const [Color(0xFFE5B540), Color(0xFFFFE6A0)]
              : const [Color(0xFF23325F), Color(0xFF6B2B4D)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFF4D9), width: 1.7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isCurrentGuesser ? const Color(0xFF351A10) : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (disablePolishForDebug) return banner;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.18), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
      child: banner,
    );
  }
}

class _PressureTimer extends StatefulWidget {
  const _PressureTimer({required this.turnEndsAt});

  final DateTime? turnEndsAt;

  @override
  State<_PressureTimer> createState() => _PressureTimerState();
}

class _PressureTimerState extends State<_PressureTimer> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondsLeft = _secondsLeft(widget.turnEndsAt);
    final danger = secondsLeft <= 10;
    final warning = secondsLeft <= 20;
    final progress = (secondsLeft / 60).clamp(0.0, 1.0);
    final color = danger
        ? const Color(0xFFB83A4B)
        : warning
        ? const Color(0xFFFFA53B)
        : const Color(0xFFE5B540);
    final minutes = (secondsLeft ~/ 60).toString();
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');

    final timerFace = SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 10,
            strokeCap: StrokeCap.round,
            backgroundColor: const Color(0xFFFFE6A0),
            color: color,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$minutes:$seconds',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: danger ? const Color(0xFFB83A4B) : null,
                  ),
                ),
                if (warning)
                  Text(
                    danger ? 'DANGER' : 'HURRY',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (disablePolishForDebug) return timerFace;

    return TweenAnimationBuilder<double>(
      key: ValueKey(warning ? secondsLeft : 0),
      tween: Tween(begin: 1, end: warning ? 1.08 : 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: warning ? scale : 1, child: child),
      child: timerFace,
    );
  }
}

class _SuspectStage extends StatelessWidget {
  const _SuspectStage({
    required this.players,
    required this.isCurrentGuesser,
    required this.isLoading,
    required this.targetRole,
    required this.onGuessPlayer,
  });

  final List<GamePlayer> players;
  final bool isCurrentGuesser;
  final bool isLoading;
  final String targetRole;
  final ValueChanged<GamePlayer> onGuessPlayer;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const _EventStrip(
        icon: Icons.workspace_premium_rounded,
        message: 'No active suspects remain.',
      );
    }

    return Column(
      children: [
        Text(
          isCurrentGuesser
              ? 'Choose your suspect'
              : 'The court waits in shadow',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final player in players)
                  SizedBox(
                    width: wide
                        ? ((constraints.maxWidth - 12) / 2).clamp(190, 260)
                        : constraints.maxWidth,
                    child: _SuspectCard(
                      player: player,
                      enabled: isCurrentGuesser && !isLoading,
                      targetRole: targetRole,
                      onTap: () => onGuessPlayer(player),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SuspectCard extends StatefulWidget {
  const _SuspectCard({
    required this.player,
    required this.enabled,
    required this.targetRole,
    required this.onTap,
  });

  final GamePlayer player;
  final bool enabled;
  final String targetRole;
  final VoidCallback onTap;

  @override
  State<_SuspectCard> createState() => _SuspectCardState();
}

class _SuspectCardState extends State<_SuspectCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final focused = widget.enabled && _pressed;
    if (disablePolishForDebug) {
      return Opacity(
        opacity: widget.enabled ? 1 : 0.72,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF4D9), Color(0xFFFFDFA0)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.enabled
                    ? const Color(0xFFE5B540)
                    : const Color(0xFFE7C879),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF23325F),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFFE6A0),
                      width: 2,
                    ),
                  ),
                  child: const Text('?', style: TextStyle(fontSize: 30)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${widget.player.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.enabled
                            ? 'Accuse as ${widget.targetRole.isEmpty ? 'target' : widget.targetRole}'
                            : widget.player.isReconnecting
                            ? 'Reconnecting...'
                            : widget.player.isOnline
                            ? 'Mysterious court card'
                            : 'Disconnected',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (widget.enabled) const Icon(Icons.gavel_rounded),
              ],
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: widget.enabled ? 1 : 0.72,
      child: Listener(
        onPointerDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onPointerUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap();
              }
            : null,
        onPointerCancel: widget.enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_pressed ? 0.025 : 0)
            ..rotateY(_pressed ? -0.018 : 0)
            ..translateByDouble(0.0, _pressed ? 3.0 : 0.0, 0.0, 1.0),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF4D9), Color(0xFFFFDFA0)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.enabled
                  ? const Color(0xFFE5B540)
                  : const Color(0xFFE7C879),
              width: focused ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: focused
                    ? const Color(0x88E5B540)
                    : const Color(0x44351A10),
                blurRadius: focused ? 22 : 14,
                offset: Offset(0, focused ? 9 : 7),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: focused ? 0.32 : 0.12,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topLeft,
                        radius: 1.1,
                        colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF23325F),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFFE6A0),
                        width: 2,
                      ),
                    ),
                    child: const Text('?', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${widget.player.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.enabled
                              ? 'Accuse as ${widget.targetRole.isEmpty ? 'target' : widget.targetRole}'
                              : widget.player.isReconnecting
                              ? 'Reconnecting...'
                              : widget.player.isOnline
                              ? 'Mysterious court card'
                              : 'Disconnected',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (widget.enabled) const Icon(Icons.gavel_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundCompleteBanner extends StatelessWidget {
  const _RoundCompleteBanner({required this.room});

  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6A0),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5B540), width: 2),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFB83A4B),
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            'Round ${room.currentRound} completed',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'The court catches its breath.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EventStrip extends StatelessWidget {
  const _EventStrip({
    required this.icon,
    required this.message,
    this.danger = false,
  });

  final IconData icon;
  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFE3E3) : const Color(0xFFFFF4D9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: danger ? const Color(0xFFB83A4B) : const Color(0xFFE7C879),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: danger ? const Color(0xFFB83A4B) : const Color(0xFF7E4F2B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoyalCourtDrawer extends StatelessWidget {
  const _RoyalCourtDrawer({
    required this.players,
    required this.open,
    required this.onToggle,
  });

  final List<GamePlayer> players;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final completedPlayers = players
        .where((player) => player.isRoundComplete && !player.isRemoved)
        .toList();

    if (completedPlayers.isEmpty) return const SizedBox.shrink();

    return GamePanel(
      variant: GamePanelVariant.dense,
      child: Column(
        children: [
          PressableScale(
            onPressed: onToggle,
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFB83A4B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Royal Court (${completedPlayers.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                ),
              ],
            ),
          ),
          if (disablePolishForDebug)
            open
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        for (final player in completedPlayers)
                          _CourtRow(player: player),
                      ],
                    ),
                  )
                : const SizedBox.shrink()
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          for (final player in completedPlayers)
                            _CourtRow(player: player),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _CourtRow extends StatelessWidget {
  const _CourtRow({required this.player});

  final GamePlayer player;

  @override
  Widget build(BuildContext context) {
    final role = player.completedRole ?? 'Complete';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7C879)),
      ),
      child: Row(
        children: [
          Text(
            RoleVisuals.emojiFor(role),
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '@${player.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '$role  ${player.score}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ScoreboardDrawer extends StatelessWidget {
  const _ScoreboardDrawer({required this.players});

  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      variant: GamePanelVariant.dense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: Color(0xFFB83A4B)),
              SizedBox(width: 8),
              Text(
                'Scoreboard',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Scoreboard(players: players),
        ],
      ),
    );
  }
}

class _GameMenuDrawer extends StatelessWidget {
  const _GameMenuDrawer({
    required this.room,
    required this.isHost,
    required this.canRequestEndGame,
    required this.isEndGameRequesting,
    required this.isLeaving,
    required this.onRequestEndGameVote,
    required this.onCheckAfkPlayers,
    required this.onLeaveRoom,
  });

  final GameRoom room;
  final bool isHost;
  final bool canRequestEndGame;
  final bool isEndGameRequesting;
  final bool isLeaving;
  final VoidCallback? onRequestEndGameVote;
  final VoidCallback onCheckAfkPlayers;
  final VoidCallback onLeaveRoom;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      variant: GamePanelVariant.dense,
      child: Column(
        children: [
          _GameSummary(room: room),
          const SizedBox(height: 12),
          GameButton(
            label: isEndGameRequesting ? 'Requesting...' : 'Request End Game',
            icon: Icons.flag_rounded,
            style: GameButtonStyle.secondary,
            onPressed: canRequestEndGame && !isEndGameRequesting && !isLeaving
                ? onRequestEndGameVote
                : null,
          ),
          if (isHost) ...[
            const SizedBox(height: 10),
            GameButton(
              label: 'Check AFK Players',
              icon: Icons.manage_search_rounded,
              style: GameButtonStyle.secondary,
              onPressed: onCheckAfkPlayers,
            ),
          ],
          const SizedBox(height: 10),
          GameButton(
            label: isLeaving ? 'Leaving...' : 'Leave Room',
            icon: Icons.exit_to_app_rounded,
            style: GameButtonStyle.danger,
            onPressed: isLeaving
                ? null
                : () {
                    debugPrint('IN_GAME_MENU_LEAVE_ROOM_PRESSED');
                    onLeaveRoom();
                  },
          ),
        ],
      ),
    );
  }
}

class _GameEffectOverlay extends StatefulWidget {
  const _GameEffectOverlay({super.key, required this.kind, this.scoreText});

  final _GameEffectKind? kind;
  final String? scoreText;

  @override
  State<_GameEffectOverlay> createState() => _GameEffectOverlayState();
}

class _GameEffectOverlayState extends State<_GameEffectOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (disablePolishForDebug) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.kind != null) _controller?.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) return const SizedBox.shrink();
    final kind = widget.kind;
    if (kind == null) return const SizedBox.shrink();
    final controller = _controller!;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
            final isWrong = kind == _GameEffectKind.wrong;
            final isRoundComplete = kind == _GameEffectKind.roundComplete;
            final color = switch (kind) {
              _GameEffectKind.success => const Color(0xFFE5B540),
              _GameEffectKind.wrong => const Color(0xFFB83A4B),
              _GameEffectKind.suspense => const Color(0xFF7E4F2B),
              _GameEffectKind.roundStart => const Color(0xFFE5B540),
              _GameEffectKind.roundComplete => const Color(0xFFFFE6A0),
            };
            final shake = isWrong ? math.sin(t * math.pi * 10) * 10 : 0.0;

            return Stack(
              children: [
                Container(color: color.withValues(alpha: fade * 0.18)),
                if (kind == _GameEffectKind.success)
                  Opacity(
                    opacity: fade,
                    child: const GameParticleOverlay(
                      style: GameParticleStyle.sparkles,
                      intensity: 1.3,
                      duration: Duration(seconds: 3),
                    ),
                  ),
                if (kind == _GameEffectKind.wrong ||
                    kind == _GameEffectKind.suspense)
                  Opacity(
                    opacity: fade,
                    child: GameParticleOverlay(
                      style: GameParticleStyle.fog,
                      intensity: kind == _GameEffectKind.wrong ? 1.1 : 0.8,
                      color: kind == _GameEffectKind.wrong
                          ? const Color(0xFFB83A4B)
                          : const Color(0xFFD8D0FF),
                      duration: const Duration(seconds: 7),
                    ),
                  ),
                if (isRoundComplete) _SoftConfettiGlow(progress: t),
                if (isRoundComplete)
                  Opacity(
                    opacity: fade,
                    child: const GameParticleOverlay(
                      style: GameParticleStyle.confetti,
                      intensity: 1.1,
                      duration: Duration(seconds: 4),
                    ),
                  ),
                if (kind == _GameEffectKind.success && widget.scoreText != null)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 110 - (t * 42),
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: fade,
                      child: Transform.scale(
                        scale: 0.85 + (t * 0.35),
                        child: Text(
                          widget.scoreText!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: const Color(0xFFE5B540),
                                fontWeight: FontWeight.w900,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xAA4C2B20),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 74,
                  left: 22,
                  right: 22,
                  child: Opacity(
                    opacity: fade,
                    child: Transform.translate(
                      offset: Offset(shake, 0),
                      child: Transform.scale(
                        scale: 0.94 + (fade * 0.06),
                        child: _EffectBanner(kind: kind),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EffectBanner extends StatelessWidget {
  const _EffectBanner({required this.kind});

  final _GameEffectKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, icon, background, border) = switch (kind) {
      _GameEffectKind.success => (
        'Correct guess',
        Icons.check_circle_rounded,
        const Color(0xFFFFF4D9),
        const Color(0xFFE5B540),
      ),
      _GameEffectKind.wrong => (
        'Wrong guess - roles swapped',
        Icons.swap_horiz_rounded,
        const Color(0xFFFFE5DC),
        const Color(0xFFDB7B5B),
      ),
      _GameEffectKind.suspense => (
        'Court tension rises',
        Icons.bolt_rounded,
        const Color(0xFFFFF4D9),
        const Color(0xFF7E4F2B),
      ),
      _GameEffectKind.roundStart => (
        'Round started',
        Icons.flag_rounded,
        const Color(0xFFFFFAEC),
        const Color(0xFFE5B540),
      ),
      _GameEffectKind.roundComplete => (
        'Round complete',
        Icons.emoji_events_rounded,
        const Color(0xFFFFE6A0),
        const Color(0xFFE5B540),
      ),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x442B160D),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFB83A4B)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4C2B20),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftConfettiGlow extends StatelessWidget {
  const _SoftConfettiGlow({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: List.generate(12, (index) {
        final x = ((index * 73) % 100) / 100 * size.width;
        final startY = 70.0 + ((index * 31) % 90);
        final y = startY + (progress * (90 + (index % 4) * 18));
        final opacity = math.sin(progress * math.pi).clamp(0.0, 1.0);
        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: progress * math.pi * (index.isEven ? 1 : -1),
              child: Container(
                width: 8 + (index % 3) * 3,
                height: 8 + (index % 2) * 5,
                decoration: BoxDecoration(
                  color: index.isEven
                      ? const Color(0xFFE5B540)
                      : const Color(0xFFB83A4B),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GameShell extends StatelessWidget {
  const _GameShell({required this.child, this.transitionKey});

  final Widget child;
  // Kept for call-site compatibility; intentionally unused to avoid reparenting
  // stateful stream content during frequent room/player updates.
  final Key? transitionKey;

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

class _GameSummary extends StatelessWidget {
  const _GameSummary({required this.room});

  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7C879), width: 2),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Room', value: room.roomId),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Round',
            value: '${room.currentRound}/${room.selectedRounds}',
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Active players',
            value: '${room.activePlayerCount}',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF7E4F2B),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MyRoleCard extends StatelessWidget {
  const _MyRoleCard({required this.player});

  final GamePlayer? player;

  @override
  Widget build(BuildContext context) {
    final role = RoleCatalog.byName(player?.currentRole);
    return RoleCharacterCard(
      role: role,
      playerUsername: player?.username,
      size: RoleCharacterCardSize.standard,
      reveal: player?.currentRole.isNotEmpty == true,
    );
  }
}

class _RoundCompleteControls extends StatelessWidget {
  const _RoundCompleteControls({
    required this.isHost,
    required this.canStartNext,
    required this.isLoading,
    required this.onStartNextRound,
  });

  final bool isHost;
  final bool canStartNext;
  final bool isLoading;
  final VoidCallback onStartNextRound;

  @override
  Widget build(BuildContext context) {
    if (!isHost) {
      return const Text(
        'Round complete. Waiting for host...',
        textAlign: TextAlign.center,
      );
    }

    if (!canStartNext) {
      return const Text('Round complete', textAlign: TextAlign.center);
    }

    return RoyalButton(
      label: 'Start Next Round',
      icon: Icons.skip_next_rounded,
      isLoading: isLoading,
      onPressed: onStartNextRound,
    );
  }
}

class _EndGameVoteCard extends StatelessWidget {
  const _EndGameVoteCard({
    required this.room,
    required this.players,
    required this.votes,
    required this.currentUid,
    required this.onAccept,
    required this.onDecline,
  });

  final GameRoom room;
  final List<GamePlayer> players;
  final List<EndGameVote> votes;
  final String? currentUid;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final activePlayers = players.where((player) => !player.isRemoved).toList();
    final acceptedCount = votes
        .where(
          (vote) =>
              vote.vote == 'accept' &&
              activePlayers.any((player) => player.uid == vote.uid),
        )
        .length;
    final currentVote = votes
        .where((vote) => vote.uid == currentUid)
        .firstOrNull
        ?.vote;

    return GamePanel(
      variant: GamePanelVariant.dense,
      child: Column(
        children: [
          const Icon(
            Icons.how_to_vote_rounded,
            color: Color(0xFFB83A4B),
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            '@${room.endGameRequestedByUsername} called the final vote.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            '$acceptedCount/${activePlayers.length} accepted',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (currentVote != null) ...[
            const SizedBox(height: 8),
            Text(
              'Your vote: $currentVote',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  style: GameButtonStyle.success,
                  expand: true,
                  onPressed: onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GameButton(
                  label: 'Decline',
                  icon: Icons.close_rounded,
                  style: GameButtonStyle.danger,
                  expand: true,
                  onPressed: onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.players});

  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = [...players]
      ..sort((a, b) => b.score.compareTo(a.score));
    final activePlayers = sortedPlayers.where((player) => !player.isRemoved);
    final removedPlayers = sortedPlayers.where((player) => player.isRemoved);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 260),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7C879), width: 2),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scoreboard',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final player in activePlayers) _ScoreRow(player: player),
            if (removedPlayers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Removed',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final player in removedPlayers)
                _ScoreRow(player: player, isRemoved: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.player, this.isRemoved = false});

  final GamePlayer player;
  final bool isRemoved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '@${player.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isRemoved ? Colors.black54 : null,
              ),
            ),
          ),
          if (disablePolishForDebug)
            Text(
              '${player.score}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isRemoved ? Colors.black54 : null,
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                '${player.score}',
                key: ValueKey('${player.uid}-${player.score}'),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isRemoved ? Colors.black54 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FinalResultsCard extends StatelessWidget {
  const _FinalResultsCard({
    required this.room,
    required this.players,
    required this.error,
  });

  final GameRoom room;
  final List<GamePlayer> players;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final validPlayers = players.where((player) => !player.isRemoved).toList();
    final sortedPlayers = [...validPlayers]
      ..sort((a, b) => b.score.compareTo(a.score));
    final finalKing = sortedPlayers.isEmpty ? null : sortedPlayers.first;
    final finalThief = sortedPlayers.isEmpty ? null : sortedPlayers.last;
    final podium = sortedPlayers.take(3).toList();

    return GamePanel(
      variant: GamePanelVariant.hero,
      child: Stack(
        children: [
          if (!disablePolishForDebug) ...[
            const Positioned.fill(child: _SoftConfettiGlow(progress: 0.65)),
            const Positioned.fill(
              child: GameParticleOverlay(
                style: GameParticleStyle.confetti,
                intensity: 0.8,
                duration: Duration(seconds: 5),
              ),
            ),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFE6A0), Color(0xFFE5B540)],
                  ),
                  border: Border.all(color: const Color(0xFFFFF4D9), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x88E5B540),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Text('👑', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 8),
              Text(
                'Final Court Ceremony',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                finalKing == null
                    ? 'The court stands empty.'
                    : 'Final King: @${finalKing.username}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (finalKing != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${finalKing.score} royal points',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7E4F2B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              if (room.gameEndedReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  room.gameEndedReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
              const SizedBox(height: 18),
              if (podium.isNotEmpty) _Podium(players: podium),
              if (finalThief != null && finalThief.uid != finalKing?.uid) ...[
                const SizedBox(height: 14),
                _FinalThiefAtmosphere(player: finalThief),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                _EventStrip(
                  icon: Icons.error_rounded,
                  message: error!,
                  danger: true,
                ),
              ],
              const SizedBox(height: 18),
              _Scoreboard(players: sortedPlayers),
              const SizedBox(height: 14),
              RoyalButton(
                label: 'Back To Home',
                icon: Icons.home_rounded,
                onPressed: () {
                  debugPrint('FINAL_COURT_BACK_HOME_PRESSED');
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                          HomeScreen(username: _homeUsername(players)),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _homeUsername(List<GamePlayer> players) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  for (final player in players) {
    if (player.uid == uid && player.username.isNotEmpty) {
      return player.username;
    }
  }
  return 'player';
}

class _Podium extends StatelessWidget {
  const _Podium({required this.players});

  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < players.length; index++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _PodiumSlot(
                player: players[index],
                rank: index + 1,
                height: switch (index) {
                  0 => 118.0,
                  1 => 92.0,
                  _ => 78.0,
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.player,
    required this.rank,
    required this.height,
  });

  final GamePlayer player;
  final int rank;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return Column(
        children: [
          Text(
            rank == 1 ? '👑' : '🏅',
            style: TextStyle(fontSize: rank == 1 ? 34 : 28),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rank == 1
                    ? const [Color(0xFFE5B540), Color(0xFFFFE6A0)]
                    : const [Color(0xFFFFDFA0), Color(0xFFFFF4D9)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFF4D9), width: 2),
              boxShadow: [
                BoxShadow(
                  color: rank == 1
                      ? const Color(0x88E5B540)
                      : const Color(0x33351A10),
                  blurRadius: rank == 1 ? 22 : 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#$rank',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${player.username}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${player.score}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + rank * 120),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 26),
            child: Transform.scale(scale: 0.88 + value * 0.12, child: child),
          ),
        );
      },
      child: Column(
        children: [
          Text(
            rank == 1 ? '👑' : '🏅',
            style: TextStyle(fontSize: rank == 1 ? 34 : 28),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rank == 1
                    ? const [Color(0xFFE5B540), Color(0xFFFFE6A0)]
                    : const [Color(0xFFFFDFA0), Color(0xFFFFF4D9)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFF4D9), width: 2),
              boxShadow: [
                BoxShadow(
                  color: rank == 1
                      ? const Color(0x88E5B540)
                      : const Color(0x33351A10),
                  blurRadius: rank == 1 ? 22 : 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#$rank',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${player.username}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${player.score}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalThiefAtmosphere extends StatelessWidget {
  const _FinalThiefAtmosphere({required this.player});

  final GamePlayer player;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2130), Color(0xFF4C2B20)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x998A6A55), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.dark_mode_rounded, color: Color(0xFFFFDFA0)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Final Thief shadow: @${player.username}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFF4D9),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${player.score}',
            style: const TextStyle(
              color: Color(0xFFFFE6A0),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return RoyalCard(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

GamePlayer? _playerByUid(List<GamePlayer> players, String? uid) {
  if (uid == null || uid.isEmpty) return null;
  for (final player in players) {
    if (player.uid == uid) return player;
  }
  return null;
}

bool _hasOfflineActivePlayer(List<GamePlayer> players) {
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
    _ => 'You are no longer in this game.',
  };
}

int _secondsLeft(DateTime? turnEndsAt) {
  if (turnEndsAt == null) return 0;
  final seconds = turnEndsAt.difference(DateTime.now()).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

String _friendlyFirebaseError(FirebaseException error) {
  return switch (error.code) {
    'permission-denied' => 'Room access denied. Check Firestore rules',
    'unavailable' => 'Network error. Check your connection',
    _ => error.message ?? 'Firestore error. Try again',
  };
}

String _friendlyActionToast(String message) {
  if (message.contains('Round complete')) {
    return 'Round complete';
  }
  if (message.contains('guessed wrong')) {
    return 'Wrong guess';
  }
  if (message.contains('correctly') || message.contains('found')) {
    return 'Correct guess';
  }
  if (message.contains('Round') && message.contains('started')) {
    return message.split('.').first;
  }
  if (message.contains('Game complete')) {
    return 'Game complete';
  }
  return message;
}

IconData _actionToastIcon(String message) {
  if (message.contains('Round complete')) {
    return Icons.emoji_events_rounded;
  }
  if (message.contains('guessed wrong')) {
    return Icons.close_rounded;
  }
  if (message.contains('correctly') || message.contains('found')) {
    return Icons.check_circle_rounded;
  }
  if (message.contains('Round') && message.contains('started')) {
    return Icons.flag_rounded;
  }
  if (message.contains('Game complete')) {
    return Icons.emoji_events_rounded;
  }
  return Icons.auto_awesome_rounded;
}

void _playActionSound(String message) {
  if (message.contains('Round complete')) {
    AudioService.instance.playRoundComplete();
    return;
  }
  if (message.contains('guessed wrong')) {
    AudioService.instance.playWrong();
    return;
  }
  if (message.contains('correctly') || message.contains('found')) {
    AudioService.instance.playCorrect();
    return;
  }
  if (message.contains('Round') && message.contains('started')) {
    AudioService.instance.playRoundStart();
    return;
  }
  if (message.contains('Game complete')) {
    AudioService.instance.playVictory();
  }
}
