import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:transconnect/features/meadow/models/online_user.dart';
import 'package:transconnect/widgets/pronoun_butterfly.dart';

class MeadowButterfly extends StatefulWidget {
  const MeadowButterfly({
    super.key,
    required this.user,
    required this.meadowSize,
    required this.padding,
    this.size = 120,
    this.flyToTarget,
    this.onArrived,
    this.onTap,
    this.driftEnabled = true,
    this.flightDuration = const Duration(milliseconds: 900),
  });

  final OnlineUser user;
  final Size meadowSize;
  final EdgeInsets padding;
  final double size;
  final Offset? flyToTarget;
  final VoidCallback? onArrived;
  final VoidCallback? onTap;
  final bool driftEnabled;
  final Duration flightDuration;

  @override
  State<MeadowButterfly> createState() => _MeadowButterflyState();
}

class _MeadowButterflyState extends State<MeadowButterfly>
    with SingleTickerProviderStateMixin {
  late Offset _currentPosition;
  late AnimationController _movementController;
  late AnimationController _fadeController;
  Timer? _pauseTimer;
  Offset? _activeFlightTarget;
  final _random = Random();
  late final double _bobPhase;
  double _bobAmplitude = 2.6;
  int _flightCounter = 0;
  bool _hasEntered = false;

  static const double _pixelsPerSecond = 56;
  static const Duration _minTravelDuration = Duration(milliseconds: 1600);

  Offset _start = Offset.zero;
  Offset _control = Offset.zero;
  Offset _end = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentPosition = _randomEntryPoint();
    _bobPhase = _random.nextDouble() * pi * 2;
    _movementController = AnimationController(vsync: this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _movementController.addListener(_handleTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startEntry();
    });
  }

  @override
  void didUpdateWidget(covariant MeadowButterfly oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flyToTarget != null && widget.flyToTarget != _activeFlightTarget) {
      _flyTo(widget.flyToTarget!);
    } else if (widget.flyToTarget == null && _activeFlightTarget != null) {
      _activeFlightTarget = null;
      if (widget.driftEnabled) {
        _startDrift();
      }
    } else if (!widget.driftEnabled) {
      _stopDrift();
    } else if (widget.driftEnabled && !_movementController.isAnimating) {
      _startDrift();
    }
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _movementController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startEntry() {
    if (_hasEntered) return;
    _hasEntered = true;
    _animateTo(
      widget.user.position,
      duration: _durationForDistance(_currentPosition, widget.user.position),
      onCompleted: () {
        if (widget.driftEnabled) {
          _startDrift();
        }
      },
    );
  }

  void _startDrift() {
    if (!widget.driftEnabled) return;
    _pauseTimer?.cancel();
    final target = _random.nextDouble() < 0.20 ? _randomPoint() : _randomNearbyPoint();
    _animateTo(
      target,
      duration: _durationForDistance(_currentPosition, target),
    );
  }

  void _stopDrift() {
    _pauseTimer?.cancel();
    _movementController.stop();
  }

  void _flyTo(Offset target) {
    _activeFlightTarget = target;
    _pauseTimer?.cancel();
    _animateTo(
      target,
      duration: _durationForDistance(
        _currentPosition,
        target,
        minimum: widget.flightDuration,
      ),
      onCompleted: () {
        widget.onArrived?.call();
      },
    );
  }

  void _animateTo(
    Offset target, {
    required Duration duration,
    VoidCallback? onCompleted,
  }) {
    final flightId = ++_flightCounter;
    _movementController
      ..stop()
      ..reset()
      ..duration = duration;

    _start = _currentPosition;
    _end = target;

    _bobAmplitude = widget.flyToTarget != null ? 1.8 : 2.6;

    final mid = Offset((_start.dx + _end.dx) / 2, (_start.dy + _end.dy) / 2);
    final dx = _end.dx - _start.dx;
    final dy = _end.dy - _start.dy;
    final length = max(1.0, sqrt(dx * dx + dy * dy));
    final nx = -dy / length;
    final ny = dx / length;
    final wobbleBase = min(widget.size * 0.30, length * 0.22);
    final wobble = wobbleBase * (0.65 + _random.nextDouble() * 0.55);
    final sign = _random.nextBool() ? 1.0 : -1.0;
    _control = Offset(
      mid.dx + nx * wobble * sign,
      mid.dy + ny * wobble * sign,
    );

    _movementController.forward().whenComplete(() {
      if (!mounted) return;
      if (flightId != _flightCounter) return;
      setState(() {
        _currentPosition = target;
      });
      onCompleted?.call();

      if (widget.flyToTarget != null) {
        return;
      }
      if (widget.driftEnabled) {
        _startDrift();
      }
    });
  }

  void _handleTick() {
    final t = Curves.easeInOutSine.transform(_movementController.value);
    final point = _quadraticBezier(_start, _control, _end, t);
    final wistfulBob = sin((t * pi * 2) + _bobPhase) * _bobAmplitude;
    if (!mounted) return;
    final minX = widget.padding.left + widget.size / 2;
    final minY = widget.padding.top + widget.size / 2;
    final maxX = widget.meadowSize.width - widget.padding.right - widget.size / 2;
    final maxY = widget.meadowSize.height - widget.padding.bottom - widget.size / 2;
    final next = point.translate(0, wistfulBob);
    setState(() {
      _currentPosition = Offset(
        next.dx.clamp(minX, maxX).toDouble(),
        next.dy.clamp(minY, maxY).toDouble(),
      );
    });
  }

  Offset _randomPoint() {
    final minX = widget.padding.left + widget.size / 2;
    final minY = widget.padding.top + widget.size / 2;
    final maxX = widget.meadowSize.width - widget.padding.right - widget.size / 2;
    final maxY = widget.meadowSize.height - widget.padding.bottom - widget.size / 2;
    final dx = minX + _random.nextDouble() * max(0, maxX - minX);
    final dy = minY + _random.nextDouble() * max(0, maxY - minY);
    return Offset(dx, dy);
  }

  Offset _randomEntryPoint() {
    final minX = widget.padding.left - widget.size;
    final minY = widget.padding.top - widget.size;
    final maxX = widget.meadowSize.width - widget.padding.right + widget.size;
    final maxY = widget.meadowSize.height - widget.padding.bottom + widget.size;
    final side = _random.nextInt(4);
    switch (side) {
      case 0:
        return Offset(minX, minY + _random.nextDouble() * (maxY - minY));
      case 1:
        return Offset(maxX, minY + _random.nextDouble() * (maxY - minY));
      case 2:
        return Offset(minX + _random.nextDouble() * (maxX - minX), minY);
      default:
        return Offset(minX + _random.nextDouble() * (maxX - minX), maxY);
    }
  }

  Offset _randomNearbyPoint() {
    final minX = widget.padding.left + widget.size / 2;
    final minY = widget.padding.top + widget.size / 2;
    final maxX = widget.meadowSize.width - widget.padding.right - widget.size / 2;
    final maxY = widget.meadowSize.height - widget.padding.bottom - widget.size / 2;

    final radius = 140 + _random.nextDouble() * 220;
    final angle = _random.nextDouble() * pi * 2;
    final dx = _currentPosition.dx + cos(angle) * radius;
    final dy = _currentPosition.dy + sin(angle) * radius * 0.65;

    return Offset(
      dx.clamp(minX, maxX).toDouble(),
      dy.clamp(minY, maxY).toDouble(),
    );
  }

  Offset _quadraticBezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      (u * u) * p0.dx + (2 * u * t) * p1.dx + (t * t) * p2.dx,
      (u * u) * p0.dy + (2 * u * t) * p1.dy + (t * t) * p2.dy,
    );
  }

  Duration _durationForDistance(
    Offset start,
    Offset end, {
    Duration? minimum,
  }) {
    final distance = (end - start).distance;
    final ms = (distance / _pixelsPerSecond * 1000).round();
    final computed = Duration(
      milliseconds: max(ms, _minTravelDuration.inMilliseconds),
    );
    if (minimum == null) return computed;
    if (computed < minimum) return minimum;
    return computed;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _currentPosition.dx - widget.size / 2,
      top: _currentPosition.dy - widget.size / 2,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PronounButterflyAvatar(
                pronouns: widget.user.pronounSlots,
                size: widget.size,
                isFlapping: true,
                flapSpeed: const Duration(milliseconds: 520),
                centerGap: widget.user.pronounSlots.length >= 5 ? 12 : -8,
              ),
              const SizedBox(height: 4),
              Text(
                widget.user.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.55),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
