import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/pressable_scale.dart';
import '../data/role_data.dart';

enum RoleCharacterCardSize { compact, standard, hero }

class RoleCharacterCard extends StatefulWidget {
  const RoleCharacterCard({
    super.key,
    required this.role,
    this.playerUsername,
    this.size = RoleCharacterCardSize.standard,
    this.reveal = true,
    this.showLore = false,
    this.onTap,
  });

  final RoleData role;
  final String? playerUsername;
  final RoleCharacterCardSize size;
  final bool reveal;
  final bool showLore;
  final VoidCallback? onTap;

  @override
  State<RoleCharacterCard> createState() => _RoleCharacterCardState();
}

class _RoleCharacterCardState extends State<RoleCharacterCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant RoleCharacterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role.id != widget.role.id ||
        oldWidget.reveal != widget.reveal) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metricsFor(widget.size);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final float = math.sin(_controller.value * math.pi * 2) * 3;
        final entrance = _entranceOffset(widget.role.entranceAnimationType, t);
        final rotation = _entranceRotation(
          widget.role.entranceAnimationType,
          t,
        );
        final scale = 0.88 + (t * 0.12);
        final glowPulse =
            0.55 + (math.sin(_controller.value * math.pi * 2) * 0.18);

        final card = Transform.translate(
          offset: Offset(entrance.dx, entrance.dy + float),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: _RoleCardFrame(
                role: widget.role,
                metrics: metrics,
                reveal: widget.reveal,
                showLore: widget.showLore,
                playerUsername: widget.playerUsername,
                glowPulse: glowPulse,
              ),
            ),
          ),
        );

        if (widget.onTap == null) return card;
        return PressableScale(onPressed: widget.onTap, child: card);
      },
    );
  }
}

class _RoleCardFrame extends StatelessWidget {
  const _RoleCardFrame({
    required this.role,
    required this.metrics,
    required this.reveal,
    required this.showLore,
    required this.playerUsername,
    required this.glowPulse,
  });

  final RoleData role;
  final _RoleCardMetrics metrics;
  final bool reveal;
  final bool showLore;
  final String? playerUsername;
  final double glowPulse;

  @override
  Widget build(BuildContext context) {
    final displayRole = reveal ? role : RoleCatalog.unknown;
    final quote = reveal ? role.shortFlavorText : 'Tap into the secret court.';

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: metrics.maxWidth),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            displayRole.glowColor,
            displayRole.primaryColor,
            displayRole.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(metrics.radius + 4),
        boxShadow: [
          BoxShadow(
            color: displayRole.glowColor.withValues(
              alpha: 0.34 + glowPulse * 0.2,
            ),
            blurRadius: 22 + glowPulse * 14,
            spreadRadius: 1 + glowPulse * 2,
            offset: const Offset(0, 10),
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(metrics.padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(metrics.radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFF4D9),
              displayRole.secondaryColor.withValues(alpha: 0.72),
              const Color(0xFFFFDFA0),
            ],
          ),
          border: Border.all(color: const Color(0xFFFFF7D0), width: 1.5),
        ),
        child: Column(
          children: [
            if (playerUsername != null) ...[
              Text(
                '@$playerUsername',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: metrics.gap),
            ],
            _RolePortrait(
              role: displayRole,
              height: metrics.portraitHeight,
              reveal: reveal,
            ),
            SizedBox(height: metrics.gap),
            _RarityCrest(role: displayRole),
            SizedBox(height: metrics.gap * 0.65),
            Text(
              displayRole.displayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: displayRole.primaryColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: metrics.gap * 0.45),
            Text(
              quote,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF351A10),
                fontSize: metrics.flavorSize,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (showLore && reveal) ...[
              SizedBox(height: metrics.gap),
              Text(
                role.longLoreDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4C2B20),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RolePortrait extends StatelessWidget {
  const _RolePortrait({
    required this.role,
    required this.height,
    required this.reveal,
  });

  final RoleData role;
  final double height;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: _RolePatternPainter(role: role, reveal: reveal),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.82,
                      colors: [
                        role.glowColor.withValues(alpha: 0.5),
                        role.primaryColor.withValues(alpha: 0.9),
                        const Color(0xFF1C1725),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -8,
                child: _RoleSilhouette(role: role, reveal: reveal),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Icon(
                  _symbolFor(role),
                  color: Colors.white.withValues(alpha: 0.82),
                  size: 28,
                ),
              ),
              Positioned(
                bottom: 18,
                child: Text(
                  role.placeholderEmoji,
                  style: TextStyle(
                    fontSize: reveal ? 42 : 34,
                    shadows: const [
                      Shadow(color: Color(0xAA000000), blurRadius: 12),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.22),
                      ],
                    ),
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

class _RoleSilhouette extends StatelessWidget {
  const _RoleSilhouette({required this.role, required this.reveal});

  final RoleData role;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final width = switch (role.id) {
      'king' || 'queen' => 124.0,
      'knight' || 'soldier' => 112.0,
      'thief' => 96.0,
      _ => 104.0,
    };
    final color = reveal
        ? Colors.black.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.82);

    return SizedBox(
      width: width,
      height: 132,
      child: CustomPaint(
        painter: _SilhouettePainter(role: role, color: color),
      ),
    );
  }
}

class _RarityCrest extends StatelessWidget {
  const _RarityCrest({required this.role});

  final RoleData role;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Icon(
              i < role.rarityStars
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: i < role.rarityStars
                  ? role.glowColor
                  : const Color(0x997E4F2B),
              size: 18,
            ),
          ),
      ],
    );
  }
}

class _RolePatternPainter extends CustomPainter {
  const _RolePatternPainter({required this.role, required this.reveal});

  final RoleData role;
  final bool reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = role.secondaryColor.withValues(alpha: reveal ? 0.26 : 0.14);

    final spacing = switch (role.id) {
      'thief' => 22.0,
      'police' => 28.0,
      'minister' => 34.0,
      _ => 30.0,
    };

    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }

    final fogPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.24),
      34,
      fogPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.34),
      42,
      fogPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RolePatternPainter oldDelegate) {
    return oldDelegate.role != role || oldDelegate.reveal != reveal;
  }
}

class _SilhouettePainter extends CustomPainter {
  const _SilhouettePainter({required this.role, required this.color});

  final RoleData role;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = size.width / 2;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center, 34),
        width: role.id == 'thief' ? 40 : 48,
        height: 50,
      ),
      paint,
    );

    final body = Path()
      ..moveTo(center - 42, size.height)
      ..quadraticBezierTo(center - 32, 70, center - 18, 60)
      ..lineTo(center + 18, 60)
      ..quadraticBezierTo(center + 34, 76, center + 42, size.height)
      ..close();
    canvas.drawPath(body, paint);

    if (role.id == 'king' || role.id == 'queen') {
      final crown = Path()
        ..moveTo(center - 30, 18)
        ..lineTo(center - 18, 2)
        ..lineTo(center, 18)
        ..lineTo(center + 18, 2)
        ..lineTo(center + 30, 18)
        ..lineTo(center + 25, 28)
        ..lineTo(center - 25, 28)
        ..close();
      canvas.drawPath(crown, paint);
    } else if (role.id == 'knight') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(center + 22, 40, 18, 68),
          const Radius.circular(9),
        ),
        paint,
      );
    } else if (role.id == 'thief') {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center, 32), width: 58, height: 18),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) {
    return oldDelegate.role != role || oldDelegate.color != color;
  }
}

class _RoleCardMetrics {
  const _RoleCardMetrics({
    required this.maxWidth,
    required this.portraitHeight,
    required this.padding,
    required this.radius,
    required this.gap,
    required this.flavorSize,
  });

  final double maxWidth;
  final double portraitHeight;
  final double padding;
  final double radius;
  final double gap;
  final double flavorSize;
}

_RoleCardMetrics _metricsFor(RoleCharacterCardSize size) {
  return switch (size) {
    RoleCharacterCardSize.compact => const _RoleCardMetrics(
      maxWidth: 340,
      portraitHeight: 150,
      padding: 14,
      radius: 22,
      gap: 8,
      flavorSize: 13,
    ),
    RoleCharacterCardSize.standard => const _RoleCardMetrics(
      maxWidth: 390,
      portraitHeight: 178,
      padding: 17,
      radius: 24,
      gap: 10,
      flavorSize: 14,
    ),
    RoleCharacterCardSize.hero => const _RoleCardMetrics(
      maxWidth: 430,
      portraitHeight: 220,
      padding: 20,
      radius: 28,
      gap: 12,
      flavorSize: 16,
    ),
  };
}

Offset _entranceOffset(RoleEntranceAnimationType type, double t) {
  final remaining = 1 - t;
  return switch (type) {
    RoleEntranceAnimationType.royalRise => Offset(0, 34 * remaining),
    RoleEntranceAnimationType.veilFade => Offset(0, -18 * remaining),
    RoleEntranceAnimationType.scrollUnfurl => Offset(-28 * remaining, 0),
    RoleEntranceAnimationType.shieldClash => Offset(24 * remaining, 0),
    RoleEntranceAnimationType.marchingPulse => Offset(0, 18 * remaining),
    RoleEntranceAnimationType.spotlightScan => Offset(18 * remaining, 0),
    RoleEntranceAnimationType.shadowSlip => Offset(
      -34 * remaining,
      12 * remaining,
    ),
  };
}

double _entranceRotation(RoleEntranceAnimationType type, double t) {
  final remaining = 1 - t;
  return switch (type) {
    RoleEntranceAnimationType.shieldClash => -0.035 * remaining,
    RoleEntranceAnimationType.shadowSlip => 0.045 * remaining,
    RoleEntranceAnimationType.scrollUnfurl => -0.025 * remaining,
    _ => 0,
  };
}

IconData _symbolFor(RoleData role) {
  return switch (role.id) {
    'king' => Icons.workspace_premium_rounded,
    'queen' => Icons.diamond_rounded,
    'minister' => Icons.menu_book_rounded,
    'knight' => Icons.shield_rounded,
    'soldier' => Icons.military_tech_rounded,
    'police' => Icons.manage_search_rounded,
    'thief' => Icons.dark_mode_rounded,
    _ => Icons.help_rounded,
  };
}
